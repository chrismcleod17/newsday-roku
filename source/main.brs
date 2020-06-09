' ********** Copyright 2016 Roku Corp.  All Rights Reserved. **********
Library "Roku_Ads.brs"

' 1st function called when channel application starts.
sub Main(input as Dynamic)
  print "################"
  print "Start of Channel"
  print "################"
  
  ' Add deep linking support here. Input is an associative array containing
  ' parameters that the client defines. Examples include "options, contentID, etc."
  ' See guide here: https://sdkdocs.roku.com/display/sdkdoc/External+Control+Guide
  ' For example, if a user clicks on an ad for a movie that your app provides,
  ' you will have mapped that movie to a contentID and you can parse that ID
  ' out from the input parameter here.
  ' Call the service provider API to look up
  ' the content details, or right data from feed for id
  if input <> invalid
    print "Received Input -- write code here to check it!"
    if input.reason <> invalid
      if input.reason = "ad" then
        print "Channel launched from ad click"
        'do ad stuff here
      end if
    end if
    if input.contentID <> invalid
      print "contentID is: " + input.contentID
      screen = CreateObject("roSGScreen")
      m.port = CreateObject("roMessagePort")
      screen.setMessagePort(m.port)
      deepLinkURL = "https://www.newsday.com/json/" + input.contentID
      deepLinkReq = CreateObject("roUrlTransfer")
      deepLinkReq.SetMessagePort(m.port)
      deepLinkReq.SetUrl(deepLinkURL)
      deepLinkRsp = deepLinkReq.GetToString()
      deepLinkJson = ParseJSON(deepLinkRsp)
      
      if(deepLinkJson.content <> invalid)
        node = createObject("RoSGNode", "ContentNode")
        
        if(deepLinkJson.content.caption <> invalid) then node.setField("DESCRIPTION", deepLinkJson.content.caption)
        if(deepLinkJson.content.date <> invalid) then node.setField("RELEASEDATE", deepLinkJson.content.date)
        node.setField("STREAMFORMAT", "mp4")
        if(deepLinkJson.content.headline <> invalid) then node.setField("TITLE", deepLinkJson.content.headline)
        if(deepLinkJson.content.mp4 <> invalid) then node.setField("URL", deepLinkJson.content.mp4)
        scene = screen.CreateScene("DeepLinkVideoPlayer")
        scene.content = node
        scene.backExitsScene = false
        screen.show()
        scene.observeField("videoFinishedFlag", m.port)
        
        while(true)
          msg = wait(0, m.port)
          msgType = type(msg)
          print "msgType is " + msgType
          if msgType = "roSGScreenEvent"
              if msg.isScreenClosed() then exit while
          else if msgType = "roSGNodeEvent"
            if (msg.GetField() = "videoFinishedFlag") and scene.videoFinishedFlag = true
                exit while
            end if
        end if
      end while
      end if
      'launch/prep the content mapped to the contentID here
      
    end if
  end if
  
  showHeroScreen()  
end sub

