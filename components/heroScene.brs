' ********** Copyright 2016 Roku Corp.  All Rights Reserved. **********

' 1st function that runs for the scene on channel startup
sub init()
  'To see print statements/debug info, telnet on port 8089
  'print "HeroScene.brs - [init]"
  'main hero screen stuff
  m.HeroScreen = m.top.FindNode("HeroScreen")
  m.Overhang = m.top.findNode("Overhang")
  m.VideoPlayer = m.top.FindNode("VideoPlayer")
  m.VideoPlayer.retrievingBar.filledBarBlendColor = "#0072ae"
  m.VideoPlayer.retrievingBar.trackBlendColor = "#f4f4f4"
  m.LoadingIndicator = m.top.findNode("LoadingIndicator")
  m.WarningDialog = m.top.findNode("WarningDialog")
  m.FadeIn = m.top.findNode("FadeIn")
  m.FadeOut = m.top.findNode("FadeOut")
  
  deviceInfo = CreateObject("roDeviceInfo")
  res = deviceInfo.GetDisplayMode()
  print "Resolution is " + res
  if(res = "1080p" or res = "1080i") then m.Overhang.logoUri = "pkg:/images/newsday-amp-logo.png"
  
  'Options screen
  m.Options = m.top.findNode("Options")
  m.buttons = m.top.findNode("Buttons")
  m.optionsLabel = m.top.findNode("OptionsLabel")
  m.TosText = m.top.findNode("TosLabel")
  m.FaqText = m.top.findNode("FaqLabel")
  m.PrivacyText = m.top.findNode("PrivacyLabel")
  result = []
  'for each button in ["Search", "Verify your account", "FAQ", "Terms of Use", "Privacy Policy"]
  for each button in ["Search", "FAQ", "Terms of Use", "Privacy Policy"]
    result.push({title : button})
  end for
  m.buttons.content = ContentList2SimpleNode(result)
  
  'search & activation screens
  m.search = m.top.findNode("Search")
  m.activation = m.top.findNode("Activation")
  
  'registry to check user status
  m.Registry = CreateObject("roSGNode", "RegistryHandler")
  m.Registry.observeField("content", "onRegistryContentChanged")
      
  m.Omniture = CreateObject("roSGNode", "OmnitureHandler")
  m.Omniture.observeField("finished", "onOmnitureCallFinished")
  
'  'registry to check user status
'  m.Ads = CreateObject("roSGNode", "AdHandler")
'  m.Ads.observeField("shouldPlayVideo", "onAdEnded")
   m.top.observeField("adFinishedPlaying", "onAdEnded")
   m.top.observeField("focusedChild", "OnFocusedChildChange")
   
   m.top.videoFromFront = true
   m.top.didVideoFinsh = false
  
  'nav bar within video while playing
  m.videoRowList = m.top.findNode("VideoRowList")
  m.videoRect = m.top.findNode("VideoRectangle")
  m.videoLine = m.top.findNode("VideoBlueLine")
  m.top.setFocus(true)
end sub

' Hero Grid Content handler fucntion. If content is set, stops the
' loadingIndicator and focuses on GridScreen.
sub OnChangeContent()
  'print "HeroScene.brs - [OnChangeContent]"
  m.loadingIndicator.control = "stop"
  if m.top.content <> invalid
    'Warn the user if there was a bad request
    if m.top.numBadRequests > 0
      m.HeroScreen.visible = "true"
      m.WarningDialog.visible = "true"
      m.WarningDialog.message = (m.top.numBadRequests).toStr() + " request(s) for content failed. Press '*' or OK or '<-' to continue."
    else
      m.HeroScreen.visible = "true"
      m.HeroScreen.setFocus(true)
    end if
  else
    m.WarningDialog.visible = "true"
  end if
end sub

' Row item selected handler function.
' On select any item on home scene, show Details node and hide Grid.
sub OnRowItemSelected()
  print "HeroScene.brs - [OnRowItemSelected]"
  m.videoPlayer.content = m.HeroScreen.focusedContent
  makeOmnitureCall("trackState", m.videoPlayer.content.metrics, invalid, "video", "none")
  m.top.videoFromFront = true
  m.top.didTrack33 = false
  m.top.didTrack66 = false
  m.videoRowList.content = m.HeroScreen.focusedRow
