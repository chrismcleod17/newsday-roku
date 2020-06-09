' ********** Copyright 2016 Roku Corp.  All Rights Reserved. **********

' A context node has a parameters and response field
' - parameters corresponds to everything related to an HTTP request
' - response corresponds to everything related to an HTTP response
' Component Variables:
'   m.port: the UriFetcher message port
'   m.jobsById: an AA containing a history of HTTP requests/responses

' init(): UriFetcher constructor
' Description: sets the execution function for the UriFetcher
' 						 and tells the UriFetcher to run
sub init()
  print "UriHandler.brs - [init]"

  ' create the message port
  m.port = createObject("roMessagePort")

  ' fields for checking if content has been loaded
  ' each row is assumed to be a different request for a rss feed
  m.top.numRows = 2
  m.top.numRowsReceived = 0
  m.top.numBadRequests = 0
  m.top.contentSet = false

  ' Stores the content if not all requests are ready
  m.top.ContentCache = createObject("roSGNode", "ContentNode")

  ' setting callbacks for url request and response
  m.top.observeField("request", m.port)
  m.top.observeField("ContentCache", m.port)

  ' setting the task thread function
  m.top.functionName = "go"
  m.top.control = "RUN"
end sub

' Callback function for when content has finished parsing
sub updateContent()
  print "UriHandler.brs - [updateContent]"

  ' Received another row of content
  m.top.numRowsReceived++

  ' Return if the content is already set
  if m.top.contentSet return
  ' Set the UI if all content from all streams are ready
  ' Note: this technique is hindered by slowest request
  ' Need to think of a better asynchronous method here!
  print m.top.numRows
  print m.top.numRowsReceived
  if m.top.numRows = m.top.numRowsReceived
    parent = createObject("roSGNode", "ContentNode")
    for i = 0 to (m.top.numRowsReceived - 1)
      oldParent = m.top.contentCache.getField(i.toStr())
      print oldParent
      if oldParent <> invalid
        for j = 0 to (oldParent.getChildCount() - 1)
          oldParent.getChild(0).reparent(parent,true)
        end for
      end if
    end for
    print "All content has finished loading"
    m.top.contentSet = true
    m.top.content = parent
    
    if(m.top.omniture <> invalid)
        'do omniture calls
        print m.top.omniture
        dictionary = {}
        dictionary["pageName"] = m.top.omniture.pageName
        dictionary["contentTitle"] = m.top.omniture.contentTitle
        dictionary["contentHierarchy"] = m.top.omniture.hierarchy
        dictionary["contentSource"] = "app"
        dictionary["contentType"] = m.top.omniture.contentType
        levels = m.top.omniture.hierarchy.Split(":")
        for i=1 to 5
            contentLevel = "contentLevel" + i.toStr()
            if(i < 3)
                levelindex = 2
             else
                levelindex = i-1
             end if
             
            if levels[levelindex] <> invalid
                dictionary[contentLevel] = levels[levelindex]
            else
                dictionary[contentLevel] = levels[levels.Count() - 1]
            end if
        end for
        dictionary["contentDirectory"] = levels[levels.Count() - 1]
        
        if(m.top.searchterm <> invalid) then dictionary["searchTerms"] = m.top.searchterm
        
        deviceinfo = CreateObject("roDeviceInfo")
        dictionary["ipAddress"] = deviceInfo.GetIPAddrs()
        dictionary["deviceId"] = deviceInfo.GetDeviceUniqueId()
        version=deviceInfo.GetVersion()
        version_major=mid(version,3,1)
        version_minor=mid(version,5,2)
        version_build=mid(version,8,5)

        if version_minor.toint() < 10 then
            version_minor=mid(version_minor,2)
        end if
        userAgent="Roku/DVP-"+version_major+"."+version_minor+" ("+version+")"
        dictionary["userAgent"] = userAgent
        dictionary["bundleId"] = "newsday_roku"
        dictionary["myAppName"] = "newsday roku tv"
        
        userid = invalid
        zipcode = invalid
        accessLevel = invalid
        
        'add user info to dictionary
        sec = CreateObject("roRegistrySection", "UserInfo")
        if sec.Exists("UserId")
            userid = sec.Read("UserId")
            zipcode = sec.Read("Zipcode")
            req = CreateObject("roUrlTransfer")
            req.SetMessagePort(m.port)
            req.SetUrl("http://www.newsday.com/device/accountservices?serviceType=getSiteAccess&userid=" + userid)
            rsp = req.GetToString()
            responseJSON = ParseJSON(rsp)
            if(responseJSON <> invalid and responseJSON.status <> "fail")
                accessLevel = responseJSON.accessLevel
            end if
        else
            print "No User Info Stored!"
        end if
    
        if userid <> invalid then dictionary["userAccountId"] = userid
        if zipcode <> invalid then dictionary["userZip"] = zipcode
        if accessLevel <> invalid then dictionary["userAccessLevel"] = LCase(accessLevel)
        ADBMobile().trackState(m.top.omniture.pageName, dictionary)
    end if
  else
    print "Not all content has finished loading yet"
  end if
