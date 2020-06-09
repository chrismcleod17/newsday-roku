''
'' Retrieves playlist and video information that begin with a Smart Player.
'' If you are using a Brightcove Player instead, see BrightcovePlayerAPI
''

function BrightcoveMediaAPI()
  this = {
    GetPlaylistConfig: GetPlaylistConfig
    GetPlaylists: GetPlaylists
    GetVideosForPlaylist: GetVideosForPlaylist
    GetRenditionsForVideo: GetRenditionsForVideo
  }
  return this
end function

function GetPlaylistConfig() as Object
  configUrl = "http://api.brightcove.com/services/library?command=find_playlists_for_player_id&player_id=" + Config().playerID +"&playlist_fields=id,name,thumbnailURL&token=" + Config().brightcoveToken
  'print "configUrl: " ; configUrl
  out = {
    playlists: [], thumbs: {}
  }
  raw = GetStringFromURL(configUrl)
  playlists = ParseJSON(raw)

  ' Brightcove does not have multiple thumbnails for playlists, so we'll use the HD one and scale down
  for each list in playlists.items
    'print "List: " ; list.id
    out.playlists.push(list.id)
    out.thumbs[list.id]  = list.thumbnailurl
  next
  return out
End Function

function GetPlaylists(playlists = [], thumbs = [])
  result = []
  playlistFilter = {}
  lists = ""
  for each playlist in playlists
    playlistFilter.AddReplace(playlist, "")
    lists = lists + playlist + ","
  next
  lists = Left(lists, Len(lists) - 1 )
  'print lists
  ' Can we just grab the correct playlists?
  raw = GetStringFromURL("http://api.brightcove.com/services/library?command=find_playlists_by_ids&playlist_ids="+lists+"&playlist_fields=name,id,thumbnailurl,shortdescription,videos&video_fields=thumbnailurl,longdescription,VIDEOSTILLURL&sort_by=publish_date&sort_order=DESC&get_item_count=true&token=" + Config().brightcoveToken)

  ' print "Getting Playlists\n";raw
  json = ParseJSON(raw)

  if json = invalid then
    return false
  end if

  for each item in json.items
    'PrintAA(item)

    if item <> invalid and playlists.Count() > 0 and playlistFilter.DoesExist(ValidStr(item.id))
      print "Adding playlist ";item.id

      newPlaylist = {
        playlistID:             ValidStr(item.id)
        shortDescriptionLine1:  ValidStr(item.name)
        shortDescriptionLine2:  Left(ValidStr(item.shortdescription), 60)
      }

      if (thumbs[item.id] <> invalid)
        transportAgnosticUrl = strReplace(thumbs[item.id], "https", "http")
        newPlaylist.sdPosterURL = ValidStr(transportAgnosticUrl)
        newPlaylist.hdPosterURL = ValidStr(transportAgnosticUrl)
      else
        newPlaylist.sdPosterURL = ValidStr(item.videos[0].videostillurl)
        newPlaylist.hdPosterURL = ValidStr(item.videos[0].videostillurl)
      end if

      'PrintAA(newPlaylist)
      result.Push(newPlaylist)
    else
      print "Skipping empty playlist ";item.id
    end if
  next

  return result
end function