'  if m.videoPlayer.content.TEXTOVERLAYBODY = "limited"
'    m.activation.isVideoRequest = true
'    makeRegistryReq("UserInfo")
'  else
    m.top.adPlayFlag = true
'  end if
end sub

sub onVideoRowItemSelected()
  print "HeroScene.brs - [OnVideoRowItemSelected]"
  m.videoPlayer.control = "stop"
  m.videoPlayer.content = m.top.focusedVideoContent
  m.top.videoFromFront = false
'  if m.videoPlayer.content.TEXTOVERLAYBODY = "limited"
'    makeRegistryReq("UserInfo")
'  else
      m.videoRowList.visible = false
      m.videoRect.visible = false
      m.videoLine.visible = false
      m.videoPlayer.control = "play"
      m.videoPlayer.observeField("state", "OnVideoPlayerStateChange")
      m.videoPlayer.setFocus(true)
      'm.videoPlayer.observeField("position", "OnVideoPositionChange")
  'end if
end sub

' handler of focused item in RowList
sub OnVideoItemFocused()
  print "HeroScene.brs - [onVideoItemFocused]"
  itemFocused = m.top.videoItemFocused

  'When an item gains the key focus, set to a 2-element array,
  'where element 0 contains the index of the focused row,
  'and element 1 contains the index of the focused item in that row.
  if itemFocused.Count() = 2 then
    focusedContent            = m.top.videoContent.getChild(itemFocused[0]).getChild(itemFocused[1])
    if focusedContent <> invalid then
      m.top.focusedVideoContent    = focusedContent
    end if
  end if
end sub

' set proper focus on buttons and stops video if return from Playback to details
Sub onVideoVisibleChange()
  print "HeroScene.brs - [onVideoVisibleChange]"
  if m.videoPlayer.visible = false
    print "Video visible = false"
    m.videoRowList.visible = false
    m.videoRect.visible = false
    m.videoLine.visible = false
    m.HeroScreen.visible = true
    m.HeroScreen.opacity = 1.0
    m.HeroScreen.setFocus(true)
    m.videoPlayer.control = "stop"
    'makeOmnitureCall("trackState", invalid, invalid, "front", "none")
  end if
End Sub

sub onActivationVisibleChange()
    print "HeroScene.brs - [onActivationVisibleChange]"
    if m.activation.visible = false and m.activation.isActivated = false
        m.Options.visible = false
        m.buttons.visible = false
        m.optionsLabel.visible = false
        m.HeroScreen.visible = true
        m.HeroScreen.setFocus(true)
     else if m.activation.visible = false and m.activation.isActivated = true and  m.activation.isVideoRequest = true
        m.Options.visible = false
        m.buttons.visible = false
        m.optionsLabel.visible = false
        m.top.adPlayFlag = true
     else if m.activation.visible = false and m.activation.isActivated = true and  m.activation.isVideoRequest = false
        m.Options.visible = false
        m.buttons.visible = false
        m.optionsLabel.visible = false
        m.HeroScreen.visible = true
        m.HeroScreen.setFocus(true)
     end if
end sub

' event handler of Video player msg
Sub OnVideoPlayerStateChange()
  print "HeroScene.brs - [OnVideoPlayerStateChange]"
  print m.videoPlayer.state
  if m.videoPlayer.state = "error"
    ' error handling
    m.FadeOut.control = "start"
    m.videoPlayer.control = "stop"
    m.videoPlayer.visible = false
    m.HeroScreen.opacity = 1.0
    m.HeroScreen.visible = true
    m.HeroScreen.setFocus(true)
  else if m.videoPlayer.state = "playing"
    ' playback handling
    m.top.didVideoFinish = false
    makeOmnitureCall("play", m.videoPlayer.content.metrics, m.videoPlayer.content, "video", "none")
  else if m.videoPlayer.state = "stopped" and m.top.didVideoFinish = false
    print "Video stopped"
    print "Duration " + Str(m.videoPlayer.duration)
    print "Position " + Str(m.videoPlayer.position)
    makeVideoPositionReq({"videoid" : m.videoPlayer.content.id, "position" : m.videoPlayer.position})
  else if m.videoPlayer.state = "finished"
    print "Video finished"
    m.top.didVideoFinish = true
    makeOmnitureCall("finished", m.videoPlayer.content.metrics, m.videoPlayer.content, "video", "none")
    makeVideoPositionReq({"videoid" : m.videoPlayer.content.id, "position" : -1})
    m.videoPlayer.visible = false
    m.HeroScreen.visible = true
  end if
