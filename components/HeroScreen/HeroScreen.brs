' ********** Copyright 2016 Roku Corp.  All Rights Reserved. **********

' Called when the HeroScreen component is initialized
sub Init()
  'Uncomment the print statements to see where and when the functions are called
  'print "HeroScreen.brs - [init]"

  'Get references to child nodes
  m.RowList       =   m.top.findNode("RowList")
  m.background    =   m.top.findNode("Background")

  'Create a task node to fetch the UI content and populate the screen
  m.UriHandler = CreateObject("roSGNode", "UriHandler")
  m.UriHandler.observeField("content", "onContentChanged")

  'Make a request for each "row" in the UI (in the order that you want content filled)
   URLs = [ "http://www.newsday.com/json/video?device=rokutv" ]
   'URLs = [ "https://stage.newsday.com/iosfeeds/video?device=rokutv" ]
   makeRequest(URLs,"Parser")

  'Create observer events for when content is loaded
  m.top.observeField("visible", "onVisibleChange")
  m.top.observeField("focusedChild", "OnFocusedChildChange")
end sub

' Issues a URL request to the UriHandler component
sub makeRequest(URLs as object, ParserComponent as String)
  'print "HeroScreen.brs - [makeRequest]"
  for i = 0 to URLs.count() - 1
    context = createObject("roSGNode", "Node")
    uri = { uri: URLs[i] }
    if type(uri) = "roAssociativeArray"
      context.addFields({
        parameters: uri,
        num: i,
        response: {}
      })
      m.UriHandler.request = {
        context: context
        parser: ParserComponent
      }
    end if
  end for
end sub

' observer function to handle when content loads
sub onContentChanged()
  'print "HeroScreen.brs - [onContentChanged]"
  m.top.numBadRequests = m.UriHandler.numBadRequests
  m.top.content = m.UriHandler.content
end sub

' handler of focused item in RowList
sub OnItemFocused()
  'print "HeroScreen.brs - [onItemFocused]"
  itemFocused = m.top.itemFocused

  'When an item gains the key focus, set to a 2-element array,
  'where element 0 contains the index of the focused row,
  'and element 1 contains the index of the focused item in that row.
  if itemFocused.Count() = 2 then
    focusedContent            = m.top.content.getChild(itemFocused[0]).getChild(itemFocused[1])
    focusedRow = m.top.content.getChild(itemFocused[0])
    if focusedContent <> invalid then
      m.top.focusedContent    = focusedContent
    end if
    
    if focusedRow <> invalid then
        Parent = createObject("RoSGNode", "ContentNode")
        rowCopy = createObject("RoSGNode", "ContentNode")
        for i = 0 to focusedRow.getChildCount() - 1
            item = m.top.content.getChild(itemFocused[0]).getChild(i)
            if item <> invalid
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
                'print node

               rowCopy.appendChild(node)
            end if
        end for
        Parent.appendChild(rowCopy)
        m.top.focusedRow = Parent
    end if
  end if
end sub

' sets proper focus to RowList in case channel returns from Details Screen
sub onVisibleChange()
  'print "HeroScreen.brs - [onVisibleChange]"
  if m.top.visible then m.rowList.setFocus(true)
end sub

' set proper focus to RowList in case if return from Details Screen
Sub onFocusedChildChange() 
  'print "HeroScreen.brs - [onFocusedChildChange]"
  if m.top.isInFocusChain() and not m.rowList.hasFocus() then m.rowList.setFocus(true)
End Sub


