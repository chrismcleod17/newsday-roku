' ********** Copyright 2016 Roku Corp.  All Rights Reserved. **********

 ' inits details screen
 ' sets all observers
 ' configures buttons for Details screen
sub init()
  print "Search.brs - [init]"
  m.top.observeField("visible", "onVisibleChange")
  m.top.observeField("focusedChild", "OnFocusedChildChange")   
  
  'Create a task node to fetch the UI content and populate the screen
  m.UriHandler = CreateObject("roSGNode", "UriHandler")
  m.UriHandler.observeField("content", "onContentChanged")
  
  m.Omniture = CreateObject("roSGNode", "OmnitureHandler")
  m.Omniture.observeField("finished", "onOmnitureCallFinished")
  
  m.searchfont  = CreateObject("roSGNode", "Font")
  m.searchfont.uri = "pkg:/fonts/HelveticaNeueLTStd-Md.otf"
  m.searchfont.size = 34
   
  m.searchfocusedfont  = CreateObject("roSGNode", "Font")
  m.searchfocusedfont.uri = "pkg:/fonts/HelveticaNeueLTStd-Roman.otf"
  m.searchfocusedfont.size = 34
    
  m.background = m.top.findNode("SearchBackground")  
  m.keyboard = m.top.findNode("Keyboard")
  m.button = m.top.findNode("Button")
  m.button.textFont = m.searchfont
  m.button.focusedTextFont = m.searchfocusedfont
  m.button.observeField("buttonSelected", "OnButtonSelected")
  m.rowlist = m.top.findNode("SearchRowList")
  m.videoPlayer = m.top.findNode("SearchVideoPlayer")
  m.videoPlayer.retrievingBar.filledBarBlendColor = "#0072ae"
  m.videoPlayer.retrievingBar.trackBlendColor = "#f4f4f4"
  m.fadeIn            =   m.top.findNode("fadeinAnimation")
  m.fadeOut           =   m.top.findNode("fadeoutAnimation")
  m.loading = m.top.findNode("LoadingLabel")
  m.rowlist.setFocus(false)
  
  m.top.videoFromFront = true
  
  'nav bar within video while playing
  m.videoRowList = m.top.findNode("SearchVideoRowList")
  m.videoRect = m.top.findNode("SearchVideoRectangle")
  m.videoLine = m.top.findNode("SearchVideoBlueLine")
  m.keyboard.setFocus(true)
end sub

Sub onVisibleChange()
  print "Search.brs - [onVisibleChange]"
  if m.top.visible
    m.fadeIn.control="start"
    m.keyboard.textEditBox.textColor="#000000"
    m.keyboard.textEditBox.hintTextColor="#636361"
    m.keyboard.textEditBox.hintText="Search"
    makeOmnitureCall("trackState", invalid, invalid)
  else
    m.fadeOut.control="start"
    m.videoPlayer.visible = false
    m.videoPlayer.control = "stop"
  end if
End Sub

' observer function to handle when content loads
sub onContentChanged()
  print "Search.brs - [onContentChanged]"
  response = m.UriHandler.content.getChild(0).TITLE
  
  if(response = "No Results")
    m.loading.text = response
  else
    m.rowlist.visible = true
    m.rowlist.setFocus(true)
    m.loading.visible = false
    m.top.numBadRequests = m.UriHandler.numBadRequests
    m.top.content = m.UriHandler.content
    m.videoRowList.content = m.UriHandler.content
  end if
  
  m.UriHandler = invalid
  m.UriHandler = CreateObject("roSGNode", "UriHandler")
  m.UriHandler.observeField("content", "onContentChanged")
end sub

' set proper focus to RowList in case if return from Details Screen
Sub onFocusedChildChange()
  'print "HeroScreen.brs - [onFocusedChildChange]"
  if m.top.isInFocusChain() and not m.keyboard.hasFocus() and not m.button.hasFocus() and not m.rowlist.hasFocus() and not m.videoRowList.hasFocus() then m.keyboard.setFocus(true)
End Sub

sub OnButtonSelected()
    m.top.content = invalid
    m.rowlist.visible = false
    searchString = m.keyboard.textEditBox.text
    urlString = "https://www.newsday.com/json/?view=search&type=video&q=" + searchString + "&ipp=50&device=rokutv"
    makeRequest(urlString, "Parser")
end sub

' set proper focus on buttons and stops video if return from Playback to details
Sub onVideoVisibleChange()
  print "Search.brs - [onVideoVisibleChange]"
  if m.videoPlayer.visible = false and m.top.visible = true
    'm.buttons.setFocus(true)
    m.videoRowList.visible = false
    m.videoRect.visible = false
    m.videoLine.visible = false
    m.videoPlayer.control = "stop"
    m.keyboard.visible = true
    m.rowlist.setFocus(true)
  end if