End Sub

' event handler of Video player msg
Sub OnVideoPositionChange()
  print "HeroScene.brs - [OnVideoPositionChange]"
  print m.videoPlayer.position
  percent% = (m.videoPlayer.position / m.videoPlayer.duration) * 100
  print percent%
  
  if percent% >= 33 and m.top.didTrack33 = false
    makeOmnitureCall("33percent", m.videoPlayer.content.metrics, m.videoPlayer.content, "video", "none")
    m.top.didTrack33 = true
  end if
  
  if percent% >= 66 and m.top.didTrack66 = false
    makeOmnitureCall("66percent", m.videoPlayer.content.metrics, m.videoPlayer.content, "video", "none")
    m.top.didTrack66 = true
  end if

End Sub

' on Button press handler
Sub onItemSelected()
  print "HeroScene.brs - [onOptionsItemSelected]"
  'Search
  if m.top.itemSelected = 0
    m.HeroScreen.visible="false"
    m.HeroScreen.setFocus(false)
    m.search.visible="true"
    m.search.setFocus(true)
  'Activation
'  else if m.top.itemSelected = 1
'    m.HeroScreen.visible="false"
'    m.HeroScreen.setFocus(false)
'    m.activation.visible="true"
'    m.activation.isVideoRequest = false
'    m.activation.setFocus(true)
  'FAQ
  else if m.top.itemSelected = 1 '2
    m.HeroScreen.visible="false"
    m.HeroScreen.setFocus(false)
    m.buttons.visible = false
    m.optionsLabel.visible = false
    m.Overhang.visible = false
    m.FaqText.visible = true
    m.FaqText.text = m.global.faqtext
    m.FaqText.setFocus(true)
    makeOmnitureCall("trackState", invalid, invalid, "settings", "faq")
  'Terms of Use
  else if m.top.itemSelected = 2 '3
    m.HeroScreen.visible="false"
    m.HeroScreen.setFocus(false)
    m.buttons.visible = false
    m.optionsLabel.visible = false
    m.Overhang.visible = false
    m.TosText.visible = true
    m.TosText.text = m.global.tostext
    m.TosText.setFocus(true)
    makeOmnitureCall("trackState", invalid, invalid, "settings", "terms of use")
  'Privacy Policy
  else if m.top.itemSelected = 3 '4
    m.HeroScreen.visible="false"
    m.HeroScreen.setFocus(false)
    m.buttons.visible = false
    m.optionsLabel.visible = false
    m.Overhang.visible = false
    m.PrivacyText.visible = true
    m.PrivacyText.text = m.global.privacytext
    m.PrivacyText.setFocus(true)
    makeOmnitureCall("trackState", invalid, invalid, "settings", "privacy policy")
  end if
End Sub