end sub

' go(): The "Task" function.
'   Has an event loop which calls the appropriate functions for
'   handling requests made by the HeroScreen and responses when requests are finished
' variables:
'   m.jobsById: AA storing HTTP transactions where:
'			key: id of HTTP request
'  		val: an AA containing:
'       - key: context
'         val: a node containing request info
'       - key: xfer
'         val: the roUrlTransfer object
sub go()
  print "UriHandler.brs - [go]"

  ' Holds requests by id
  m.jobsById = {}

	' UriFetcher event loop
  while true
    msg = wait(0, m.port)
    mt = type(msg)
    print "Received event type '"; mt; "'"
    ' If a request was made
    if mt = "roSGNodeEvent"
      if msg.getField()="request"
        if addRequest(msg.getData()) <> true then print "Invalid request"
      else if msg.getField()="ContentCache"
        updateContent()
      else
        print "Error: unrecognized field '"; msg.getField() ; "'"
      end if
    ' If a response was received
    else if mt="roUrlEvent"
      processResponse(msg)
    ' Handle unexpected cases
    else
	   print "Error: unrecognized event type '"; mt ; "'"
    end if
  end while
end sub

' addRequest():
'   Makes the HTTP request
' parameters:
'		request: a node containing the request params/context.
' variables:
'   m.jobsById: used to store a history of HTTP requests
' return value:
'   True if request succeeds
' 	False if invalid request
function addRequest(request as Object) as Boolean
  print "UriHandler.brs - [addRequest]"

  if type(request) = "roAssociativeArray"
    context = request.context
    parser = request.parser
    if type(parser) = "roString"
      if m.Parser = invalid
        m.Parser = createObject("roSGNode", parser)
        m.Parser.observeField("parsedContent", m.port)
      else
        print "Parser already created"
      end if
    else
      print "Error: Incorrect type for Parser: " ; type(parser)
      return false
    end if
  	if type(context) = "roSGNode"
      parameters = context.parameters
      if type(parameters)="roAssociativeArray"
      	uri = parameters.uri
        if type(uri) = "roString"
          urlXfer = createObject("roUrlTransfer")
          urlXfer.setUrl(uri)
          urlXfer.setPort(m.port)
          'urlXfer.SetCertificatesFile("pkg:/certs/cacert.pem")
          urlXfer.SetCertificatesFile("common:/certs/ca-bundle.crt")
          urlXfer.InitClientCertificates()
          ' should transfer more stuff from parameters to urlXfer
          idKey = stri(urlXfer.getIdentity()).trim()
          ' AsyncGetToString returns false if the request couldn't be issued
          ok = urlXfer.AsyncGetToString()
          if ok then
            m.jobsById[idKey] = {
              context: request,
              xfer: urlXfer
            }
          else
            print "Error: request couldn't be issued"
          end if
  		    print "Initiating transfer '"; idkey; "' for URI '"; uri; "'"; " succeeded: "; ok
        else
          print "Error: invalid uri: "; uri
          m.top.numBadRequests++
  			end if
      else
        print "Error: parameters is the wrong type: " + type(parameters)
        return false
      end if
  	else
      print "Error: context is the wrong type: " + type(context)
  		return false
  	end if
  else
    print "Error: request is the wrong type: " + type(request)
    return false
  end if
  return true
end function

' processResponse():
'   Processes the HTTP response.
'   Sets the node's response field with the response info.
' parameters:
' 	msg: a roUrlEvent (https://sdkdocs.roku.com/display/sdkdoc/roUrlEvent)
sub processResponse(msg as Object)
  print "UriHandler.brs - [processResponse]"
  idKey = stri(msg.GetSourceIdentity()).trim()
  job = m.jobsById[idKey]
  if job <> invalid
    context = job.context
    parameters = context.context.parameters
    jobnum = job.context.context.num
    uri = parameters.uri
    print "Response for transfer '"; idkey; "' for URI '"; uri; "'"
    result = {
      code:    msg.GetResponseCode(),
      headers: msg.GetResponseHeaders(),
      content: msg.GetString(),
      num:     jobnum
    }
    ' could handle various error codes, retry, etc. here
    m.jobsById.delete(idKey)
    job.context.context.response = result
    if msg.GetResponseCode() = 200
      'm.Parser.response = (result.content, result.num)
      m.Parser.response = result
    else
      print "Error: status code was: " + (msg.GetResponseCode()).toStr()
      m.top.numBadRequests++
      m.top.numRowsReceived++
    end if
  else
    print "Error: event for unknown job "; idkey
  end if
end sub