End Sub

sub buildContentPlaylist()
    m.top.contentPlaylist =  createObject("RoSGNode", "ContentNode")
    existingRow = m.top.content.getChild(m.top.itemFocused[0])
    
    for index = m.top.itemFocused[1] to existingRow.getChildCount() - 1
        item = existingRow.getChild(index)
        if(item.contenttype = 4)
            node = createObject("RoSGNode", "ContentNode")
            if(item.DESCRIPTION <> invalid) then node.setField("DESCRIPTION", item.DESCRIPTION)
            if(item.HDPOSTERURL <> invalid) then node.setField("HDPOSTERURL", item.HDPOSTERURL)
            if(item.LENGTH <> invalid) then node.setField("LENGTH", item.LENGTH)
            if(item.RELEASEDATE <> invalid) then node.setField("RELEASEDATE", item.RELEASEDATE)
            if(item.STREAMFORMAT <> invalid) then node.setField("STREAMFORMAT", item.STREAMFORMAT)
            if(item.TEXTOVERLAYBODY <> invalid) then node.setField("TEXTOVERLAYBODY",item.TEXTOVERLAYBODY)
            if(item.TITLE <> invalid) then node.setField("TITLE", item.TITLE)
            if(item.URL <> invalid) then node.setField("URL", item.URL)
            extras = {}
            extras["metrics"] = item.metrics
            node.addFields(extras)
            m.top.contentPlaylist.appendChild(node)
        end if
    end for
    
    for index = 0 to (m.top.itemFocused[1] - 1)
        item = existingRow.getChild(index)
        if(item.contenttype = 4)
            node = createObject("RoSGNode", "ContentNode")
            if(item.DESCRIPTION <> invalid) then node.setField("DESCRIPTION", item.DESCRIPTION)
            if(item.HDPOSTERURL <> invalid) then node.setField("HDPOSTERURL", item.HDPOSTERURL)
            if(item.LENGTH <> invalid) then node.setField("LENGTH", item.LENGTH)
            if(item.RELEASEDATE <> invalid) then node.setField("RELEASEDATE", item.RELEASEDATE)
            if(item.STREAMFORMAT <> invalid) then node.setField("STREAMFORMAT", item.STREAMFORMAT)
            if(item.TEXTOVERLAYBODY <> invalid) then node.setField("TEXTOVERLAYBODY",item.TEXTOVERLAYBODY)
            if(item.TITLE <> invalid) then node.setField("TITLE", item.TITLE)
            if(item.URL <> invalid) then node.setField("URL", item.URL)
            extras = {}
            extras["metrics"] = item.metrics
            node.addFields(extras)
            m.top.contentPlaylist.appendChild(node)
        end if
    end for

end sub

sub buildVideoRowContentPlaylist()
    m.top.contentPlaylist = invalid
    m.top.contentPlaylist =  createObject("RoSGNode", "ContentNode")
    print m.top.videoContent
    existingRow = m.top.videoContent.getChild(m.top.videoItemFocused[0])
    
    for index = m.top.videoItemFocused[1] to existingRow.getChildCount() - 1
        item = existingRow.getChild(index)
        node = createObject("RoSGNode", "ContentNode")
        if(item.DESCRIPTION <> invalid) then node.setField("DESCRIPTION", item.DESCRIPTION)
        if(item.HDPOSTERURL <> invalid) then node.setField("HDPOSTERURL", item.HDPOSTERURL)
        if(item.LENGTH <> invalid) then node.setField("LENGTH", item.LENGTH)
        if(item.RELEASEDATE <> invalid) then node.setField("RELEASEDATE", item.RELEASEDATE)
        if(item.STREAMFORMAT <> invalid) then node.setField("STREAMFORMAT", item.STREAMFORMAT)
        if(item.TEXTOVERLAYBODY <> invalid) then node.setField("TEXTOVERLAYBODY",item.TEXTOVERLAYBODY)
        if(item.TITLE <> invalid) then node.setField("TITLE", item.TITLE)
        if(item.URL <> invalid) then node.setField("URL", item.URL)
        extras = {}
        extras["metrics"] = item.metrics
        node.addFields(extras)
        m.top.contentPlaylist.appendChild(node)
    end for
    
    for index = 0 to (m.top.videoItemFocused[1] - 1)
        item = existingRow.getChild(index)
        if (item <> invalid)
            node = createObject("RoSGNode", "ContentNode")
            if(item.DESCRIPTION <> invalid) then node.setField("DESCRIPTION", item.DESCRIPTION)
            if(item.HDPOSTERURL <> invalid) then node.setField("HDPOSTERURL", item.HDPOSTERURL)
            if(item.LENGTH <> invalid) then node.setField("LENGTH", item.LENGTH)
            if(item.RELEASEDATE <> invalid) then node.setField("RELEASEDATE", item.RELEASEDATE)
            if(item.STREAMFORMAT <> invalid) then node.setField("STREAMFORMAT", item.STREAMFORMAT)
            if(item.TEXTOVERLAYBODY <> invalid) then node.setField("TEXTOVERLAYBODY",item.TEXTOVERLAYBODY)
            if(item.TITLE <> invalid) then node.setField("TITLE", item.TITLE)
            if(item.URL <> invalid) then node.setField("URL", item.URL)
            extras = {}
            extras["metrics"] = item.metrics
            node.addFields(extras)
            m.top.contentPlaylist.appendChild(node)
        end if
    end for

