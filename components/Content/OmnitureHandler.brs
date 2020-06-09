' ********** Copyright 2016 Roku Corp.  All Rights Reserved. **********

' init(): OmnitureHandler constructor
' Description: sets the execution function for the UriFetcher
'                        and tells the UriFetcher to run
sub init()
  print "OmnitureHandler.brs - [init]"

  ' create the message port
  m.port = createObject("roMessagePort")

  ' setting callbacks for url request and response
  m.top.observeField("request", m.port)
  
  m.top.mediaInfo = invalid
  m.top.finished = false

  ' setting the task thread function
  m.top.functionName = "go"
  m.top.control = "RUN"
end sub

sub go()
  print "OmnitureHandler.brs - [go]"

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
        if handleRequest(msg.getData()) <> true then print "Invalid request"
      else
        print "Error: unrecognized field '"; msg.getField() ; "'"
      end if
    else
       print "Error: unrecognized event type '"; mt ; "'"
    end if
  end while
end sub

function handleRequest(request as Object) as Boolean
  print "OmnitureHandler.brs - [handleRequest]"

  if type(request) = "roAssociativeArray"
    context = request.context
    requestType = context.reqtype
    screen = context.screen
    dictionary = context.dictionary
    
    'if requestType = "trackAction" or requestType = "trackState"
        userid = invalid
        zipcode = invalid
        accessLevel = invalid
    
        'add constants
        dictionary["contentSource"] = "app"
    
        'add content levels
        levels = dictionary["contentHierarchy"].Split(":")
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
    
        dictionary["contentDirectory"] = levels[levels.Count() - 1] ' last level is contentDirectory
    
        'add user info to dictionary
        sec = CreateObject("roRegistrySection", "UserInfo")
        if sec.Exists("UserId")
            userid = sec.Read("UserId")
            zipcode = sec.Read("Zipcode")
            req = CreateObject("roUrlTransfer")
            req.SetMessagePort(m.port)
            req.SetUrl("https://www.newsday.com/device/accountservices?serviceType=getSiteAccess&userid=" + userid)
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
    
        'add device info to dictionary
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
    
        'track request
        if(requestType = "trackAction")
            ADBMobile().trackAction(screen, dictionary)
        else if(requestType = "trackState")
            ADBMobile().trackState(screen, dictionary)
        else if requestType = "play"
            print "play requested"
            ADBMobile().trackAction("video play", dictionary)
        else if requestType = "finished"
            print "finished requested"
            ADBMobile().trackAction("video finished", dictionary)
        end if
    'else
'        mediaContextData = {}  
'        if(m.top.mediaInfo = invalid)
'            ' Create a media info object
'            mediaInfo = adb_media_init_mediainfo(dictionary["contentTitle"], dictionary["id"], dictionary["length"], dictionary["streamType"])
'            m.top.mediaInfo = mediaInfo
'            
'            ' Create context data if any
'             
'            'mediaContextData["cmk1"] = "cmv1"
'            'mediaContextData[""cmk2""] = "cmv2"
'
'            ADBMobile().mediaTrackLoad(mediaInfo,mediaContextData)
'        end if
'                else if requestType = "33percent"
'            print "33 per requested"
'            ADBMobile().mediaTrackEvent("33 Percent", m.top.mediaInfo, mediaContextData)
'        else if requestType = "66percent"
'            print "66 per requested"
'            ADBMobile().mediaTrackEvent("66 Percent", m.top.mediaInfo, mediaContextData)

       ' end if
   ' end if
  end if
  m.top.finished = true
  return true
 end function