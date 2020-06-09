' CodeHandler.brs - To handle all requests associated with activation.

sub init()
  print "RegistryHandler.brs - [init]"

  ' create the message port
  m.port = createObject("roMessagePort")

  m.top.contentSet = false

  ' setting callbacks for url request and response
  m.top.observeField("userInfo", m.port)
  m.top.observeField("regRequest", m.port)
   m.top.observeField("videoPositions", m.port)
  m.top.observeField("getVideoPos", m.port)

  ' setting the task thread function
  m.top.functionName = "go"
  m.top.control = "RUN"
end sub

sub go()
  print "RegistryHandler.brs - [go]"

  while true
    msg = wait(0, m.port)
    mt = type(msg)
    print "Received event type '"; mt; "'"
    ' If a request was made
    if mt = "roSGNodeEvent"
      if msg.getField()="userInfo"
        if storeRegistryInfo(msg.getData()) <> true then print "Invalid request"
      else if msg.getField()="regRequest"
        if fetchRegistryInfo(msg.getData()) <> true then print "Invalid request"
      else if msg.getField()="videoPositions"
        if storeVideoPosition(msg.getData()) <> true then print "Invalid request"
      else if msg.getField()="getVideoPos"
        if fetchVideoPosition(msg.getData()) <> true then print "Invalid request"
      else
        print "Error: unrecognized field '"; msg.getField() ; "'"
      end if
    end if
  end while
end sub

function storeRegistryInfo(userInfo as Object) as Boolean
    print "RegistryHandler.brs - [storeRegistryInfo]"
        
    context = userInfo.context
    userid = context.parameters.userid
    zipcode = context.parameters.zipcode
   
    sec = CreateObject("roRegistrySection", "UserInfo")

    write = sec.Write("UserId", userid)
    write2 = sec.Write("Zipcode",  zipcode)
    flush = sec.Flush()
    
    if write <> invalid and flush <> invalid and write2 <> invalid
        contentSet = true
    else
        contentSet = false
     end if
    
   if userid <> invalid  
        return true
   else
        return false
   end if
end function

function storeVideoPosition(videoPositions as Object) as Boolean
    print "RegistryHandler.brs - [storeVideoPosition]"
        
    context = videoPositions.context
    videoid = context.parameters.videoid
    position = context.parameters.position
    retval = true
    
    sec = CreateObject("roRegistrySection", "VideoPositions")
    
    if(position <> -1)
        write = sec.Write(videoid,  Str(position))
        flush = sec.Flush()
    
        if write <> invalid and flush <> invalid
            contentSet = true
        else
            contentSet = false
        end if
    
        if contentSet = true  
            retval =  true
        else
            retval =  false
        end if
   else
      if sec.Exists(videoid) then sec.Delete(videoid)
      retval = true
   end if
   
   responseJSON = {"response" : "PositionStored"}
   m.top.content = responseJSON
   return true
end function

function fetchVideoPosition(data as Object) as Boolean
    print "RegistryHandler.brs - [fetchVideoPosition]"
    
    context = data.context
    videoid = context.videoid
 
    sec = CreateObject("roRegistrySection", "VideoPositions")
    responseJSON = invalid
    if(sec.exists(videoid))
        position = sec.read(videoid)
        if(position <> invalid)
            responseJSON = {"response" : "VideoPosition", "position" : position}
        else
            responseJSON = {"response" : "VideoPosition", "position" : 0}
        end if
    else
        responseJSON = {"response" : "VideoPosition", "position" : 0}
    end if
    
    if responseJSON <> invalid
        m.top.content = responseJSON
    end if
    
    return true
end function

function fetchRegistryInfo(data as Object) as Boolean
    print "RegistryHandler.brs - [fetchRegistryInfo]"
    
    context = data.context
    section = context.section
    
    if section = "UserInfo"
        sec = CreateObject("roRegistrySection", "UserInfo")
        if sec.Exists("UserId")
            userid = sec.Read("UserId")
            responseJSON = invalid
            if userid.instr(0, ".") > 0
                print "User ID is an ip address"
                responseJSON = {"response" : "UserIP", "username" : userid}
                print responseJSON
            else
                print "User logged in as " + userid
                req = CreateObject("roUrlTransfer")
                req.SetMessagePort(m.port)
                req.SetUrl("https://www.newsday.com/device/accountservices?serviceType=getUserData&userid=" + userid)
                rsp = req.GetToString()
                responseJSON = ParseJSON(rsp)
                print responseJSON
            end if
            
            if responseJSON <> invalid
                m.top.content = responseJSON
            end if
        else
            m.top.content = { response: "Not logged in"}
        end if
    else if section = "LogOut"
      sec = CreateObject("roRegistrySection", "UserInfo")
      if sec.Exists("UserId")
        sec.Delete("UserId")
      end if
    end if
    
    return true
end function