' Called when a key on the remote is pressed
function onKeyEvent(key as String, press as Boolean) as Boolean
  print ">>> HomeScene >> OnkeyEvent"
  result = false
  print "in HeroScene.xml onKeyEvent ";key;" "; press
  if press then
    if key = "back"
      print "------ [back pressed] ------"
      ' if WarningDialog is open
      if m.WarningDialog.visible = true
        m.WarningDialog.visible = "false"
        m.HeroScreen.setFocus(true)
        result = true
      ' if Details opened
      else if m.videoRowList.visible = true
        m.videoRowList.visible = false
        m.videoRect.visible = false
        m.videoLine.visible = false
        m.videoPlayer.setFocus(true)
        result = true
      else if m.HeroScreen.visible = false and m.videoPlayer.visible = true
        m.FadeOut.control = "start"
        m.videoPlayer.control = "stop"
        m.videoPlayer.visible = false
        m.HeroScreen.visible = "true"
        m.HeroScreen.setFocus(true)
      ' if video player opened
        result = true
      else if m.HeroScreen.visible = false and m.Search.visible = true
        m.Search.visible = false
        m.Options.visible = true
        m.optionsLabel.visible = true
        m.Overhang.visible = true
        m.buttons.visible = true
        m.buttons.setFocus(true)
        result = true
      else if m.HeroScreen.visible = false and m.Activation.visible = true and m.Activation.isVideoRequest = false
        m.Activation.visible = false
        m.Options.visible = true
        m.optionsLabel.visible = true
        m.Overhang.visible = true
        m.buttons.visible = true
        m.buttons.setFocus(true)
        result = true
      else if m.HeroScreen.visible = false and m.Activation.visible = true and m.Activation.isVideoRequest = true
        m.Activation.visible = false
        m.Options.visible = false
        m.buttons.visible = false
        m.optionsLabel.visible = false
        m.HeroScreen.visible = "true"
        m.HeroScreen.setFocus(true)
        result = true
      else if m.HeroScreen.visible = false and m.TosText.visible = true
        m.TosText.visible = false
        m.Options.visible = true
        m.optionsLabel.visible = true
        m.Overhang.visible = true
        m.buttons.visible = true
        m.buttons.setFocus(true)
        result = true
     else if m.HeroScreen.visible = false and m.FaqText.visible = true
        m.FaqText.visible = false
        m.Options.visible = true
        m.optionsLabel.visible = true
        m.Overhang.visible = true
        m.buttons.visible = true
        m.buttons.setFocus(true)
        result = true
     else if m.HeroScreen.visible = false and m.PrivacyText.visible = true
        m.PrivacyText.visible = false
        m.Options.visible = true
        m.optionsLabel.visible = true
        m.Overhang.visible = true
        m.buttons.visible = true
        m.buttons.setFocus(true)
        result = true
     else if m.Options.visible = true
        m.Options.visible = false
        m.buttons.visible = false
        m.optionsLabel.visible = false
        m.HeroScreen.visible = "true"
        m.HeroScreen.setFocus(true)
        result = true
     end if
    else if key = "OK"
      print "------- [ok pressed] -------"
      if m.WarningDialog.visible = true
        m.WarningDialog.visible = "false"
        m.HeroScreen.setFocus(true)
      end if
    else if key = "options"
      print "------ [options pressed] ------"
      m.WarningDialog.visible = "false"
      if m.Options.visible = false and m.videoPlayer.visible = false
        m.Options.visible = "true"
        m.buttons.visible = "true"
        m.optionsLabel.visible = "true"
        m.buttons.jumpToItem = 0
        m.buttons.setFocus(true)
        makeOmnitureCall("trackState", invalid, invalid, "settings", "none")
        result = true
      else if m.videoPlayer.visible = true
        'do nothing?
      else
        m.Options.visible = "false"
        m.buttons.visible = "false"
        m.optionsLabel.visible = "false"
        m.HeroScreen.setFocus(true)
        result = true
      end if
      'm.HeroScreen.setFocus(true)
    else if key = "down"
      print "------- [down pressed] -------"
      if m.videoPlayer.visible = true
        m.videoRowList.visible = true
        m.videoRect.visible = true
        m.videoLine.visible = true
        m.videoRowList.setFocus(true)
        
        if(m.videoRowList.itemFocused <> invalid) and not m.top.videoFromFront
            m.videoRowList.jumpToRowItem = m.videoRowList.itemFocused
        else
            m.videoRowList.jumpToRowItem = [0, m.HeroScreen.itemFocused[1]]
        end if
        result = true
      end if
    end if
    
'    if m.Search.visible = true
'        m.Search.setFocus(true)
'    end if
  end if
  return result