function GetVideosForPlaylist(playlistID)
  result = []

  ' grabbing all the data for the playlist at once can result in a huge chunk of JSON and processing that into a BS structure can crash the box
  raw = GetStringFromURL("http://api.brightcove.com/services/library?command=find_playlist_by_id&media_delivery=http&video_fields=id,publisheddate,tags,length,name,thumbnailurl,shortdescription,videostillurl&playlist_id=" + playlistID + "&token=" + Config().brightcoveToken)
  ' print "Getting Videos";raw

  json = ParseJSON(raw)

  if json = invalid then
    return false
  end if

  for each video in json.videos
    'PrintAA(video)

    transportAgnosticUrl = strReplace(video.videostillurl, "https", "http")

    newVid = {
      id:                      ValidStr(video.id)
      contentId:               ValidStr(video.id)
      shortDescriptionLine1:   ValidStr(video.name)
      title:                   ValidStr(video.name)
      description:             ValidStr(video.shortdescription)
      synopsis:                ValidStr(video.shortdescription)
      sdPosterURL:             ValidStr(transportAgnosticUrl)
      hdPosterURL:             ValidStr(transportAgnosticUrl)
      length:                  Int(StrToI(ValidStr(video.length)) / 1000)
      streams:                 []
      streamFormat:            "mp4"
      contentType:             "episode"
      categories:              []
    }

    date = CreateObject("roDateTime")
    date.FromSeconds(StrToI(Left(ValidStr(video.publisheddate), Len(ValidStr(video.publisheddate)) - 3)))
    newVid.releaseDate = date.asDateStringNoParam()
    for each tag in video.tags
      ' print "Adding Tag ";tag
      newVid.categories.Push(ValidStr(tag))
    next

    result.Push(newVid)
  next

  return result
end function

sub GetRenditionsForVideo(video)
  ' grabbing all the data for the playlist at once can result in a huge chunk of JSON and processing that into a BS structure can crash the box
  'rendURL = "http://api.brightcove.com/services/library?command=find_video_by_id&media_delivery=http&video_fields=renditions&video_id=" + video.id + "&token=bAhFO_ah56-Nrl_7ysAeO4tmvIq1fbvfEuVmKmMTfn0o2SL8gGNQfw.."
  rendURL = "https://stage.newsday.com/videoCloudService?brightcoveId=" + video.id
  'print "Rendition URL: "; rendURL
  raw = GetStringFromURL(rendURL)
  json = ParseJSON(raw)
  'PrintAA(json)
  'print json

  if json = invalid then
    return
  end if
  
  videoUrl = ""
  
  if json.videoUrlForTv = invalid
    videoUrl = json.videoUrlForTv
  else
    videoUrl = json.videoUrl
  end if
  
  newStream = {
        url:  ValidStr(videoUrl)
  }
    
    video.url = ValidStr(videoUrl)
    video.streams = newStream
    video.streamformat = "MP4"

'  for each rendition in json.renditions
'    ' FIXME: allow HLS streams here?  They all may just work, but this still needs to be
'    ' tried out.  RTMP streams would still need to be excluded.
'    if UCase(ValidStr(rendition.videocontainer)) = "MP4" and UCase(ValidStr(rendition.videocodec)) = "H264"
'
'      newStream = {
'        url:  ValidStr(rendition.url)
'        bitrate: Int(StrToI(ValidStr(rendition.encodingrate)) / 1000)
'      }
'
'      if StrToI(ValidStr(rendition.frameheight)) > 720
'        video.fullHD = true
'      end if
'      if StrToI(ValidStr(rendition.frameheight)) > 480
'        video.isHD = true
'        video.hdBranded = true
'        newStream.quality = true
'      end if
'
'      video.streams = newStream
'    end if
'  next
end sub

function GetStringFromURL(url, bcovPolicy = "")
  result = ""
  timeout = 10000

   ut = CreateObject("roURLTransfer")
 
   ' allow for https
   ut.SetCertificatesFile("common:/certs/ca-bundle.crt")
   ut.AddHeader("X-Roku-Reserved-Dev-Id", "")
   ut.InitClientCertificates()
 
  ut.SetPort(CreateObject("roMessagePort"))
   if bcovPolicy <> ""
     ut.AddHeader("BCOV-Policy", bcovPolicy)
   end if
   ut.SetURL(url)
  if ut.AsyncGetToString()
    event = wait(timeout, ut.GetPort())
    if type(event) = "roUrlEvent"
      print ValidStr(event.GetResponseCode())
      result = event.GetString()
    else if event = invalid
      ut.AsyncCancel()
      ' reset the connection on timeouts
      'ut = CreateURLTransferObject(url)
      'timeout = 2 * timeout
    else
      print "roUrlTransfer::AsyncGetToString(): unknown event"
    endif
  end if

  return result

