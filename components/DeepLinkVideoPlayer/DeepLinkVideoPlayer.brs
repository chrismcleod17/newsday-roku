
' 1st function that runs for the scene on channel startup
sub init()
  'To see print statements/debug info, telnet on port 8089
  print "DeepLinkVideoPlayer.brs - [init]"
  m.VideoPlayer = m.top.FindNode("VideoPlayer")
  m.VideoPlayer.retrievingBar.filledBarBlendColor = "#0072ae"
  m.VideoPlayer.retrievingBar.trackBlendColor = "#f4f4f4"
  m.WarningDialog = m.top.findNode("WarningDialog")

  'activation screens
  m.activation = m.top.findNode("Activation")

  'Create observer events for when content is loaded
  m.top.observeField("visible", "onVisibleChange")
  
  m.top.videoFinishedFlag = false
  
  m.top.setFocus(true)
end sub

' sets proper focus to RowList in case channel returns from Details Screen
sub onVisibleChange()
  print "DeepLinkVideoPlayer.brs - [onVisibleChange]"
  if m.top.visible
    m.VideoPlayer.content = m.top.content
    m.VideoPlayer.visible = true
    m.VideoPlayer.control = "play"
  else
    print "Invisible!"
    m.VideoPlayer.control = "stop"
  end if
end sub

sub OnChangeContent()
  print "DeepLinkVideoPlayer.brs - [OnChangeContent]"
  if m.top.content <> invalid
    m.VideoPlayer.content = m.top.content
    m.VideoPlayer.visible = true
    m.VideoPlayer.control = "play"
  else
    m.WarningDialog.visible = "true"
  end if
end sub

sub onVideoStateChange()
  print "DeepLinkVideoPlayer.brs - [onVideoStateChange]"
  if m.top.videoState = "playing"
   'video playing
    m.VideoPlayer.setFocus(true)
  else if m.top.videoState = "stopped" or m.top.videoState = "finished"
    m.top.visible = false
    m.top.videoFinishedFlag = true
  end if
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
  print ">>> DeepLinkVideoPlayer >> OnkeyEvent"
  result = false
  print "in DeepLinkVideoPlayer.xml onKeyEvent ";key;" "; press
  if press then
    if key = "back"
      print "------ [back pressed] ------"
      m.top.videoFinishedFlag = true
      m.top.visible = false
    end if
   end if
end function