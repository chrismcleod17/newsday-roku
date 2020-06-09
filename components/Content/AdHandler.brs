Library "Roku_Ads.brs"

sub init()
  print "AdHandler.brs - [init]"

  ' create the message port
  m.port = createObject("roMessagePort")
  
  m.adIface = Roku_Ads()
  'adIface.setAdUrl(myAdUrl)
  m.adPods = m.adIface.getAds()

  ' setting callbacks for url request and response
  m.top.observeField("request", m.port)

  ' setting the task thread function
  m.top.functionName = "go"
  m.top.control = "RUN"
end sub

sub go()
  print "AdHandler.brs - [go]"

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
        if requestAds(msg.getData()) <> true then print "Invalid request"
      else
        print "Error: unrecognized field '"; msg.getField() ; "'"
      end if
    else
       print "Error: unrecognized event type '"; mt ; "'"
    end if
  end while
end sub

sub requestAds(data as Object)
    m.top.shouldPlayVideo = m.adIface.showAds(m.adPods)
end sub