end function


'******************************************************
' validstr
'
' always return a valid string. if the argument is
' invalid or not a string, return an empty string
'******************************************************
Function validstr(obj As Dynamic) As String
    if isnonemptystr(obj) return obj
    return ""
End Function


'******************************************************
'isstr
'
'Determine if the given object supports the ifString interface
'******************************************************
Function isstr(obj as dynamic) As Boolean
    if obj = invalid return false
    if GetInterface(obj, "ifString") = invalid return false
    return true
End Function


'******************************************************
'isnonemptystr
'
'Determine if the given object supports the ifString interface
'and returns a string of non zero length
'******************************************************
Function isnonemptystr(obj)
    if isnullorempty(obj) return false
    return true
End Function


'******************************************************
'isnullorempty
'
'Determine if the given object is invalid or supports
'the ifString interface and returns a string of non zero length
'******************************************************
Function isnullorempty(obj)
    if obj = invalid return true
    if not isstr(obj) return true
    if Len(obj) = 0 return true
    return false
End Function


'******************************************************
'isbool
'
'Determine if the given object supports the ifBoolean interface
'******************************************************
Function isbool(obj as dynamic) As Boolean
    if obj = invalid return false
    if GetInterface(obj, "ifBoolean") = invalid return false
    return true
End Function


'******************************************************
'isfloat
'
'Determine if the given object supports the ifFloat interface
'******************************************************
Function isfloat(obj as dynamic) As Boolean
    if obj = invalid return false
    if GetInterface(obj, "ifFloat") = invalid return false
    return true
End Function


'******************************************************
'strtobool
'
'Convert string to boolean safely. Don't crash
'Looks for certain string values
'******************************************************
Function strtobool(obj As dynamic) As Boolean
    if obj = invalid return false
    if type(obj) <> "roString" return false
    o = strTrim(obj)
    o = Lcase(o)
    if o = "true" return true
    if o = "t" return true
    if o = "y" return true
    if o = "1" return true
    return false
End Function


'******************************************************
'itostr
'
'Convert int to string. This is necessary because
'the builtin Stri(x) prepends whitespace
'******************************************************
Function itostr(i As Integer) As String
    str = Stri(i)
    return strTrim(str)
End Function


'******************************************************
'Get remaining hours from a total seconds
'******************************************************
Function hoursLeft(seconds As Integer) As Integer
    hours% = seconds / 3600
    return hours%
End Function


'******************************************************
'Get remaining minutes from a total seconds
'******************************************************
Function minutesLeft(seconds As Integer) As Integer
    hours% = seconds / 3600
    mins% = seconds - (hours% * 3600)
    mins% = mins% / 60
    return mins%
End Function


'******************************************************
'Pluralize simple strings like "1 minute" or "2 minutes"
'******************************************************
Function Pluralize(val As Integer, str As String) As String
    ret = itostr(val) + " " + str
    if val <> 1 ret = ret + "s"
    return ret
End Function


'******************************************************
'Trim a string
'******************************************************
Function strTrim(str As String) As String
    st=CreateObject("roString")
    st.SetString(str)
    return st.Trim()
End Function


'******************************************************
'Tokenize a string. Return roList of strings
'******************************************************
Function strTokenize(str As String, delim As String) As Object
    st=CreateObject("roString")
    st.SetString(str)
    return st.Tokenize(delim)
End Function


'******************************************************
'Replace substrings in a string. Return new string
'******************************************************
Function strReplace(basestr As String, oldsub As String, newsub As String) As String
    newstr = ""

    i = 1
    while i <= Len(basestr)
        x = Instr(i, basestr, oldsub)
        if x = 0 then
            newstr = newstr + Mid(basestr, i)
            exit while
        endif

        if x > i then
            newstr = newstr + Mid(basestr, i, x-i)
            i = x
        endif

        newstr = newstr + newsub
        i = i + Len(oldsub)
    end while

    return newstr
End Function


