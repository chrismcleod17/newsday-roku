' CodeHandler.brs - To handle all requests associated with activation.

sub init()
  print "CodeHandler.brs - [init]"

  ' create the message port
  m.port = createObject("roMessagePort")

  m.top.contentSet = false

  ' setting callbacks for url request and response
  m.top.observeField("request", m.port)

  ' setting the task thread function
  m.top.functionName = "go"
  m.top.control = "RUN"
end sub

sub go()
  'print "CodeHandler.brs - [go]"

  while true
    msg = wait(0, m.port)
    mt = type(msg)
    'print "Received event type '"; mt; "'"
    ' If a request was made
    if mt = "roSGNodeEvent"
      if msg.getField()="request"
        if doCodeReq(msg.getData()) <> true then print "Invalid request"
      else
        print "Error: unrecognized field '"; msg.getField() ; "'"
      end if
    end if
  end while
end sub

function doCodeReq(request as Object) as Boolean
    'print "CodeHandler.brs - [doCodeReq]"
    context = request.context
    'print context
    req = CreateObject("roUrlTransfer")
    req.SetMessagePort(m.port)
    req.SetUrl(context.parameters.uri)
    rsp = req.GetToString()

    responseJSON = ParseJSON(rsp)
    'print responseJSON

    m.top.content = responseJSON
    
   if responseJSON <> invalid  
        return true
   else
        return false
   end if
end function