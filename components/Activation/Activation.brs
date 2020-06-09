' ********** Copyright 2016 Roku Corp.  All Rights Reserved. **********

 ' inits details screen
 ' sets all observers
 ' configures buttons for Details screen
sub init()
  print "Activation.brs - [init]"
  m.top.observeField("visible", "onVisibleChange")
  
  m.background = m.top.findNode("ActivationBackground")  
'  m.fadeIn =   m.top.findNode("fadeinAnimation")
'  m.fadeOut =   m.top.findNode("fadeoutAnimation")
  
  m.loading = m.top.findNode("LoadingLabel")
  
  m.timer = m.top.findNode("testTimer")
  m.timer.ObserveField("fire","doCheckReq")
  
  m.exclusive = m.top.findNode("ContentExclusiveLabel")
  m.listlabel1 = m.top.findNode("ListLabel1")
  m.listlabel2 = m.top.findNode("ListLabel2")
  m.listlabel3 = m.top.findNode("ListLabel3")
  
  m.codeLabel  = m.top.findNode("CodeLabel")
  
  m.loggedinlabel = m.top.findNode("LoggedInLabel")
  
  m.CodeHandler = CreateObject("roSGNode", "CodeHandler")
  m.CodeHandler.observeField("content", "onContentChanged")
  
  m.Registry = CreateObject("roSGNode", "RegistryHandler")
  m.Registry.observeField("content", "onRegistryContentChanged")
  
  m.searchfont  = CreateObject("roSGNode", "Font")
  m.searchfont.uri = "pkg:/fonts/HelveticaNeueLTStd-Md.otf"
  m.searchfont.size = 34
   
  m.searchfocusedfont  = CreateObject("roSGNode", "Font")
  m.searchfocusedfont.uri = "pkg:/fonts/HelveticaNeueLTStd-Roman.otf"
  m.searchfocusedfont.size = 34
  
  m.Button = m.top.findNode("Button")
  m.Button.textFont = m.searchfont
  m.Button.focusedTextFont = m.searchfocusedfont
  m.Button.observeField("buttonSelected", "OnButtonSelected")
  
  m.counter = 0
  
  m.top.isActivated = false
  m.top.isVideoRequest = false
   
  m.top.setFocus(true)
end sub

' set proper focus to buttons if Details opened and stops Video if Details closed
Sub onVisibleChange()
  print "Activation.brs - [onVisibleChange]"
  if m.top.visible
   'm.fadeIn.control="start"
    m.codeLabel.visible = false
    makeRegistryReq("UserInfo")
  else
   ' m.fadeOut.control="start"
  end if
End Sub

sub makeCodeReq()
    print "Activation.brs - [makeCodeReq]"
    context = createObject("roSGNode", "Node")
    uri = { uri: "https://www.newsday.com/device/accountservices?serviceType=getAppleTVCode" }
    if type(uri) = "roAssociativeArray"
      context.addFields({
        parameters: uri,
        response: {}
      })
      m.CodeHandler.request = {
        context: context
      }
    end if
end sub

sub makeCheckReq(code as String)
    print "Activation.brs - [makeCheckReq]"
    m.counter++
    print "Counter is " + StrI(m.counter)
    if m.counter = 50
        print "15 minutes without claiming, dismissing window"
        m.codeLabel.visible = false
        m.top.visible = false
    else
        context = createObject("roSGNode", "Node")
        uri = { uri: "https://www.newsday.com/device/accountservices?serviceType=checkAppleTVCode&activationCode=" + code }
        if type(uri) = "roAssociativeArray"
        context.addFields({
            parameters: uri,
            response: {}
        })
        m.CodeHandler.request = {
            context: context
         }
        end if
    end if
end sub

' observer function to handle when content loads
sub onContentChanged()
    print "Activation.brs - [onContentChanged]"
    if m.top.visible = true
        responseString = m.CodeHandler.content.response
        if responseString.InStr("code succesfully created") <> -1
            m.codeLabel.visible = true
            m.codeLabel.text = m.CodeHandler.content.code
            m.top.code = m.CodeHandler.content.code
            m.counter = 0
            m.timer.control = "start"
        else if responseString.InStr("code has not yet been claimed") <> -1
            m.timer.control = "start"
        else if responseString.InStr("claimed successfully") <> -1
            m.top.isActivated = true
            makeRegistryReq(m.CodeHandler.content)
            m.codeLabel.visible = false
            m.top.visible = false
        end if
    end if
end sub

sub doCheckReq()
    makeCheckReq(m.top.code)
    m.timer.control = "stop"
end sub

sub makeRegistryReq(info as Object)
    print "Activation.brs - [makeRegistryReq]"
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

sub onRegistryContentChanged()
    print "Activation.brs - [onRegistryContentChanged]"
    content = m.Registry.content
    responseString = content.response
    username = content.username
    if responseString = invalid and content.username <> "opttester"
        if content.username <> invalid
            m.exclusive.visible = false
            m.listlabel1.visible = false
            m.listlabel2.visible = false
            m.listlabel3.visible = false
            m.codelabel.visible = false
            m.loggedinlabel.text = "You are logged in as " + username
            m.loggedinlabel.visible = true
            m.button.visible = true
            m.button.setFocus(true)
        else
            makeCodeReq()
        end if
    else if responseString = "UserIP" or content.username = "opttester"
            m.top.isActivated = true
            m.exclusive.visible = false
            m.listlabel1.visible = false
            m.listlabel2.visible = false
            m.listlabel3.visible = false
            m.codelabel.visible = false
            m.loggedinlabel.text = "You are logged in"
            m.loggedinlabel.visible = true
            m.button.visible = true
            m.button.setFocus(true)
    else
        makeCodeReq()
    end if
end sub

sub onButtonSelected()
    print "Activation.brs - [onButtonSelected]"
    makeRegistryReq("LogOut")
    m.top.isActivated = false
    m.exclusive.visible = true
    m.listlabel1.visible = true
    m.listlabel2.visible = true
    m.listlabel3.visible = true
    m.codelabel.visible = false
    m.loggedinlabel.visible = false
    m.button.visible = false
    m.top.visible = false
end sub