end function

'///////////////////////////////////////////'
' Helper function convert AA to Node
Function ContentList2SimpleNode(contentList as Object, nodeType = "ContentNode" as String) as Object
  print "HeroScene.brs - [ContentList2SimpleNode]"
  result = createObject("roSGNode", nodeType)
  if result <> invalid
    for each itemAA in contentList
      item = createObject("roSGNode", nodeType)
      item.setFields(itemAA)
      result.appendChild(item)
    end for
  end if
  return result
End Function

sub makeRegistryReq(info as Object)
    print "HeroScene.brs - [makeRegistryReq]"
    context = createObject("roSGNode", "Node")
    print info
    if type(info) = "roAssociativeArray"
      context.addFields({
        parameters: info,
        response: {}
      })
      m.Registry.userInfo = {
        context: context
      }
    else if type(info) = "roString"
        print "Info is String"
        context.addFields({
            section: info
        })
        m.Registry.regRequest = {
            context: context
        }
    end if
end sub

sub makeVideoPositionReq(info as Object)
    print "HeroScene.brs - [makeVideoPositionReq]"
    context = createObject("roSGNode", "Node")
    print info
    if type(info) = "roAssociativeArray"
      context.addFields({
        parameters: info,
        response: {}
      })
      m.Registry.videoPositions = {
        context: context
      }
    else if type(info) = "roString"
        print "Info is String"
        context.addFields({
            videoid: info
        })
        m.Registry.getVideoPos = {
            context: context
        }
    end if 
end sub

' Issues a URL request to the UriHandler component
sub makeOmnitureCall(reqType as String, omniture as Object, video as Object, pageType as String, pageName as String)
  print "HeroScreen.brs - [makeOmnitureCall]"
   context = createObject("roSGNode", "Node")
   
   if(pageType = "video")
    dictionary = makeVideoDictionary(omniture)
   else if(pageType = "settings")
    dictionary = makeOptionsDictionary(pageName)
   else if(pageType = "front")
    dictionary = makeFrontDictionary()
   end if
   pageName = dictionary["pageName"]
   
   if video <> invalid
       'add video metadata for videos
       dictionary["videoid"] = video.id
       dictionary["length"] = video.length
       dictionary["streamType"] = video.StreamFormat
   end if
   
   if reqType = "play" then dictionary["videoView"] = "true"
   if reqType = "finished" then dictionary["videoComplete"] = "true"
    'if type(dictionary) = "roAssociativeArray"
     context.addFields({
        reqtype: reqType,
        screen: pageName,
        dictionary: dictionary
     })
     m.Omniture.request = {
        context: context
     }

end sub

sub onRegistryContentChanged()
    print "HeroScene.brs - [onRegistryContentChanged]"

    content = m.Registry.content
    
    if(content <> invalid)
    responseString = content.response
    username = content.username
    if responseString = invalid and content.username <> "opttester"
        if content.username <> invalid
            m.top.adPlayFlag = true
        else
            m.HeroScreen.visible="false"
            m.HeroScreen.setFocus(false)
            m.videoRowList.visible = false
            m.videoRect.visible = false
            m.videoLine.visible = false
            m.videoPlayer.visible = false
            m.activation.visible="true"
            m.activation.setFocus(true)
        end if
    else if responseString = "UserIP" or content.username = "opttester"
        m.top.adPlayFlag = true
    else if responseString = "VideoPosition"
        position = content.position
        print "Got Position"
        m.FadeIn.control = "start"
        m.HeroScreen.visible = "false"
        m.videoRowList.visible = false
        m.videoRect.visible = false
        m.videoLine.visible = false
        m.videoPlayer.visible = true
        m.videoPlayer.setFocus(true)
        
        if(position <> invalid)
            print "Valid Position"
            if(type(position) = "roString")
                print "Position is string"
                positionnum = Val(position)
                if(positionnum > 0)
                    print "Position: " + Str(positionnum)
                    m.videoPlayer.seek = positionnum
                else
                    print "Position (stringz) zero or less"
                end if
            else if(position > 0) 
                print "Position is integer" 
                print "Position: " + Str(position)
                m.videoPlayer.seek = position
            else
                print "Position (int) zero or less"
            end if
        else
            print "Invalid Position"
        end if
        
        print m.videoPlayer.content
        print m.videoPlayer.content.streams
        m.videoPlayer.control = "play"
        m.videoPlayer.observeField("state", "OnVideoPlayerStateChange")
    else if responseString = "PositionStored"
        print "Position stored"
    else
        m.HeroScreen.visible="false"
        m.HeroScreen.setFocus(false)
        m.videoRowList.visible = false
        m.videoRect.visible = false
        m.videoLine.visible = false
        m.videoPlayer.visible = false
        m.activation.visible="true"
        m.activation.setFocus(true)
    end if
    end if
    
    m.Registry = invalid
    m.Registry = CreateObject("roSGNode", "RegistryHandler")
    m.Registry.observeField("content", "onRegistryContentChanged")