end sub

' event handler of Video player msg
Sub OnVideoPlayerStateChange()
  print "Search.brs - [OnVideoPlayerStateChange]"
  print m.videoPlayer.state
  if m.videoPlayer.state = "error"
    ' error handling
    m.videoPlayer.visible = false
  else if m.videoPlayer.state = "playing"
    makeOmnitureCall("play", m.videoPlayer.content.metrics, m.videoPlayer.content)
    ' playback handling
  else if m.videoPlayer.state = "finished"
    print m.videoPlayer.content
    if m.videoPlayer.content <> invalid
        makeOmnitureCall("finished", m.videoPlayer.content.metrics, m.videoPlayer.content)
    end if
    m.videoPlayer.visible = false

  end if
End Sub

' event handler of Video player msg
Sub OnVideoPositionChange()
  print "Search.brs - [OnVideoPlayerStateChange]"
  print m.videoPlayer.position
  percent% = (m.videoPlayer.position / m.videoPlayer.duration) * 100
  print percent%
  
  if percent >= 33 and m.top.didTrack33 = false
    makeOmnitureCall("33percent", m.videoPlayer.content.metrics, m.videoPlayer.content)
    m.top.didTrack33 = true
  end if
  
  if percent >= 66 and m.top.didTrack66 = false
    makeOmnitureCall("66percent", m.videoPlayer.content.metrics, m.videoPlayer.content)
    m.top.didTrack66 = true
  end if

End Sub

' Issues a URL request to the UriHandler component
sub makeRequest(URL as String, ParserComponent as String)
  'print "HeroScreen.brs - [makeRequest]"
   context = createObject("roSGNode", "Node")
   uri = { uri: URL }
   if type(uri) = "roAssociativeArray"
     context.addFields({
       parameters: uri,
       num: 0,
       response: {}
     })
     m.UriHandler.request = {
       context: context
       parser: ParserComponent
     }
   end if
   
   m.loading.text = "Loading..."
   m.loading.visible = true
end sub

' Issues a URL request to the UriHandler component
sub makeOmnitureCall(reqType as String, omniture as Object, video as Object)
  'print "HeroScreen.brs - [makeRequest]"
   context = createObject("roSGNode", "Node")
   
   if reqType = "play" or reqType = "finished"
      dictionary = makeVideoDictionary(omniture)
   else
      dictionary = makeSearchDictionary(omniture)
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
   'end if

end sub

' handler of focused item in RowList
sub OnItemFocused()
  print "Search.brs - [onItemFocused]"
  itemFocused = m.top.itemFocused
  'print m.top.itemFocused

  'When an item gains the key focus, set to a 2-element array,
  'where element 0 contains the index of the focused row,
  'and element 1 contains the index of the focused item in that row.
  if itemFocused.Count() = 2 then
    focusedContent            = m.top.content.getChild(itemFocused[0]).getChild(itemFocused[1])
    if focusedContent <> invalid then
      m.top.focusedContent    = focusedContent
    end if
  end if
end sub

' Row item selected handler function.
' On select any item on home scene, show Details node and hide Grid.
sub OnRowItemSelected()
  print "Search.brs - [OnRowItemSelected]"
  'print m.top.focusedContent
  'print m.top.focusedContent
   m.top.videoFromFront = true
  m.videoPlayer.content = m.top.focusedContent
  makeOmnitureCall("trackAction", m.top.focusedContent.metrics, invalid)
  m.FadeIn.control = "start"
  m.videoPlayer.visible = true
  m.keyboard.visible = "false"
  m.videoPlayer.setFocus(true)
  m.videoPlayer.control = "play"
  m.videoPlayer.observeField("state", "OnVideoPlayerStateChange")
'  m.videoPlayer.observeField("position", "OnVideoPositionChange")
end sub

