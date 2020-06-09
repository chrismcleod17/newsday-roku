' ********** Copyright 2016 Roku Corp.  All Rights Reserved. **********

sub init()
  print "Parser.brs - [init]"
end sub

' Parses the response string as XML
' The parsing logic will be different for different RSS feeds
sub parseResponse()
  print "Parser.brs - [parseResponse]"
  str = m.top.response.content
  num = m.top.response.num

  if str = invalid return
   contentAA = {}
   filesystem = CreateObject("roFileSystem")
   responseJson = ParseJson(str)
   if responseJson <> invalid and responseJson.content <> invalid
        'print responseJson.content
        
        if m.UriHandler = invalid then m.UriHandler = m.top.getParent()
            m.UriHandler.numRows = responseJson.content.Count()
        
        imageNum = 0
        m.UriHandler.omniture = responseJson.omniture
        
        for each key in responseJson.content
            result = []
            videoAA = responseJson.content[key]
            index = videoAA.index.toInt()
            label = videoAA.label
            items = videoAA.items
            logo = invalid
            print videoAA.logo
            if videoAA.logo <> invalid
                logo = videoAA.logo
            else
                logo = invalid
            end if
            
            print "Logo is "
            print logo
            for each part in items
                'download image to temp file and then set image URI to temp file location????
                'filename = "tmp:/image" + imageNum.toStr() + ".jpg"
                'filename2 = "file://" + filename
                if(part.image <> invalid)
                    if(index = 0)
                        uri = part.image.image_path_large
                    else
                        uri = part.image.image_path_list
                    end if
                    'GetURL_Image(filename, uri, filesystem)
                    'imageNum++
                    item = {}
                    item.hdposterurl = uri 'filename2 
                    item.uri = uri 'filename2
                end if
                item.rowNum = index
                item.releaseDate = part.time
                if(part.duration <> invalid)
                    item.length = (part.duration / 1000)
                 end if
                item.TextOverlayBody =  part.access
                item.title = part.title
                item.description = part.summary
                item.id = part.brightCoveAssetId
                if(item.id <> invalid)
                    GetRenditionsForVideo(item)
                    
                    if(item.streams <> invalid)
                        item.url = item.streams.url
                    end if
                else if (part.link <> invalid)
                    'print "Here!"
                    'print part.link
                    item.stream = {url: part.link} 
                    item.link = part.link
                    item.url = part.link
                    item.streamFormat = "mp4"
                end if
                item.metrics = part.omniture
                result.push(item)
            end for
                   
            content = invalid
            content = createRow(result, label, logo)
       
            'Add the newly parsed content row/grid to the cache until everything is ready
            if content <> invalid
                print "INDEX IS " + index.toStr()
                contentAA[index.toStr()] = content
                if m.UriHandler = invalid then m.UriHandler = m.top.getParent()
                m.UriHandler.contentCache.addFields(contentAA)
            else
                print "Error: content was invalid"
            end if
         end for
    else 
        result = []
        if responseJson <> invalid
            print "----Request from search ---"
            print responseJson
        
            if m.UriHandler = invalid then m.UriHandler = m.top.getParent()
                m.UriHandler.numRows = 1
            
            m.UriHandler.omniture = responseJson.omniture
            m.UriHandler.searchterm = responseJson.searchTerm
        
            imageNum = 0
            
        
            label =  invalid
        
            for each part in responseJson.results[0].headlines
                label="Results"
                item = {}
                if part.image <> invalid
                    item.hdposterurl =  part.image.image_path_list
                    item.uri = part.image.image_path_list
                end if
                item.releaseDate = part.time
                item.length = (part.duration / 1000)
                item.id = part.brightCoveAssetId
                if(item.id <> invalid)
                    GetRenditionsForVideo(item)
                else if (part.link <> invalid)
                    item.stream = {url: part.link} 
                    item.link = part.link
                    item.url = part.link
                    item.streamFormat = "mp4"
                end if
                item.title = part.title
                item.description = part.summary
                ' print "Search Omniture"
                'print part.omniture
                item.metrics = part.omniture
                result.push(item)
            end for
        else
            label = invalid
        end if
        
        content = invalid
        
        if label = invalid then label = "No Results"
        
        content = createRow(result, label, invalid)
       
        'Add the newly parsed content row/grid to the cache until everything is ready
        if content <> invalid
           contentAA["0"] = content
           if m.UriHandler = invalid then m.UriHandler = m.top.getParent()
           m.UriHandler.contentCache.addFields(contentAA)
         else
           print "Error: content was invalid"
          end if
    end if

end sub

function GetURL_Image(filename as String, uri as String, filesystem as Object)
    if filesystem.Exists(filename)
        print "File exists, delete"
        filesystem.Delete(filename)
    end if
    
    http = CreateObject("roUrlTransfer")
    http.SetPort(CreateObject("roMessagePort"))
    http.SetUrl(uri)
    http.SetCertificatesFile("pkg:/certs/cacert.pem")
    http.InitClientCertificates()
    http.GetToFile(filename)
   
end function

'Create a row of content
function createRow(list as object, label as String, logo as Object)
  print "Parser.brs - [createRow]"
  Parent = createObject("RoSGNode", "ContentNode")
  row = createObject("RoSGNode", "ContentNode")
  row.Title = label
  if logo <> invalid
    row.addFields({"logo": logo})
  end if
  for each itemAA in list
    'print itemAA
    item = createObject("RoSGNode","ContentNode")
    AddAndSetFields(item, itemAA)
    'print item
    row.appendChild(item)
  end for
  Parent.appendChild(row)
  return Parent
end function