' Initializes the scene and shows the main homepage.
' Handles closing of the channel.
sub showHeroScreen()
  print "main.brs - [showHeroScreen]"
  
  screen = CreateObject("roSGScreen")
  m.port = CreateObject("roMessagePort")
  screen.setMessagePort(m.port)
  
  deviceinfo = CreateObject("roDeviceInfo")
  ipaddr = deviceinfo.GetExternalIp()
  print ipaddr
  ipcheck = CreateObject("roUrlTransfer")
  ipcheck.SetMessagePort(m.port)
  ipcheck.SetUrl("https://www.newsday.com/device/accountservices?serviceType=checkAppleTVAccessND&ipAddress=" + ipaddr)
  iprsp = ipcheck.GetToString()
  ipJson = ParseJSON(iprsp)
  
  m.adIface = Roku_Ads()
  m.adIface.setAdUrl("http://pubads.g.doubleclick.net/gampad/ads?sz=4x4&iu=/5819/nwsd.desktop/video_gallery/roku&ciu_szs=300x250&impl=s&gdfp_req=1&env=vp&output=xml_vast2&unviewed_position_start=1&url=${referrerUrl}&correlator=1485899169017")
  m.adIface.setAdPrefs(false, 1)
  'm.adIface.setAdUrl("http://pubads.g.doubleclick.net/gampad/ads?sz=640x360&iu=/5819/cblvsn.nwsd.videogallery/roku&ciu_szs=1920x1080&impl=s&gdfp_req=1&env=vp&output=xml_vast3&unviewed_position_start=1&correlator={timestamp}&title={mediainfo.name}&ID={mediainfo.id}&refID={mediainfo.reference_id}")
  
  m.global = screen.getGlobalNode()
  faqText =  ReadAsciiFile("pkg:/text/apple-tv-faq.txt")
  privacyText = ReadAsciiFile("pkg:/text/apple-tv-privacy-policy.txt")
  tosText = ReadAsciiFile("pkg:/text/apple-tv-tos.txt")
  m.global.addFields({faqText: faqText, privacyText: privacyText, tosText: tosText})
  
  'check user access
  sec = CreateObject("roRegistrySection", "UserInfo")
  if sec.Exists("UserId")
    userid = sec.Read("UserId")
    print "User logged in as " + userid
    if userid.instr(0, ".") > 0
      print "User logged in with IP address"
    else
      req = CreateObject("roUrlTransfer")
      req.SetMessagePort(m.port)
      req.SetUrl("https://www.newsday.com/device/accountservices?serviceType=getSiteAccess&userid=" + userid)
      rsp = req.GetToString()
      responseJSON = ParseJSON(rsp)
      print responseJSON
      if responseJSON = invalid or responseJSON.siteAccess = "None" or responseJSON.siteAccess = "News12"
          print "User expired, delete"
          sec.Delete("UserId")
      end if
    end if
  else
    print "No User Info Stored - checking IP!"
    if ipJson <> invalid
        access = ipJson.access
        if access <> invalid and access <> "Failure"
            write = sec.Write("UserId", ipaddr)
            write2 = sec.Write("Zipcode",  ipJson.zip_code)
            flush = sec.Flush()
            
            if write <> invalid and flush <> invalid and write2 <> invalid
                print "User IP write succeeded!"
            end if
        else
            print "User is outside of service area - account must be activated with code!"
        end if
     end if
  end if
  
  scene = screen.CreateScene("HeroScene")
  screen.show()
  scene.observeField("adPlayFlag", m.port)

  while(true)
    msg = wait(0, m.port)
    
    ADBMobile().processMessages()
    ADBMobile().processMediaMessages() 
    
    msgType = type(msg)
    if msgType = "roSGScreenEvent"
      if msg.isScreenClosed() then return
    else if msgType = "roSGNodeEvent"
     playContent = true
     if (msg.GetField() = "adPlayFlag") and scene.adPlayFlag = true
          m.adPods = m.adIface.getAds()
          if m.adPods <> invalid and m.adPods.count() > 0
               playContent = m.adIface.showAds(m.adPods)
          end if
          
          if playContent
             ' Play video flag
             scene.adFinishedPlaying = true
          end if
     end if
   end if
  end while
end sub


' Initializes the scene and shows the main homepage.
' Handles closing of the channel.
sub showActivation()
  print "HeroScene.brs - [showActivation]"
  screen = CreateObject("roSGScreen")
  m.port = CreateObject("roMessagePort")
  screen.setMessagePort(m.port)
  scene = screen.CreateScene("Activation")
  screen.show()

  while(true)
    msg = wait(0, m.port)
    msgType = type(msg)
    if msgType = "roSGScreenEvent"
      if msg.isScreenClosed() then return
    end if
  end while
end sub