sub onVideoRowItemSelected()
  print "Search.brs - [OnVideoRowItemSelected]"
  m.top.videoFromFront = false
  m.videoPlayer.control = "stop"
  m.videoPlayer.content = m.top.focusedVideoContent
  m.videoRowList.visible = false
  m.videoRect.visible = false
  m.videoLine.visible = false
  m.videoPlayer.control = "play"
  m.videoPlayer.observeField("state", "OnVideoPlayerStateChange")
  m.videoPlayer.setFocus(true)
  'm.videoPlayer.observeField("position", "OnVideoPositionChange")
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

sub onOmnitureCallFinished()
    print "HeroScene.brs - [onOmnitureCallFinished]"
    
    doExtraPageView = false
    if m.Omniture.request.context.reqType <> invalid
        if m.Omniture.request.context.reqType = "finished" then doExtraPageView = true
    end if
    
    m.Omniture = invalid
    m.Omniture = CreateObject("roSGNode", "OmnitureHandler")
    m.Omniture.observeField("finished", "onOmnitureCallFinished")
    
    if doExtraPageView = true then makeOmnitureCall("trackState", invalid, invalid)
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
  print ">>> Search >> OnkeyEvent"
  result = false
  print "in Search.brs onKeyEvent ";key;" "; press
  if press then
    if key = "back"
      print "------ [back pressed] ------"
      if m.keyboard.visible = false and m.videoPlayer.visible = true and m.videoRowList.visible = false
        m.FadeOut.control = "start"
        m.videoPlayer.control = "stop"
        m.videoPlayer.visible = false
        'm.background.opacity="1.0"
        m.keyboard.visible = "true"
        m.rowlist.setFocus(true)
      ' if video player opened
        result = true
      else if m.videoRowList.visible = true
        m.videoRowList.visible = false
        m.videoRect.visible = false
        m.videoLine.visible = false
        m.videoPlayer.setFocus(true)
        result = true
      end if
    end if
    if key = "right" and m.rowlist.hasFocus() = false
      print "------ [right pressed] ------"
        m.button.setFocus(true)
        result = true
    end if
    else if key = "left" and m.rowlist.hasFocus() = false
      print "----- [left pressed] -------"
      m.keyboard.setFocus(true)
      result = true
    else if key = "down" and m.rowlist.hasFocus() = false and m.button.hasFocus() = false and m.videoPlayer.visible = false
      print "---down pressed---"
      m.button.setFocus(true)
      'm.rowlist.setFocus(true)
      m.keyboard.setFocus(false)
      result = true
    else if key = "down" and m.rowlist.hasFocus() = false and m.button.hasFocus() = true and m.videoPlayer.visible = false
      print "---down pressed---"
      m.button.setFocus(false)
      m.rowlist.setFocus(true)
      'm.keyboard.setFocus(false)
      result = true
    else if key = "up" and m.rowlist.hasFocus() = true
      print "---up pressed---"
      m.button.setFocus(true)
      m.rowlist.setFocus(false)
      result = true
    else if key = "up" and m.button.hasFocus() = true
      print "---up pressed---"
      m.keyboard.setFocus(true)
      m.button.setFocus(false)
      result = true
    else if key = "down" and m.videoPlayer.visible = true
      print "------- [down pressed] -------"
       m.videoRowList.visible = true
       m.videoRect.visible = true
       m.videoLine.visible = true
       m.keyboard.setFocus(false)
       m.videoRowList.setFocus(true)
       if(m.videoRowList.itemFocused <> invalid) and not m.top.videoFromFront
           m.videoRowList.jumpToRowItem = m.videoRowList.itemFocused
       else
           m.videoRowList.jumpToRowItem = m.rowList.rowItemFocused
        end if
       result = true
    end if
  return result
end function

function makeSearchDictionary(omniture as Object) as Object
     dictionary = {}
     
     if omniture <> invalid
        dictionary["pageName"] = omniture.pageName
        dictionary["contentTitle"] = omniture.contentTitle
        dictionary["contentHierarchy"] = omniture.hierarchy
        dictionary["contentType"] = omniture.contentType
     else
        dictionary["pageName"] = "rokutv - video - newsday:video - search"
        dictionary["contentTitle"] = "video"
        dictionary["contentHierarchy"] = "rokutv:newsday:video:search"
        dictionary["contentType"] = "front"
     end if
     
     return dictionary
end function

function makeVideoDictionary(omniture as Object) as Object
    dictionary = {}
    
    if(omniture <> invalid)
        dictionary["pageName"] = omniture.pageName
        dictionary["contentTitle"] = omniture.contentTitle
        dictionary["contentHierarchy"] = omniture.hierarchy
        dictionary["contentType"] = omniture.contentType
    else
        dictionary["pageName"] = "rokutv - video - newsday:video - search"
        dictionary["contentTitle"] = "video"
        dictionary["contentHierarchy"] = "rokutv:newsday:video:search"
        dictionary["contentType"] = "front"
    end if
    return dictionary
end function