end sub

sub onOmnitureCallFinished()
    print "HeroScene.brs - [onOmnitureCallFinished]"
    
    doExtraPageView = false
    if m.Omniture.request.context.reqType <> invalid
        if m.Omniture.request.context.reqType = "finished" then doExtraPageView = true
    end if
    
    m.Omniture = invalid
    m.Omniture = CreateObject("roSGNode", "OmnitureHandler")
    m.Omniture.observeField("finished", "onOmnitureCallFinished")
    
    if doExtraPageView = true then makeOmnitureCall("trackState", invalid, invalid, "front", "none")
    
end sub

'sub makeAdRequest(info as Object)
'    print "HeroScene.brs - [makeAdRequest]"
'    context = createObject("roSGNode", "Node")
'    print info
'    if type(info) = "roString"
'        print "Info is String"
'        context.addFields({j
'            uri: info
'        })
'        m.Ads.request = {
'            context: context
'        }
'    end if
'end sub

sub onAdEnded()
    print "Ad Ended"
    makeVideoPositionReq(m.videoPlayer.content.id)
'    m.FadeIn.control = "start"
'    m.HeroScreen.visible = "false"
'    m.videoRowList.visible = false
'    m.videoRect.visible = false
'    m.videoLine.visible = false
'    m.videoPlayer.visible = true
'    m.videoPlayer.setFocus(true)
'    m.videoPlayer.control = "play"
'    m.videoPlayer.observeField("state", "OnVideoPlayerStateChange")
end sub

function makeVideoDictionary(omniture as Object) as Object
    dictionary = {}
    dictionary["pageName"] = omniture.pageName
    dictionary["contentTitle"] = omniture.contentTitle
    dictionary["contentHierarchy"] = omniture.hierarchy
    dictionary["contentType"] = omniture.contentType
    return dictionary
end function

function makeOptionsDictionary(pageName as String) as Object
     dictionary = {}
     
     dictionary["pageName"] = "rokutv - video - newsday:video - settings"
     dictionary["contentTitle"] = "video"
     if(pageName <> "none")
        dictionary["contentHierarchy"] = "rokutv:newsday:video:settings:" + pageName
     else
        dictionary["contentHierarchy"] = "rokutv:newsday:video:settings"
     end if
     dictionary["contentType"] = "front"
     
     return dictionary
end function

function makeFrontDictionary() as Object
     dictionary = {}
     
     dictionary["pageName"] = "rokutv - video - newsday:video - front"
     dictionary["contentTitle"] = "video"
     dictionary["contentHierarchy"] = "rokutv:newsday:video:front"
     dictionary["contentType"] = "front"
     
     return dictionary
end function

' set proper focus to RowList in case if return from Details Screen
Sub onFocusedChildChange() 
  'print "HeroScreen.brs - [onFocusedChildChange]"
  if m.top.isInFocusChain() and m.videoRowList.visible = true and not m.videoRowList.hasFocus()
     m.videoRowList.setFocus(true)
  else if m.top.isInFocusChain() and not m.HeroScreen.hasFocus()
    m.HeroScreen.setFocus(true)
  end if
End Sub

