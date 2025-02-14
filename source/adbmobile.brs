' *************************************************************************
' *
' * ADOBE CONFIDENTIAL
' * ___________________
' *
' *  Copyright 2015 Adobe Systems Incorporated
' *  All Rights Reserved.
' *
' * NOTICE:  All information contained herein is, and remains
' * the property of Adobe Systems Incorporated and its suppliers,
' * if any.  The intellectual and technical concepts contained
' * herein are proprietary to Adobe Systems Incorporated and its
' * suppliers and are protected by trade secret or copyright law.
' * Dissemination of this information or reproduction of this material
' * is strictly forbidden unless prior written permission is obtained
' * from Adobe Systems Incorporated.
' *
' **************************************************************************
Library "v30/bslCore.brs"

Function ADBMobile() As Object
  if GetGlobalAA().ADBMobile = invalid
    instance = {
      version: "2.0.0",
      PRIVACY_STATUS_OPT_IN: "optedin",
      PRIVACY_STATUS_OPT_OUT: "optedout",

      ''' event loop processor
      processMessages: Function() as Void
          _adb_worker().processMessage()
          _adb_audienceManager().processMessage()
        End Function,

      processMediaMessages: Function() as Void
          ' call the ADB Mobile process message since media uses analytics
          m.processMessages()
          _adb_serializeAndSendHeartbeat().processMessage()
          _adb_clockservice_loop()
        End Function,

      ''' opt-in/opt-out
      setPrivacyStatus: Function(state as String) as Void
          _adb_logger().debug("ADBMobile Privacy Status changed to: " + state)
          _adb_persistenceLayer().writeValue("adbmobile_optout", state)
        End Function,

      getPrivacyStatus: Function() as String
          optOutState = _adb_persistenceLayer().readValue("adbmobile_optout")
          if optOutState <> invalid
            return optOutState
          end if
          return _adb_config().privacyDefault
        End Function,

      setDebugLogging: Function(flag as Boolean) as Void
          _adb_logger().debugLoggingEnabled = flag
        End Function,

      getDebugLogging: Function() as Boolean
          return _adb_logger().debugLoggingEnabled
        End Function,

      ''' analytics
      trackState: Function(state As String, ContextData as Object) as Void
          _adb_trackState(state, ContextData)
        End Function,
      trackAction: Function(action As String, ContextData as Object) as Void
          _adb_trackAction(action, ContextData)
        End Function,
      trackingIdentifier: Function() as Dynamic
          return _adb_aid()["aid"]
        End Function,
      userIdentifier: Function() as Dynamic
          return _adb_config()["userIdentifier"]
        End Function,
      setUserIdentifier: Function(id as String) as Void
          _adb_config().setUserIdentifier(id)
        End Function,

      ''' visitor id service
      visitorSyncIdentifiers: Function(identifiers as Object) As Void
        _adb_visitor().idSync(identifiers)
      End Function,
      visitorMarketingCloudID: Function() as Dynamic
        return _adb_visitor()["_mid"]
      End Function,

      ''' audience manager
      audienceSubmitSignal: Function(traits as Object) As Void
          _adb_audienceManager().submitSignal(traits)
        End Function,
      audienceVisitorProfile: Function() As Object
          return _adb_audienceManager().getVisitorProfile()
        End Function,
      audienceDpid: Function() As Dynamic
          return _adb_audienceManager().getDpid()
        End Function,
      audienceDpuuid: Function() As Dynamic
          return _adb_audienceManager().getDpuuid()
        End Function,

      audienceSetDpidAndDpuuid: Function(dpid as String, dpuuid as String) As Void
          _adb_audienceManager().setDpidAndDpuuid(dpid, dpuuid)
        End Function,

    ''' media/MediaHeartbeat

    mediaTrackLoad: Function(mediaInfo as Object, ContextData as Object) As Void
      _adb_media().trackLoad(mediaInfo, ContextData)
      End Function,

    mediaTrackStart: Function() As Void
          _adb_media().trackStart()
        End Function,

    mediaTrackUnload: Function() As Void
        _adb_media().trackUnload()
      End Function,

    mediaTrackPlay: Function() As Void
        _adb_media().trackPlaybackState()
      End Function,

    mediaTrackPause: Function() As Void
        _adb_media().trackPause()
        End Function,

    mediaTrackComplete: Function() As Void
        _adb_media().trackComplete()
      End Function,

    mediaTrackError: Function(errorId As String, errorSource As String) As Void
        _adb_media().trackError(errorId, errorSource)
      End Function,

    mediaTrackEvent: Function(event as String, data as Object, ContextData as Object) As Void
        _adb_media().trackMediaEvent(event, data, ContextData)
      End Function,

    mediaUpdatePlayhead: Function(position as Integer) As Void
        _adb_media().updatePlayhead(position)
      End Function,

    mediaUpdateQoS: Function(data as Object) As Void
        _adb_media().updateQoSData(data)
      End Function
    }

	' Include Constants
	_adb_media_loadconstants(instance)
  _adb_media_loadStandardMetadataConstants(instance)

    GetGlobalAA()["ADBMobile"] = instance
  end if

  return GetGlobalAA().ADBMobile
End Function

Function _adb_buildAndSendRequest(data, vars, timestamp)
  mutableData = {}
  mutableData.append(data)

  ''' TODO: add time since launch?

  mutableData["a.Resolution"] = _adb_deviceInfo().resolution
  mutableData["a.DeviceName"] = _adb_deviceInfo().platform
  mutableData["a.OSVersion"] = _adb_deviceInfo().operatingSystem
  mutableData["a.AppID"] = _adb_deviceInfo().appID

  ''' TODO: add privacy status?

  mutableVars = {}
  mutableVars.append(vars)

  ''' apply visitor id service variables
  mutableVars.Append(_adb_visitor().analyticsParameters())

  ''' apply aid
  aid = _adb_aid().aid
  if aid <> invalid
    mutableVars["aid"] = aid
  end if

  ''' apply vid if it exists
  if _adb_config().userIdentifier <> invalid
    mutableVars["vid"] = _adb_config().userIdentifier
  end if

  ''' apply timestamp if offline tracking is enabled
  if _adb_config().offlineTrackingEnabled = true
    mutableVars["ts"] = timestamp
  end if

  mutableVars["t"] = _adb_deviceInfo().timestring

  ''' handle var hack
  for each key in mutableData
    if type(key) <> "roString" AND type(key) <> "String"
      _adb_logger().warning("Analytics - Invalid context data key specified, skipping it")
      mutableData.Delete(key)
    else if key.left(2) = "&&" AND Len(key) > 2
      mutableVars[key.mid(2)] = mutableData[key]
      mutableData.Delete(key)
    end if
  end for

  ''' create our query string
  encoder = _adb_urlEncoder()
  queryString = "ndh=1" + encoder.serializeParameters(mutableVars) + encoder.serializeContextData(mutableData)

  ''' enqueue the hit
  _adb_worker().queue(queryString, timestamp)

  'check for callbacks
  thirdPartyMutableVars = mutableVars
  thirdPartyMutableData = mutableData
  _adb_messages().checkFor3rdPartyCallbacks(thirdPartyMutableVars,thirdPartyMutableData)

End Function

Function _adb_urlEncoder() as Object
  if GetGlobalAA()._adb_contextDataHandlerSharedInstance = invalid
    instance = {
      ''' private variables
      _urlEncoder: CreateObject("roUrlTransfer"),
      _multiplePeriodsRegex: CreateObject("roRegex", "([.]){2,}", "i"),
      _disallowedCharactersRegex: CreateObject("roRegex", "[^0-9a-zA-Z._]|^[.]{1,}|[.]{1,}$", "i"),
      ''' private Functions

      ''' adds a value to an associative array of context data
      _addValueToAA: Function(value as dynamic, cdataStructure as object, keys as object, index as integer) as Void
          numKeys = keys.Count()
          if index >= numKeys
            return
          end if

          keyName = keys[index]

          if cdataStructure[keyName] = invalid
            cdataStructure[keyName] = {}
          end if

          if numKeys - 1 = index
            cdataStructure[keyName]["v"] = value
            return
          end if

          if cdataStructure[keyName]["subValues"] = invalid
            cdataStructure[keyName]["subValues"] = {}
          end if

          m._addValueToAA(value, cdataStructure[keyName]["subValues"], keys, index+1)
        End Function,

      ''' translates context data k/v pairs into a nested structure of associative arrays
      _translateContextData: Function(dict as Object) as Object
          tempContextData = {}
          cleanedDictionary = m._cleanContextDataDictionary(dict)
          for each key in cleanedDictionary
            value = cleanedDictionary[key]
            m._addValueToAA(value, tempContextData, key.Tokenize("."), 0)
          end for
          return tempContextData
        End Function,

      ''' serializes context data encoded object into a string format suitible for url inclusion
      _serializeContextDataObject: Function(contextData as Object) as String
          returnValue = ""

          for each key in contextData
            if contextData[key]["v"] <> invalid
              returnValue = returnValue + m._serializeKeyValuePair(key, contextData[key]["v"])
            end if

            if contextData[key]["subValues"] <> invalid
              returnValue = returnValue + "&" + key + "." + m._serializeContextDataObject(contextData[key]["subValues"]) + "&." + key
            end if
          end for

          return returnValue
        End Function,

      ''' serializes a k/v pair into a url friendly format
      _serializeKeyValuePair: Function(key as dynamic, value as dynamic) as String
          valType = type(value)

          if valType = "String" OR valType="roString"
            return "&" + m._urlEncoder.Escape(key) + "=" + m._urlEncoder.Escape(value)
          else if valType = "roInteger" OR valType = "Int"
            return "&" + m._urlEncoder.Escape(key) + "=" + m._urlEncoder.Escape(value.ToStr())
          else if valType = "roFloat" OR valType = "Float" OR valType = "Double"
            return "&" + m._urlEncoder.Escape(key) + "=" + m._urlEncoder.Escape(Str(value))
          else if valType = "roBoolean" OR valType = "Boolean"
            if value
              return "&" + m._urlEncoder.Escape(key) + "=" + "true"
            end if
            return "&" + m._urlEncoder.Escape(key) + "=" + "false"
          end if

          return ""
        End Function,

      ''' serializes a value into a url friendly format
      _serializeValue: Function(value as dynamic) as String
          valType = type(value)

          if valType = "String" OR valType="roString"
            return m._urlEncoder.Escape(value)
          else if valType = "roInteger" OR valType = "Int"
            return m._urlEncoder.Escape(value.ToStr())
          else if valType = "roFloat" OR valType = "Float" OR valType = "Double"
            return m._urlEncoder.Escape(Str(value))
          else if valType = "roBoolean" OR valType = "Boolean"
            if value
              return "true"
            end if
            return "false"
          end if

          return ""
        End Function,

        ''' joins a k/v pair into k=v format
      _joinKeyValuePair: Function(key as dynamic, value as dynamic) as String
          valType = type(value)

          if valType = "String" OR valType="roString"
            return "&" + key + "=" + value
          else if valType = "roInteger" OR valType = "Int"
            return "&" + key + "=" + value.ToStr()
          else if valType = "roFloat" OR valType = "Float" OR valType = "Double"
            return "&" + key + "=" + Str(value)
          else if valType = "roBoolean" OR valType = "Boolean"
            if value
              return "&" + key + "=" + "true"
            end if
            return "&" + key + "=" + "false"
          end if

          return ""
        End Function,

      ''' cleans context data dictionary of keys to ensure they match the required format
      _cleanContextDataDictionary: Function(dict as Object) As Object
          newDict = {}

          for each key in dict
            newKey = m._disallowedCharactersRegex.ReplaceAll(m._multiplePeriodsRegex.ReplaceAll(key, "."), "")
            if Len(newKey) > 0
              val = dict[key]
              valType = type(val)
              if valType = "String" OR valType="roString"
                if Len(val) > 0
                  newDict[newKey] = dict[key]
                end if
              else
                newDict[newKey] = dict[key]
              end if
            end if
          end for

          return newDict
        End Function

      ''' public Functions

      ''' takes an associative array of context data k/v pairs and translates into a url-ready string
      serializeContextData: Function(contextData as object) as String
          return "&c." + m._serializeContextDataObject(m._translateContextData(contextData)) + "&.c"
        End Function,

      ''' serializes a dictionary of k/v pairs into a url query string
      serializeParameters: Function(dict as Object) as String
          queryParameters = ""

          for each key in dict
            if type(key) <> "roString" OR Len(key) = 0
              _adb_logger().warning("Analytics - Invalid key in array, ignoring")
            else
              queryParameters = queryParameters + m._serializeKeyValuePair(key, dict[key])
            end if
          end for

          return queryParameters
        End Function,

      ''' join a dictionary of k/v pairs into a string
      joinParameters: Function(dict as Object) as String
          joinedParameters = ""

          for each key in dict
            if type(key) <> "roString" OR Len(key) = 0
              _adb_logger().warning("Analytics - Invalid key in array, ignoring")
            else
              joinedParameters = joinedParameters + m._serializeKeyValuePair(key, dict[key])
            end if
          end for

          return joinedParameters
        End Function,

    }
    GetGlobalAA()["_adb_contextDataHandlerSharedInstance"] = instance
  end if

  return GetGlobalAA()._adb_contextDataHandlerSharedInstance
End Function

Function _adb_deviceInfo() as Object
  if GetGlobalAA()._adb_deviceInfo = invalid
    instance = {
        _init: Function() as Void
            ''' build device info
            deviceInfo = CreateObject("roDeviceInfo")
            m["resolution"] = deviceInfo.GetDisplaySize().w.ToStr() + "x" + deviceInfo.GetDisplaySize().h.ToStr()
            m["platform"] = deviceInfo.GetModel()
            m["operatingSystem"] = "Roku " + deviceInfo.GetVersion()

            ''' build app id
            appInfo = CreateObject("roAppInfo")

            title = appInfo.GetTitle()
            subTitle = appInfo.GetSubTitle()
            version = appInfo.GetVersion()

            appID = title

            if Len(subTitle) > 0
              appID = appID + "(" + subTitle + ")"
            end if

            m["appID"] = appID + " " + version
            m["defaultPageName"] = title + "/" + version

            ''' timestamp string generation
            m["timestring"] = m._timestampString(deviceInfo)
          End Function,
        _timestampString: Function(deviceInfo as Object) As String
            dstNow = False
            tzList = {}
            tzList ["US/Puerto Rico-Virgin Islands"]    = {diff: -4,    dst: False}
            tzList ["US/Guam"]                          = {diff: -10,   dst: False}
            tzList ["US/Samoa"]                         = {diff: -11,   dst: True}
            tzList ["US/Hawaii"]                        = {diff: -10,   dst: False}
            tzList ["US/Aleutian"]                      = {diff: -10,   dst: True}
            tzList ["US/Alaska"]                        = {diff: -9,    dst: True}
            tzList ["US/Pacific"]                       = {diff: -8,    dst: True}
            tzList ["US/Arizona"]                       = {diff: -7,    dst: False}
            tzList ["US/Mountain"]                      = {diff: -7,    dst: True}
            tzList ["US/Central"]                       = {diff: -6,    dst: True}
            tzList ["US/Eastern"]                       = {diff: -5,    dst: True}
            tzList ["Canada/Pacific"]                   = {diff: -8,    dst: True}
            tzList ["Canada/Mountain"]                  = {diff: -7,    dst: True}
            tzList ["Canada/Central Standard"]          = {diff: -6,    dst: False}
            tzList ["Canada/Central"]                   = {diff: -6,    dst: True}
            tzList ["Canada/Eastern"]                   = {diff: -5,    dst: True}
            tzList ["Canada/Atlantic"]                  = {diff: -4,    dst: True}
            tzList ["Canada/Newfoundland"]              = {diff: -3.5,  dst: True}
            tzList ["Europe/Iceland"]                   = {diff: 0,     dst: False}
            tzList ["Europe/Ireland"]                   = {diff: 0,     dst: True}
            tzList ["Europe/United Kingdom"]            = {diff: 0,     dst: True}
            tzList ["Europe/Portugal"]                  = {diff: 0,     dst: True}
            tzList ["Europe/Central European Time"]     = {diff: 1,     dst: True}
            tzList ["Europe/Greece/Finland"]            = {diff: 2,     dst: True}
            tzEntry = tzList[deviceInfo.GetTimeZone()]

            if tzEntry = Invalid : return "00/00/0000 00:00:00 0 0" : end if

            ' Return False if the current time zone does not ever observe DST, or if time zone was not found
            If tzEntry.dst
                ' Get the current time in GMT
                dt = CreateObject ("roDateTime")
                secsGmt = dt.AsSeconds ()

                ' Convert the current time to local time
                dt.ToLocalTime ()
                secsLoc = dt.AsSeconds ()

                ' Calculate the difference in seconds between local time and GMT
                secsDiff = secsLoc - secsGmt

                ' If the difference between local and GMT equals the difference in our table, then we're on standard time now
                dstDiff = tzEntry.diff * 60 * 60 - secsDiff
                If dstDiff < 0 Then dstDiff = -dstDiff

                dstNow = dstDiff > 1   ' Use 1 sec not zero as Newfoundland time is a floating-point value
            end if

            timeValue = tzEntry.diff

            if dstNow
              timeValue = timeValue + 1
            end if

            return "00/00/0000 00:00:00 0 " + (timeValue * -60 ).ToStr()
          End Function
    }

    instance._init()

    GetGlobalAA()["_adb_deviceInfo"] = instance
  end if

  return GetGlobalAA()._adb_deviceInfo
End Function

Function _adb_trackInternal(action as string, data as object, timeStamp as Integer) as Void
  contextData = {}
  contextData.append(data)
  contextData["a.internalaction"] = action
  rawLinkVars = {}
  rawLinkVars["pe"] = "lnk_o"
  rawLinkVars["pev2"] = "ADBINTERNAL:" + action
  rawLinkVars["pageName"] = _adb_deviceInfo()["defaultPageName"]

  _adb_buildAndSendRequest(contextData, rawLinkVars, timeStamp)
End Function

Function _adb_trackAction(action as string, data as object) as Void
  contextData = {}
  contextData.append(data)
  contextData["a.action"] = action
  rawLinkVars = {}
  rawLinkVars["pe"] = "lnk_o"
  rawLinkVars["pev2"] = "AMACTION:" + action
  rawLinkVars["pageName"] = _adb_deviceInfo()["defaultPageName"]

  _adb_buildAndSendRequest(contextData, rawLinkVars, CreateObject("roDateTime").AsSeconds())
End Function

Function _adb_trackState(state as string, data as object) as Void
  if Len(state) = 0
    state = _adb_deviceInfo()["defaultPageName"]
  end if

  rawLinkVars = {}
  rawLinkVars["pageName"] = state

  _adb_buildAndSendRequest(data, rawLinkVars, CreateObject("roDateTime").AsSeconds())
End Function

Function _adb_worker() as Object
  if GetGlobalAA()._adb_worker = invalid
    instance = {
      queue: Function(fragment as String, timestamp as Integer) as Void
              if ADBMobile().getPrivacyStatus() <> ADBMobile().PRIVACY_STATUS_OPT_OUT
                newHit = {frag: fragment, stamp: timestamp}
                _adb_logger().debug("Analytics - Queued Hit (" + fragment + ")")
                m._queue.Push(newHit)
                m._sendNextHit()
              end if
            End Function,
      processMessage: Function() As Void
              ''' process this message if it's something we need to handle
              msg = wait(1, m._port)
              if type(msg) = "roUrlEvent" AND msg.GetSourceIdentity() = m._http.GetIdentity()
                responseCode = msg.GetResponseCode()
                if responseCode = 200
                  _adb_logger().debug("Analytics - Successfully sent hit (" + m._currentHit.frag + ")")
                else
                  _adb_logger().error("Analytics - Unable to send hit (" + msg.GetFailureReason() + ")")
                end if

                m._currentHit = invalid

                m._sendNextHit()
              end if
            End Function,
      _init: Function() as Void
              ''' create reusable instance vars
              m["_http"] = CreateObject("roUrlTransfer")
              m["_port"] = CreateObject("roMessagePort")
              m["_queue"] = []
              m["_currentHit"] = invalid

              ''' configure
              m._http.SetRequest("POST")
              m._http.SetMessagePort(m._port)
              m._http.SetCertificatesFile("common:/certs/ca-bundle.crt")

            End Function,
      _sendNextHit: Function() as Void
              if _adb_config().analyticsEnabled() = false
                _adb_logger().error("Analytics - Unable to send hit (Analytics not enabled in config file)")
                return
              end if

              if m._queue.count() > 0 AND m._currentHit = invalid
                ''' grab oldest hit in the queue
                m._currentHit = m._queue.Shift()

                ''' if offline is disabled we need to throw away hits older than 60 seconds
                if _adb_config().offlineTrackingEnabled = false
                  currentTime = CreateObject("roDateTime").AsSeconds()

                  delta = currentTime - m._currentHit.stamp
                  ''' hit is old, toss it.
                  if(delta > 60)

                    ''' invalidate current hit
                    m._currentHit = invalid
                    ''' recurse
                    m._sendNextHit()
                    return
                  end if
                end if

                ''' set url
                m._http.SetUrl(m._urlStub())
                ''' send it asynchronously
                m._http.AsyncPostFromString(m._currentHit.frag)
              end if
            End Function,
        _urlStub: Function() as String
              urlBase = ""
              if _adb_config().ssl
                urlBase = "https"
              else
                urlBase = "http"
              end if

              urlBase = urlBase + "://" + _adb_config().trackingServer + "/b/ss/" + _adb_config().reportSuiteIDs + "/0/BS-" + ADBMobile().version + "/s" + Rnd(1000000).ToStr()

              return urlBase
            End Function
    }
    instance._init()

    GetGlobalAA()["_adb_worker"] = instance
  end if

  return GetGlobalAA()._adb_worker
End Function

Function _adb_audienceManager() As Object
  if GetGlobalAA()._audienceManager = invalid
      instance = {
        _sanitizeRegex: CreateObject("roRegex", "\.", "i"),
        _fixRequestRegex: CreateObject("roRegex", "\?\&", "i"),
        submitSignal: Function(data As Object) As Void
            if ADBMobile().getPrivacyStatus() <> ADBMobile().PRIVACY_STATUS_OPT_OUT
              m._queue.Push(data)
              m._sendNextSignal()
            end if
          End Function,
        ''' processes messages received on the queue
        processMessage: Function() As Void
            ''' process this message if it's something we need to handle
            msg = wait(1, m._port)
            if type(msg) = "roUrlEvent" AND msg.GetSourceIdentity() = m._http.GetIdentity()
              responseCode = msg.GetResponseCode()
              ''' success
              if responseCode = 200
                _adb_logger().debug("Audience Manager - Successfully sent signal")

                ''' parse response
                responseString = msg.GetString()
                responseObject = invalid
                if responseString <> invalid AND Len(responseString) > 0
                  responseObject = ParseJson(responseString)
                end if

                ''' if we have a response
                if responseObject <> invalid
                  ''' handle uuid
                  if responseObject.uuid <> invalid
                    m._setUUID(responseObject.uuid)
                  end if

                  ''' handle destinations
                  dests = responseObject.dests
                  if dests <> invalid
                    for each destination in dests
                      url = destination.c
                      if url <> invalid
                        _adb_logger().debug("Audience Manager - Forwarding 'dests' request (" + url + ")")
                        urlTransfer = CreateObject("roUrlTransfer")
                        urlTransfer.SetCertificatesFile("common:/certs/ca-bundle.crt")
                        urlTransfer.SetUrl(url)
                        urlTransfer.AsyncGetToString()
                      end if
                    end for
                  end if

                  ''' handle 'stuff'
                  stuff = responseObject.stuff
                  if stuff <> invalid
                    newStuff = {}
                    for each item in stuff
                      if item.cn <> invalid
                        newStuff[item.cn] = item.cv
                      end if
                    end for
                    ''' persist stuff
                    _adb_persistenceLayer().writeValue("aam_profile", FormatJson(newStuff))
                    _adb_logger().debug("Audience Manager - Updated Visitor Profile")
                  end if
                ''' handle non 200 response code
                else
                  _adb_logger().debug("Audience Manager - Empty or non JSON response received")
                end if

              else
                _adb_logger().error("Audience Manager - Unable to send signal (" + msg.GetFailureReason() + ")")
              end if

              m._currentHit = invalid
              m._sendNextSignal()
            end if
          End Function,
        ''' returns the current visitor profile as an associative array
        getVisitorProfile: Function() As Object
            visitorProfileString = _adb_persistenceLayer().readValue("aam_profile")

            if visitorProfileString <> invalid
              jsonObject = ParseJson(visitorProfileString)

              if jsonObject <> invalid
                return jsonObject
              end if
            end if

            return {}
          End Function,
        ''' sets current dpid/dpuuid
        setDpidAndDpuuid: Function(dpid as String, dpuuid as String) As Void
            m["_dpid"] = dpid
            m["_dpuuid"] = dpuuid
          End Function,
        ''' gets the currently set d_dpid
        getDpid: Function() As Dynamic
            return m._dpid
          End Function,
        ''' gets the currently set d_dpuuid
        getDpuuid: Function() As Dynamic
            return m._dpuuid
          End Function,
        _init: Function() As Void
            ''' initialize shared objects
            m["_queue"] = []
            m["_currentHit"] = invalid
            m["_http"] = CreateObject("roUrlTransfer")
            m["_port"] = CreateObject("roMessagePort")
            m["_uuid"] = m._getUUID()

            ''' configure
            m._http.SetRequest("GET")
            m._http.SetMessagePort(m._port)
            m._http.SetCertificatesFile("common:/certs/ca-bundle.crt")
          End Function,
        ''' sends the next signal waiting in the queue to AAM (async)
        _sendNextSignal: Function() As Void
            if m._queue.count() > 0 AND m._currentHit = invalid
              ''' grab oldest hit in the queue
              m["_currentHit"] = m._queue.Shift()

              ''' set url
              url = m._buildSchemaRequest(m._currentHit)
              m._http.SetUrl(url)
              _adb_logger().debug("Audience Manager - Sending signal request (" + url + ")")

              ''' send it asynchronously
              if m._http.AsyncGetToString() = false
                _adb_logger().error("Audience Manager - Unable to execute GET request to URL (" + url + ")")
              end if
            end if
          End Function,
        _setVisitorProfile: Function(segments as Object) As Void
          End Function,
        _buildSchemaRequest: Function(data as Object) As String
            urlString = m._generateURLPrefix() + m._getCustomURLVariables(data) + m._getDataProviderURLVariables() + "&d_ptfm=roku&d_dst=1&d_rtbd=json"
            return m._fixRequestRegex.ReplaceAll(urlString, "?")
          End Function,
        _generateURLPrefix: Function() As String
            urlBase = ""
            if _adb_config().ssl
              urlBase = "https"
            else
              urlBase = "http"
            end if

            urlBase = urlBase + "://" + _adb_config().aamServer + "/event?"
            return urlBase
          End Function,
        _getCustomURLVariables: Function(data as Object) As String
            response = ""
            for each key in data
              response = response + _adb_urlEncoder()._serializeKeyValuePair(m._sanitize(key), data[key])
            end for
            return response
          End Function,
        _getDataProviderURLVariables: Function() As String
            response = ""

            if m._uuid <> invalid AND Len(m._uuid) > 0
              response = response + _adb_urlEncoder()._serializeKeyValuePair("d_uuid", m._uuid)
            end if

            response = response + _adb_visitor().aamParameters()

            if m._dpuuid <> invalid AND m._dpid <> invalid
              response = response + "&d_dpid=" + m._dpid + "&d_dpuuid=" + m._dpuuid
            end if

            return response
          End Function,
        ''' sanitizes a key for aam consumption.  This is to move context dat akeys over to aam parameters
        ''' where we need to change '.' delimiters to '_'
        _sanitize: Function(key as String) As String
            return m._sanitizeRegex.ReplaceAll(key, "_")
          End Function,
        ''' sets UUID to persistent storage
        _setUUID: Function(uuid as Dynamic) As Void
            if uuid <> invalid
              _adb_persistenceLayer().writeValue("aam_uuid", uuid)
              m["_uuid"] = uuid
            end if
          End Function,
        ''' returns the UUID for the AAM user
        _getUUID: Function() As Dynamic
            return _adb_persistenceLayer().readValue("aam_uuid")
          End Function
    }

    instance._init()

    GetGlobalAA()["_audienceManager"] = instance
  end if

  return GetGlobalAA()._audienceManager
End Function

Function _adb_serializeAndSendHeartbeat() As Object
  if GetGlobalAA()._serializeAndSendHeartbeat = invalid
    instance = {
      _sanitizePublisherRegex: CreateObject("roRegex", "[^a-zA-Z0-9]+", "i"),

		  queueRequestsForResponse: Function(data As Object) As Void
          if ADBMobile().getPrivacyStatus() <> ADBMobile().PRIVACY_STATUS_OPT_OUT
			     _adb_logger().debug("MediaHeartbeat - Queued Hit")
            m._queue.Push(data)
            m._sendNextHit()
          end if
        End Function,

      reset: Function() As Void
        m.flushAsyncRequests()
        m._init()
      End Function,

      flushAsyncRequests: Function() As Void
          while true              
            if m._currentHit <> invalid
              if _adb_clockservice().isActive() = true AND _adb_clockservice().flushFilterTimerTick()
                m.timeOutActiveRequest()
                m._sendNextHit()
              else
                'this is only possible when the only call queued up going out is the error call.
                m._currentHit = invalid
              end if
            end if
        
            if m._queue.count() > 0 AND m._currentHit = invalid
              m._sendNextHit()
            end if

            ''' break the while loop when nothing is left to process in the queue
            if m._queue.count() = 0 AND m._currentHit = invalid
              exit while              
            end if
          end while
        End Function,

		  processMessage: Function() As Void
        ''' process this message if it's something we need to handle
        msg = wait(1, m._port)
        if type(msg) = "roUrlEvent" AND msg.GetSourceIdentity() = m._http.GetIdentity()
          responseCode = msg.GetResponseCode()
            if responseCode = 200
            	_adb_logger().debug("MediaHeartbeat - Successfully sent status hit")

					    ''' parse response
					    responseXML = msg.GetString()
					    setupData = invalid

              if responseXML <> invalid AND Len(responseXML) > 0
    					  setupData = CreateObject("roXMLElement")
    					  if not setupData.Parse(responseXML) then
    						  _adb_logger().debug("MediaHeartbeat - XML response could not be parsed (" + responseXML + ")")
    					  end if
              end if

              ''' if we have a response
              if setupData <> invalid
                responseConfig = {}
                _adb_logger().debug("MediaHeartbeat - XML response (" + responseXML + ")")

                if setupData.trackingInterval <> invalid
                	responseConfig.trackingInterval = setupData.trackingInterval.GetText().ToInt()
                end if
                if setupData.trackExternalErrors <> invalid
                	responseConfig.trackExternalErrors = setupData.trackExternalErrors.GetText().ToInt()
                end if
               	if setupData.setupCheckInterval <> invalid
                	responseConfig.setupCheckInterval = setupData.setupCheckInterval.GetText().ToInt()
                end if

                ''' update the check status timer settings
                _adb_clockservice().updateCheckStatusInterval(responseConfig)

                ''' handle empty or ivalid response
              else 
              	_adb_logger().debug("MediaHeartbeat - Empty or invalid XML response received")
              end if

            ''' handle non 200 response code, 204 is received for heartbeat calls
            else if responseCode = 204
              _adb_logger().debug("MediaHeartbeat - Successfully sent heartbeat hit")

            else
              _adb_logger().error("MediaHeartbeat - Unable to send hit, Failure Reason: " + msg.GetFailureReason() + " ResponseCode: " + msg.GetResponseCode().ToStr())

            end if

            m._currentHit = invalid
            m._urlRetry = false
            m._sendNextHit()
          end if
        End Function,

      timeOutActiveRequest: Function() As Void
          if m._currentHit <> invalid
            msg = wait(1, m._port)
            if msg = invalid AND m._urlRetry = false
              url = m._http.GetUrl()
              if url <> invalid 
                m._http.AsyncCancel()

                ''' retry the URL one more time
                m._sendUrlRequest(true, url)
              end if

            else if msg = invalid AND m._urlRetry = true
              _adb_logger().error("MediaHeartbeat - URL dropped after retry (" + m._http.GetUrl() + ")")
              m._http.AsyncCancel()

              m._currentHit = invalid
              m._urlRetry = false

            else if msg <> invalid
              ''' we have a response available so do nothing, ProcessMessage loop will handle this scenario
              m._currentHit = invalid
              m._urlRetry = false
            end if
          end if

           m._currentHit=invalid

        End Function,

      _sendNextHit: Function() As Void
          if m._queue.count() > 0 AND m._currentHit = invalid
            ''' grab oldest hit in the queue
            m["_currentHit"] = m._queue.Shift()

            ''' set url and send it asynchronously
            url = m._buildHeartbeatUrl(m._currentHit)         
            m._sendUrlRequest(false, url)
          end if
        End Function,

      _sendUrlRequest: Function(retryFlag as Boolean, url as String) As Void
          retry = ""
          if (retryFlag)
            retry = "Retry: "
          end if

          m._http.SetUrl(url)

          if (m._http.AsyncGetToString())
            _adb_logger().debug("MediaHeartbeat - " + retry + "Sent Media Heartbeat Hit (" + url + ")")
            if _adb_clockservice().isActive() = true
              _flushFilterTimer = _adb_clockservice().getTimer("FlushFilterTimer")
              _flushFilterTimer.reset()
            end if
            m._urlRetry = retryFlag
          else
            _adb_logger().error("MediaHeartbeat - " + retry + "Unable to execute GET request for URL (" + url + ")")

            m._http.AsyncCancel()
            m._currentHit = invalid            
          end if
        End Function,

 		 _buildHeartbeatUrl: Function(data as Object) As String
 			  checkStatus = false
 			
 			  ''' check if Hit is for check status, if yes form a different Base URL
 			  if data.r <> invalid
 				 checkStatus = true
 			  end if

        serializedParameters = _adb_urlEncoder().serializeParameters(data)
        ''' trim the extra '&' sign at the beginning of query string
        if serializedParameters.Len() > 2
          serializedParameters = serializedParameters.Mid(1)
        end if

        urlString = m._generateURLPrefix(checkStatus) + serializedParameters
        return urlString
      End Function,

      _generateURLPrefix: Function(checkStatus as Boolean) As String
          urlBase = ""
            
          ''' assuming the media SSSL mediaTrackingServer parameters for now.
		      if _adb_config().mTrackingServer <> INVALID
	          if _adb_config().mSSL
	            urlBase = "https"
	          else
	            urlBase = "http"
	          end if

	          urlBase = urlBase + "://" + _adb_config().mTrackingServer

	          if (checkStatus)
	            sanitizedPublisher = m._sanitizePublisherRegex.ReplaceAll(_adb_config().mPublisher, "-")
	          	urlBase = urlBase + "/settings/" + sanitizedPublisher + ".xml"
	          end if

	          urlBase = urlBase + "?"
		      end if
          return urlBase
        End Function,

      _init: Function() As Void
          ''' initialize shared objects
          m["_queue"] = []
          m["_currentHit"] = invalid
          m["_urlRetry"] = false
          m["_http"] = CreateObject("roUrlTransfer")          
          m["_port"] = CreateObject("roMessagePort")

          ''' configure
          m._http.SetRequest("GET")
          m._http.SetMessagePort(m._port)
          m._http.EnableFreshConnection(true)
          m._http.SetCertificatesFile("common:/certs/ca-bundle.crt")
        End Function

    }
    instance._init()

    GetGlobalAA()["_serializeAndSendHeartbeat"] = instance
  end if

  return GetGlobalAA()._serializeAndSendHeartbeat
End Function

Function _adb_clockservice() As Object
  if GetGlobalAA()._adb_clockservice = invalid
    instance = {

      updateCheckStatusInterval: Function(setupData as Object) as void
          if setupData.setupCheckInterval <> invalid 
            if type(setupData.setupCheckInterval) = "roInteger"
              _adb_logger().debug("ClockService -  updating the check status interval to: " + setupData.setupCheckInterval.ToStr())

              m._checkStatusInterval = setupData.setupCheckInterval * 1000
              m._checkStatusTimer.restartWithNewInterval(m._checkStatusInterval)
            else
              _adb_logger().debug("ClockService -  updateCheckStatusInterval: interval not an Integer")
            end if
          else
            _adb_logger().debug("ClockService -  updateCheckStatusInterval: setupCheckInterval is invalid")
          end if
        End Function,

      checkStatusTimerTick: Function() As Boolean
          return m._checkStatusTimer.ticked()
        End Function,

      reportingTimerTick: Function() As Boolean
          if m._reportingTimer.ticked()
            return true
          end if
          return false
        End Function,

      flushFilterTimerTick: Function() As Boolean
          if m._flushFilterTimer.ticked()
            return true
          end if
          return false
        End Function,                

      startClockService: Function() As Void
          m._checkStatusTimer.start(m._checkStatusInterval, "CheckStatusTimer")

          ''' Send the first check status ping as soon as timer is started
          dictionary = {
            '''r: CreateObject("roDateTime").AsSeconds()
            r: _adb_util().getTimestampInMillis()
          }
          _adb_serializeAndSendHeartbeat().queueRequestsForResponse(dictionary)

          m._reportingTimer.start(m._reportingInterval, "ReportingTimer")
          m._flushFilterTimer.start(m._flushFilterInterval, "FlushFilterTimer")
          m._active = true
        End Function,

      stopClockService: Function() As Void
          _adb_serializeAndSendHeartbeat().reset()
          if m.isActive()            
            m._checkStatusTimer.stop()
            m._reportingTimer.stop()
            m._flushFilterTimer.stop()
            m._active = false
          end if
        End Function,

      resetClockService: Function() As Void
          m._checkStatusTimer.reset()
          m._reportingTimer.reset()
          m._flushFilterTimer.reset()
        End Function,

      isActive: Function() As Boolean
          return m._active
        End Function,

      getTimer: Function(timerName as String) As Dynamic
          if timerName = "ReportingTimer"
            return m._reportingTimer
          else if timerName = "CheckStatusTimer"
            return m._checkStatusTimer
          else if timerName = "FlushFilterTimer"
            return m._flushFilterTimer
          end if
          return invalid
        End Function

      _init: Function() As Void
        ''' private internal variables
          m["_checkStatusInterval"] = 60*1000
          m["_reportingInterval"] = 10*1000
          m["_flushFilterInterval"] = 3000
          m["_active"] = false

        ''' initialize the timer objects
          m["_checkStatusTimer"] = _adb_timer()
          m["_reportingTimer"] = _adb_timer()
          m["_flushFilterTimer"] = _adb_timer()
        End Function
    }

    instance._init()

    GetGlobalAA()["_adb_clockservice"] = instance
  end if

  return GetGlobalAA()._adb_clockservice
End Function

Function _adb_clockservice_loop() As Void
    if _adb_clockservice().isActive()
      
      ''' check each timer if ticked, if yes then do something
      if _adb_clockservice().checkStatusTimerTick()
        ''' make a call for getting new config settings
        _adb_logger().debug("ClockServiceLoop - Check Status Timer Ticked")
        dictionary = {
            '''r: CreateObject("roDateTime").AsSeconds()
            r: _adb_util().getTimestampInMillis()
        }
        _adb_serializeAndSendHeartbeat().queueRequestsForResponse(dictionary)
      end if

      if _adb_clockservice().flushFilterTimerTick()
        ''' using flush filter timer to timeout unsent network requests for HB and retry
        _adb_serializeAndSendHeartbeat().timeOutActiveRequest()
      end if

      if _adb_clockservice().reportingTimerTick()
        ''' send the heartbeat/ 10sec reporting pings
        if _adb_media().isPaused()
          _adb_logger().debug("ClockServiceLoop - Reporting timer ticked but ADBMedia is in Paused state.")
        else
          _adb_logger().debug("ClockServiceLoop - Reporting Timer Ticked")
          _adb_media().trackPlaybackState()
        end if
      end if

    else
      _adb_logger().debug("ClockServiceLoop -  ClockService not initialized yet")
    end if
End Function

Function _adb_media() As Object
  if GetGlobalAA()._adb_media_instance = invalid
      instance = {
        
        _init: Function() As Void
            ''' initialize the clock service timers
            _adb_clockservice()
            m["_isEnabled"] = invalid
            m["_isPaused"] = false

            if _adb_media_isInErrorState() = false              
              m._isEnabled = true
            else 
              m._isEnabled = false
            end if
          End Function,

        enable: Function() As Void 
            m._isEnabled = true
          End Function,

        isEnabled: Function() As Boolean 
            return m._isEnabled
          End Function,

        disable: Function() As Void 
            m._isEnabled = false
          End Function,

        isPaused: Function() As Boolean 
            return m._isPaused
          End Function,

        trackStart: Function() As Void
          if _adb_media_isInErrorState() = false AND m.isEnabled()
            ' start the clockservice with the start of session
            _adb_clockservice().startClockService()

            dictionary = _adb_paramsResolver().resolveDataForEvent("media-start")
            _adb_serializeAndSendHeartbeat().queueRequestsForResponse(dictionary)
          
            contextData = _adb_paramsResolver().getContextData("start")
            _adb_trackAction("", contextData)

            dictionary_aa_start = _adb_paramsResolver().resolveDataForEvent(_adb_paramsResolver()["_aa_start"])
            _adb_serializeAndSendHeartbeat().queueRequestsForResponse(dictionary_aa_start)

            _adb_mediacontext().setActiveSession(true)
          else
            _adb_logger().debug("trackStart: ADB Media module is in error state.") 
          end if
        End Function,
		  
        trackLoad: Function(mediaInfo as Object, ContextData as Object) As Void
          if _adb_media_isInErrorState() = false
            ' check if adb_media was disabled previously, if yes, enable the same
            if m.isEnabled() = false
              m.enable()
            end if

            _adb_mediacontext().setMediaInfo(mediaInfo)

            finalData = {}
            if ContextData <> invalid
              finalData.append(ContextData)
            end if

            ' extract standard video metadata and append it to context data
            if mediaInfo <> invalid AND mediaInfo[ADBMobile().MEDIA_STANDARD_VIDEO_METADATA] <> invalid
              finalData.append(mediaInfo[ADBMobile().MEDIA_STANDARD_VIDEO_METADATA])
            end if

            _adb_mediacontext().setMediaContextData(finalData)

            if _adb_mediacontext().isActiveTracking() = true
              _adb_mediacontext().resetState()
            end if
            _adb_mediacontext().setIsActiveTracking(true)
          else
            _adb_logger().debug("trackLoad: ADB Media module is in error state.") 
          end if
        End Function,

        trackUnload: Function() As Void
           if _adb_mediacontext().isActiveTracking() = false
              _adb_logger().debug("trackUnload: No active tracking session.") 
            end if
            ' stop the reporting timer and end active sesison
            _adb_mediacontext().setIsActiveTracking(false)            
            _adb_mediacontext().setActiveSession(false)
            _adb_mediacontext().resetState()
            _adb_clockservice().stopClockService()             
          End Function,

        trackPlaybackState: Function() As Void
          if _adb_media_isInErrorState() = false AND m.isEnabled()
            if _adb_mediacontext().isActiveSession() = false
              m.trackStart()
            end if
            
            ' reset the reporting timer if adb_media was in pause state and change the state to play
            if m.isPaused()
              reportingTimer = _adb_clockservice().getTimer("ReportingTimer")
              if reportingTimer <> invalid
                reportingTimer.reset()
              end if
              m._isPaused = false

              m.resetAssetReferenceTimeStamp()
            else
              ' if not in paused state, this is regular trackplayback state
              dictionary = _adb_paramsResolver().resolveDataForEvent(_adb_mediacontext().getCurrentPlaybackState())
              _adb_serializeAndSendHeartbeat().queueRequestsForResponse(dictionary)
            end if
            
            m.resetAssetReferenceTimeStamp()
          else
            _adb_logger().debug("trackPlaybackState: ADB Media module is in error state.") 
          end if
        End Function,

        trackPause: Function() As Void
          if _adb_media_isInErrorState() = false AND m.isEnabled()
            ' track partial state of previous play/buffer before pause
            m.trackPlaybackState()
            m._isPaused = true
          else
            _adb_logger().debug("trackPause: ADB Media module is in error state.") 
          end if
        End Function,
      
        trackComplete: Function() As Void
          if _adb_media_isInErrorState() = false AND m.isEnabled()        
            dictionary = _adb_paramsResolver().resolveDataForEvent("media-complete")
            _adb_serializeAndSendHeartbeat().queueRequestsForResponse(dictionary)   
          else
            _adb_logger().debug("trackComplete: ADB Media module is in error state.") 
          end if
        End Function,
      
        trackError: Function(errorId As String, errorSource As String) As Void 
            dictionary = _adb_paramsResolver().resolveDataForEvent("error")
            dictionary["s:event:source"] = errorSource
            dictionary["s:event:id"] = errorId
            _adb_serializeAndSendHeartbeat().queueRequestsForResponse(dictionary)
          End Function,
		  
        trackMediaEvent: Function(event as String, data as Object, ContextData as Object) As Void
          if _adb_media_isInErrorState() = false AND m.isEnabled()
            if (event = ADBMobile().MEDIA_BUFFER_START)
              m.trackBufferStart()
            else if (event = ADBMobile().MEDIA_BUFFER_COMPLETE)
              m.trackBufferComplete()
            else if (event = ADBMobile().MEDIA_SEEK_START)
              m.trackSeekStart()
            else if (event = ADBMobile().MEDIA_SEEK_COMPLETE)
              m.trackSeekComplete()
            else if (event = ADBMobile().MEDIA_BITRATE_CHANGE)
              m.trackBitrateChange()
            else if (event = ADBMobile().MEDIA_CHAPTER_START)
              m.trackChapterStart(data, ContextData)
            else if (event = ADBMobile().MEDIA_CHAPTER_COMPLETE)
              m.trackChapterComplete(data)
            else if (event = ADBMobile().MEDIA_CHAPTER_SKIP)
              m.trackChapterSkip()
            else if (event = ADBMobile().MEDIA_AD_BREAK_START)
              m.trackAdBreakStart(data)
            else if (event = ADBMobile().MEDIA_AD_BREAK_COMPLETE)
              m.trackAdBreakComplete()
            else if (event = ADBMobile().MEDIA_AD_BREAK_SKIP)
              m.trackAdBreakSkip()
            else if (event = ADBMobile().MEDIA_AD_START)
              m.trackAdStart(data, ContextData)
            else if (event = ADBMobile().MEDIA_AD_COMPLETE)
              m.trackAdComplete(data)										
            else if (event = ADBMobile().MEDIA_AD_SKIP)
              m.trackAdSkip()
            end if	
          else
            _adb_logger().debug("trackMediaEvent: ADB Media module is in error state.") 
          end if		
        End Function,
		  
    		updatePlayhead: Function(postion as Integer) As Void
          if _adb_media_isInErrorState() = false AND m.isEnabled()
          	_adb_mediacontext().updateCurrentPlayhead(postion)
          else
            _adb_logger().debug("updatePlayhead: ADB Media module is in error state.") 
          end if 
    		End Function,
		  
    		updateQoSData: Function(qosInfo as Object) As Void
          if _adb_media_isInErrorState() = false AND m.isEnabled()
        		_adb_mediacontext().setQoSInfo(qosInfo)
          else
            _adb_logger().debug("updateQoSData: ADB Media module is in error state.") 
          end if 
    		End Function,		  

        trackAdBreakStart: Function(adBreakInfo as Object) As Void
            _adb_mediacontext().setAdBreakInfo(adBreakInfo)
          End Function, 

        trackAdBreakComplete: Function() As Void
            _adb_mediacontext().setAdBreakInfo(invalid)
          End Function, 

        trackAdBreakSkip: Function() As Void
            _adb_mediacontext().setAdBreakInfo(invalid)
          End Function,

        trackBufferStart: Function() As Void
            ' track partial state of previous play before buffer start
            ' reset the reporting timer if state is tracked
            reportingTimer = _adb_clockservice().getTimer("ReportingTimer")
            if reportingTimer <> invalid
              if reportingTimer.elapsedTime() > 250
                m.trackPlaybackState()
                reportingTimer.reset()
              end if
            end if

            _adb_mediacontext().setInBuffering(true)
            m.trackPlaybackState()
          End Function,

        trackBufferComplete: Function() As Void
            ' track partial untracked buffer time of before completing buffer
            ' reset the reporting timer if state is tracked
            reportingTimer = _adb_clockservice().getTimer("ReportingTimer")
            if reportingTimer <> invalid
              if reportingTimer.elapsedTime() > 250
                m.trackPlaybackState()
                reportingTimer.reset()
              end if
            end if

            _adb_mediacontext().setInBuffering(false)
            _adb_mediacontext().updateTimeStampForEvent("buffer", "-1")
            _adb_mediacontext().updateRefTSForEvent("buffer", "-1")

            m.resetAssetReferenceTimeStamp() 
          End Function,
		  
        trackSeekStart: Function() As Void
            ' set the adb media state to pause as seek starts
            m.trackPause()
          End Function,

        trackSeekComplete: Function() As Void
            ' remove the adb media from pause state and un-pause
            m.trackPlaybackState()
          End Function,

        trackChapterStart: Function(chapterInfo as Object, ContextData as Object) As Void
            ' track partial state of previous main play before chapter start
            ' reset the reporting timer if state is tracked
            reportingTimer = _adb_clockservice().getTimer("ReportingTimer")
            if reportingTimer <> invalid
              if reportingTimer.elapsedTime() > 250
                m.trackPlaybackState()
                reportingTimer.reset()
              end if
            end if

            _adb_mediacontext().setInChapterTo(true)
            _adb_mediacontext().setChapterInfo(chapterInfo)
            _adb_mediacontext().setChapterContextData(ContextData)

            dictionary = _adb_paramsResolver().resolveDataForEvent(_adb_paramsResolver()["_chapter_start"])
            _adb_serializeAndSendHeartbeat().queueRequestsForResponse(dictionary) 

            ' force play with duration 0 after chapter start
            m.trackPlaybackState()
          End Function,

        trackChapterComplete: Function(chapterInfo as Object) As Void
            ' track partial play of of chapter to be completed
            ' reset the reporting timer if state is tracked
            reportingTimer = _adb_clockservice().getTimer("ReportingTimer")
            if reportingTimer <> invalid
              if reportingTimer.elapsedTime() > 250
                m.trackPlaybackState()
                reportingTimer.reset()
              end if
            end if

            dictionary = _adb_paramsResolver().resolveDataForEvent(_adb_paramsResolver()["_chapter_complete"])
            _adb_serializeAndSendHeartbeat().queueRequestsForResponse(dictionary)      
            _adb_mediacontext().setInChapterTo(false)  

            'reset main content's reference time stamp to current timestamp.
             _adb_mediacontext().updateRefTSForEvent(_adb_mediacontext().getCurrentPlaybackState(), _adb_util().getTimestampInMillis())
          End Function,

        trackChapterSkip: Function() As Void
            _adb_mediacontext().setInChapterTo(false)
            _adb_mediacontext().setChapterInfo(invalid)
          End Function,

        trackAdStart: Function(adInfo as Object, ContextData as Object) As Void
            ' track partial state of previous main play before ad start
            ' reset the reporting timer if state is tracked
            reportingTimer = _adb_clockservice().getTimer("ReportingTimer")
            if reportingTimer <> invalid
              if reportingTimer.elapsedTime() > 250
                m.trackPlaybackState()
                reportingTimer.reset()
              end if
            end if

            _adb_mediacontext().setInAdTo(true)
            _adb_mediacontext().setAdInfo(adInfo)

            ' extract standard ad metadata and append it to context data
            finalData = {}
            if ContextData <> invalid
              finalData.append(ContextData)
            end if

            if adInfo <> invalid AND adInfo[ADBMobile().MEDIA_STANDARD_AD_METADATA] <> invalid
              finalData.append(adInfo[ADBMobile().MEDIA_STANDARD_AD_METADATA])
            end if

            _adb_mediacontext().setAdContextData(finalData)

            dictionary = _adb_paramsResolver().resolveDataForEvent("media-ad-start")
            _adb_serializeAndSendHeartbeat().queueRequestsForResponse(dictionary)

            contextData = _adb_paramsResolver().getContextData("ad-start")
            _adb_trackAction("", contextData)

            dictionary_aa_ad_start = _adb_paramsResolver().resolveDataForEvent(_adb_paramsResolver()["_aa_ad_start"])
            _adb_serializeAndSendHeartbeat().queueRequestsForResponse(dictionary_aa_ad_start)
          End Function,

        trackAdComplete: Function(adInfo as Object) As Void            
            ' track partial play of of ad to be completed
            ' reset the reporting timer if state is tracked
            reportingTimer = _adb_clockservice().getTimer("ReportingTimer")
            if reportingTimer <> invalid
              if reportingTimer.elapsedTime() > 250
                m.trackPlaybackState()
                reportingTimer.reset()
              end if
            end if

            dictionary = _adb_paramsResolver().resolveDataForEvent("media-ad-end")
            _adb_serializeAndSendHeartbeat().queueRequestsForResponse(dictionary)
            _adb_mediacontext().setInAdTo(false)  

            'reset main content's reference time stamp to current timestamp.
            _adb_mediacontext().updateRefTSForEvent(_adb_mediacontext().getCurrentPlaybackState(), _adb_util().getTimestampInMillis()) 
          End Function,

        trackAdSkip: Function() As Void
            _adb_mediacontext().setInAdTo(false)
            _adb_mediacontext().setAdInfo(invalid)
          End Function,

        trackBitrateChange: Function() As Void
            _adb_mediacontext().updateRefTSForEvent(_adb_paramsResolver()["_bitrate_change"], _adb_util().getTimestampInMillis())
            dictionary = _adb_paramsResolver().resolveDataForEvent(_adb_paramsResolver()["_bitrate_change"])
            _adb_serializeAndSendHeartbeat().queueRequestsForResponse(dictionary)             
          End Function,

        resetAssetReferenceTimeStamp: Function() As Void
          if _adb_mediacontext().isInAd() = true
            currAd = _adb_mediacontext().getAdInfo()
            currAdID = currAd["id"]
            _adb_mediacontext().updateRefTSForEvent(currAdID+"_"+_adb_mediacontext().getCurrentPlaybackState(),_adb_util().getTimestampInMillis())            
          else
            _adb_mediacontext().updateRefTSForEvent(_adb_mediacontext().getCurrentPlaybackState(), _adb_util().getTimestampInMillis())
          end if

        End Function
    }

    instance._init()

    GetGlobalAA()["_adb_media_instance"] = instance
  end if

  return GetGlobalAA()._adb_media_instance
End Function


Function adb_media_init_mediainfo(name As String, id As String, length As Double, streamType As String) As Object
    o = CreateObject("roAssociativeArray")
    o.id			= id
    o.name			= name
    o.length		= length
    o.playhead		= 0
    o.streamType	= streamType
    return o
End Function


Function adb_media_init_adinfo(name As String, id As String, position As Double, length As Double) As Object
    o = CreateObject("roAssociativeArray")
    o.id			= id
    o.name			= name
    o.length		= length
    o.position		= position
    return o
End Function


Function adb_media_init_chapterinfo(name As String, position As Double, length As Double, startTime As Double) As Object
    o = CreateObject("roAssociativeArray")
    o.name			= name
    o.length		= length
    o.position		= position
	o.offset		= startTime
    return o
End Function


Function adb_media_init_adbreakinfo(name As String, startTime as Double, position as Double) As Object
    o = CreateObject("roAssociativeArray")
    o.name        	= name
    o.startTime	  	= startTime
    o.position    	= position
    return o
End Function


Function adb_media_init_qosinfo(bitrate As Double, startupTime as Double, fps as Double, droppedFrames as Double) As Object
    o = CreateObject("roAssociativeArray")
    o.bitrate			= bitrate
    o.fps				= fps
    o.droppedFrames		= droppedFrames
    o.startupTime		= startupTime
    return o
End Function

Function _adb_media_loadconstants(instance as Object)

	instance.MEDIA_BUFFER_START			= "MediaBufferStart"
	instance.MEDIA_BUFFER_COMPLETE		= "MediaBufferComplete"
	instance.MEDIA_SEEK_START			= "MediaSeekStart"
	instance.MEDIA_SEEK_COMPLETE		= "MediaSeekComplete"
	instance.MEDIA_BITRATE_CHANGE		= "MediaBitrateChange"
	instance.MEDIA_CHAPTER_START		= "MediaChapterStart"
	instance.MEDIA_CHAPTER_COMPLETE		= "MediaChapterComplete"
	instance.MEDIA_CHAPTER_SKIP    		= "MediaChapterSkip"
	instance.MEDIA_AD_BREAK_START		= "MediaAdBreakStart"
	instance.MEDIA_AD_BREAK_COMPLETE	= "MediaAdBreakComplete"
	instance.MEDIA_AD_BREAK_SKIP   		= "MediaAdBreakSkip"
	instance.MEDIA_AD_START				= "MediaAdStart"
	instance.MEDIA_AD_COMPLETE			= "MediaAdComplete"	
	instance.MEDIA_AD_SKIP       		= "MediaAdSkip"
	instance.MEDIA_STREAM_TYPE_LIVE		= "live"
	instance.MEDIA_STREAM_TYPE_VOD		= "vod"
	instance.ERROR_SOURCE_PLAYER      	= "sourceErrorSDK"
  instance.MEDIA_STANDARD_VIDEO_METADATA = "media_standard_content_metadata"
  instance.MEDIA_STANDARD_AD_METADATA = "media_standard_ad_metadata"

End Function

Function _adb_media_loadStandardMetadataConstants(instance as Object)

  ' Standard Video metadata keys
  instance.MEDIA_VideoMetadataKeySHOW                    = "a.media.show"
  instance.MEDIA_VideoMetadataKeySEASON                  = "a.media.season"
  instance.MEDIA_VideoMetadataKeyEPISODE                 = "a.media.episode"
  instance.MEDIA_VideoMetadataKeyASSET_ID                = "a.media.asset"
  instance.MEDIA_VideoMetadataKeyGENRE                   = "a.media.genre"
  instance.MEDIA_VideoMetadataKeyFIRST_AIR_DATE          = "a.media.airDate"
  instance.MEDIA_VideoMetadataKeyFIRST_DIGITAL_DATE      = "a.media.digitalDate"
  instance.MEDIA_VideoMetadataKeyRATING                  = "a.media.rating"
  instance.MEDIA_VideoMetadataKeyORIGINATOR              = "a.media.originator"
  instance.MEDIA_VideoMetadataKeyNETWORK                 = "a.media.network"
  instance.MEDIA_VideoMetadataKeySHOW_TYPE               = "a.media.type"
  instance.MEDIA_VideoMetadataKeyAD_LOAD                 = "a.media.adLoad"
  instance.MEDIA_VideoMetadataKeyMVPD                    = "a.media.pass.mvpd"
  instance.MEDIA_VideoMetadataKeyAUTHORIZED              = "a.media.pass.auth"
  instance.MEDIA_VideoMetadataKeyDAY_PART                = "a.media.dayPart"
  instance.MEDIA_VideoMetadataKeyFEED                    = "a.media.feed"
  instance.MEDIA_VideoMetadataKeySTREAM_FORMAT           = "a.media.format"

  ' Standard Ad metadata keys
  instance.MEDIA_AdMetadataKeyADVERTISER                 = "a.media.ad.advertiser"
  instance.MEDIA_AdMetadataKeyCAMPAIGN_ID                = "a.media.ad.campaign"
  instance.MEDIA_AdMetadataKeyCREATIVE_ID                = "a.media.ad.creative"
  instance.MEDIA_AdMetadataKeyPLACEMENT_ID               = "a.media.ad.placement"
  instance.MEDIA_AdMetadataKeySITE_ID                    = "a.media.ad.site"
  instance.MEDIA_AdMetadataKeyCREATIVE_URL               = "a.media.ad.creativeURL"  
  
End Function

Function _adb_media_setErrorState(boolval As Boolean) 
  if boolval = true
    _adb_persistenceLayer().writeValue("media_error_state", "true")
    if GetGlobalAA()._adb_media_instance <> invalid
      _adb_media().disable()
      _adb_clockservice().stopClockService()      
    end if
  else if boolval = false 
    _adb_persistenceLayer().writeValue("media_error_state", "false")
    if GetGlobalAA()._adb_media_instance <> invalid
      _adb_media().enable()
      _adb_clockservice().startClockService()
    end if
  end if
End Function

Function _adb_media_isInErrorState() As Boolean
  mediaErrorState = _adb_persistenceLayer().readValue("media_error_state")

  if mediaErrorState <> invalid
    if mediaErrorState = "true"
      return true
    end if
  end if

  return false
End Function

Function _adb_mediacontext() As Object
  if GetGlobalAA()._mediaContext = invalid
      
      instance = {
        _init: Function() As Void 
          m["isInAdValue"] = false
          m["isInChapterValue"] = false
          m["isActiveTrackingValue"] = false
          m["_isSessionActive"] = false
          m.resetState()
        End Function,

        setInAdTo: Function(flag As Boolean) As Void
          m["isInAdValue"] = flag
        End Function,

        setIsActiveTracking: Function(flag as Boolean) As Void
          m["isActiveTrackingValue"] = flag
        End Function,

        setInChapterTo: Function(flag As Boolean) As Void
          m["isInChapterValue"] = flag
        End Function,

        isActiveTracking: Function() As Boolean
          return m["isActiveTrackingValue"]
        End Function,

        isBuffering: Function() As Boolean
          return m.buffering
        End Function,

        isInAd: Function() As Boolean
          return m["isInAdValue"]
        End Function,

        isInChapter: Function() As Boolean
          return m["isInChapterValue"]
        End Function, 

        isActiveSession: Function() As Boolean
          return m._isSessionActive
        End Function,

        setActiveSession: Function(value as Boolean) As Boolean
          m._isSessionActive = value
        End Function,

        setInBuffering: Function(flag as Boolean)
          m.buffering = flag
        End Function,

        eventTSMap: {},

        ''' getter methods to get the player info
        getMediaInfo: Function() As Object
          result = m["currMediaInfo"]

          if result = invalid 
            _adb_logger().warning("Media - MediaInfo object not set.")
          else if _adb_mediaPlayerDataValidator().isValidMediaInfoObject(result) = false
            _adb_logger().warning("Media - MediaInfo object is not valid")
            result = invalid
          end if

          return result
        End Function,

        getAdBreakInfo: Function() As Object
          result = m["currAdBreakInfo"]

          if result = invalid 
            _adb_logger().warning("Media - AdBreakInfo object not set.")
          else if _adb_mediaPlayerDataValidator().isValidAdBreakInfoObject(result) = false
            _adb_logger().warning("Media - AdBreakInfo object is not valid")
            result = invalid
          end if

          return result
        End Function,

        getAdInfo: Function() As Object
          result = m["currAdInfo"]

          if result = invalid 
            _adb_logger().warning("Media - AdInfo object not set.")
          else if _adb_mediaPlayerDataValidator().isValidAdInfoObject(result) = false
            _adb_logger().warning("Media - AdInfo object is not valid")
            result = invalid
          end if

          return result
        End Function,

        getChapterInfo: Function() As Object
          result = m["currChapterInfo"]

          if result = invalid 
            _adb_logger().warning("Media - ChapterInfo object not set.")
          else if _adb_mediaPlayerDataValidator().isValidChapterInfoObject(result) = false
            _adb_logger().warning("Media - ChapterInfo object is not valid")
            result = invalid
          end if

          return result
        End Function,

        getQoSInfo: Function() As Object
          result = m["currQoSInfo"]

          if result = invalid 
            _adb_logger().warning("Media - QoSInfo object not set.")
          else if _adb_mediaPlayerDataValidator().isValidQoSInfoObject(result) = false
            _adb_logger().warning("Media - QoSInfo object is not valid")
            result = invalid
          end if

          return result
        End Function,

        getMediaContextData: Function() As Object
          result = m["currMediaContextData"]

          if result = invalid 
            _adb_logger().warning("Media - Media context data is not set.")
          end if

          return result
        End Function,

        getChapterContextData: Function() As Object
          result = m["currChapterContextData"]

          if result = invalid 
            _adb_logger().warning("Media - Chapter context data is not set.")
          end if

          return result
        End Function,

        getAdContextData: Function() As Object
          result = m["currAdContextData"]

          if result = invalid 
            _adb_logger().warning("Media - Ad context data is not set.")
          end if

          return result
        End Function,

        ''' setter methods to set the player info/metadata callbacks
        setMediaInfo: Function(info As Object) As Void
          if info = invalid
             _adb_logger().warning("Media - Setting media info to invalid.")           
          end if

          m["currMediaInfo"] = info
        End Function,

        setAdBreakInfo: Function(info As Object) As Void
          if info = invalid
             _adb_logger().warning("Media - Setting ad break info to invalid.") 
          end if

          m["currAdBreakInfo"] = info
        End Function,

        setAdInfo: Function(info As Object) As Void
          if info = invalid
            _adb_logger().warning("Media - Setting ad info to invalid.") 
          end if

          m["currAdInfo"] = info
        End Function,

        setChapterInfo: Function(info As Object) As Void
          if info = invalid
            _adb_logger().warning("Media - Setting chapter info to invalid.") 
          end if

          m["currChapterInfo"] = info
        End Function,

        setQoSInfo: Function(info As Object) As Void
          if info = invalid
            _adb_logger().warning("Media - Setting qos info to invalid.") 
          end if

          m["currQoSInfo"] = info
        End Function,

        setMediaContextData: Function(contextData As Object) As Void
          if contextData = invalid
            _adb_logger().warning("Media - Setting media context data to invalid.") 
          end if

          m["currMediaContextData"] = contextData
        End Function,

        setAdContextData: Function(contextData As Object) As Void
          if contextData = invalid
            _adb_logger().warning("Media - Setting ad context to invalid.") 
          end if

          m["currAdContextData"] = contextData
        End Function,

        setChapterContextData: Function(contextData As Object) As Void
          if contextData = invalid
            _adb_logger().warning("Media - Setting chapter context info to invalid.")
          end if

          m["currChapterContextData"] = contextData
        End Function,

        resetState: Function() as Void
          m.setInAdTo(false)
          m.setInChapterTo(false)
          m["isActiveTrackingValue"] = false
          m["eventTSMap"] = {}
          m["refTSMap"] = {}
          m["playhead"] = 0
          m["buffering"] = false
        End Function,

        updateTimeStampForEvent: Function(eventName As String, ts As String) As Void
          m.eventTSMap[eventName] = ts
        End Function,

        updateRefTSForEvent: Function(eventName As String, ts As String) As Void
          m.refTSMap[eventName] = ts
        End Function,

        updateCurrentPlayhead: Function(playhead As Integer) As Void
          m["playhead"] = playhead
        End Function,

        getCurrentPlayhead: Function() As Integer
          return m["playhead"]
        End Function,

        getCurrentPlaybackState: Function() As Object
          if m.buffering = true
            return "buffer"
          end if
            return "play"
        End Function,

        getTimeStampForEvent: Function(eventName As String) As Object
          if m.eventTSMap[eventName] = invalid
            m.eventTSMap[eventName] = "-1"
          end if

          return m.eventTSMap[eventName]
        End Function,

        getRefTSForEvent: Function(eventName As String) As Object
          if m.refTSMap[eventName] = invalid
            'don't save it to always return -1 so that we can always check for it and make it = prevTS
            return "-1"
          end if

          return m.refTSMap[eventName]
        End Function
      }

      instance._init()

      GetGlobalAA()["_mediaContext"] = instance
  end if

  return GetGlobalAA()._mediaContext
End Function

Function _adb_paramsResolver() As Object
  if GetGlobalAA()._paramsResolver = invalid      
      instance = {

        resolveDataForEvent: Function(eventName As String) As Object

          resolvedData = {}

          ''' common data 
          '''analytics specific (s:sc:)
          m._appendAnalyticsData(resolvedData)

          m._appendUserData(resolvedData)

          '''service provider config specific - (s:sp:)
          m._appendServiceData(resolvedData)

          '''asset specific - reset here always - (l:asset:)
          m._appendCommonAssetData(resolvedData)

          '''common stream specific - update (l:stream:)
          m._appendCommonStreamData(resolvedData)

          '''session (s:event:sid)
          resolvedData[m._event_sid] = m._mediaSessionId()

          ''' event specific data.
          if eventName = m["_aa_start"]
            m._appendEventData(resolvedData, eventName)
            m._appendCUserData(resolvedData)

          else if eventName = m["_aa_ad_start"]
            m._appendEventData(resolvedData, eventName)

          else if eventName="media-start" 
            m._appendEventData(resolvedData, "start")
            m._appendMetadata(resolvedData)

          else if eventName="media-buffer-start" 
            m._appendEventData(resolvedData, "buffer")
            m._appendMetadata(resolvedData)

          else if eventName="media-ad-start" 
            'reset the ad_sid to invalid before every AdStart, fix for VHL-652
            m["_adSessionIdValue"] = invalid
            m._appendEventData(resolvedData, "start")
            m._appendMetadata(resolvedData)
            
            'save time stamp for ad play so that first ad play has event duration != 0
            currAd = _adb_mediacontext().getAdInfo()
            currAdID = currAd["id"]
            _adb_mediacontext().updateRefTSForEvent(currAdID+"_"+_adb_mediacontext().getCurrentPlaybackState(),_adb_util().getTimestampInMillis())
          
          else if eventName="media-ad-end" 
            m._appendEventData(resolvedData, "complete")
            'm._appendAdAssetData(resolvedData)            

          else if eventName = m["_chapter_start"]
            m["_chapterSessionIdValue"] = invalid
            'update the reference time stamp with every chapter-start event. This makes event duration = 0 with a prev_ts
            _adb_mediacontext().updateRefTSForEvent(eventName,_adb_util().getTimestampInMillis())
            m._appendEventData(resolvedData,eventName)
            m._appendMetadata(resolvedData)

          else if eventName = m["_chapter_complete"]
            _adb_mediacontext().updateRefTSForEvent(eventName,_adb_util().getTimestampInMillis())
            m._appendEventData(resolvedData,eventName)
            'm._appendChapterStreamData(resolvedData)

          else if eventName="media-complete" 
            m._appendEventData(resolvedData, "complete")
            m["_mediaSessionIdValue"] = invalid

          else
            'append the eventName anyway
            m._appendEventData(resolvedData, eventName)
          end if  

          if _adb_mediacontext().isInAd() = true
            m._appendAdAssetData(resolvedData)
            
            '''currAd = _adb_mediacontext().getAdInfo
            currAd = _adb_mediacontext().getAdInfo()
            currAdID = currAd["id"]
            m._appendEventTS(resolvedData, currAdID+"_"+eventName)
          else
            m._appendEventTS(resolvedData, eventName)
          end if

          if _adb_mediacontext().isInChapter() = true
            m._appendChapterStreamData(resolvedData)
          end if

          return resolvedData      
        End Function,

        getContextData: Function(eventName as String) As Object
          contextData = {}

          if eventName = "start"            
            mediaMetadata = _adb_mediacontext().getMediaContextData()
            if mediaMetadata <> invalid
              contextData.append(mediaMetadata)
            end if

            mediaInfo = _adb_mediacontext().getMediaInfo()
            contextData["a.contentType"] = mediaInfo.streamType
            contextData["a.media.name"] = mediaInfo.id
            contextData["a.media.friendlyName"] = mediaInfo.name
            contextData["a.media.length"] = mediaInfo.length
            contextData["a.media.playerName"] = _adb_config().mPlayerName
            contextData["a.media.channel"] = _adb_config().mChannel
            contextData["a.media.view"] = "true"
            contextData["a.media.vsid"] = m._mediaSessionId()
            contextData["&&pev3"] = "video"
            contextData["&&pe"] = "ms_s"

            ' appending customer ids to support AAM's declared id
            if _adb_audienceManager().getDpid() <> invalid
              contextData["&&cid.userId.id"] = _adb_audienceManager().getDpid()
            end if
            if _adb_audienceManager().getDpuuid() <> invalid
              contextData["&&cid.puuid.id"] = _adb_audienceManager().getDpuuid()
            end if

          else if eventName = "ad-start"            
            mediaMetadata = _adb_mediacontext().getMediaContextData()
            adMetadata = _adb_mediacontext().getAdContextData()
            if mediaMetadata <> invalid
              contextData.append(mediaMetadata)
            end if
            if adMetadata <> invalid
              contextData.append(adMetadata)
            end if

            mediaInfo = _adb_mediacontext().getMediaInfo()
            adInfo = _adb_mediacontext().getAdInfo()
            adBreakInfo = _adb_mediacontext().getAdBreakInfo()
            assetIdMD5 = _adb_util().generateMD5(mediaInfo.id)
            podId = assetIdMD5 + "_" + Str(adBreakInfo.position).Trim()

            contextData["a.contentType"] = mediaInfo.streamType
            contextData["a.media.name"] = mediaInfo.id
            contextData["a.media.playerName"] = _adb_config().mPlayerName
            contextData["a.media.channel"] = _adb_config().mChannel
            contextData["a.media.vsid"] = m._mediaSessionId()
            contextData["a.media.friendlyName"] = mediaInfo.name
            contextData["a.media.length"] = mediaInfo.length
            
            contextData["a.media.ad.name"] = adInfo.id
            contextData["a.media.ad.friendlyName"] = adInfo.name
            contextData["a.media.ad.podFriendlyName"] = adBreakInfo.name
            contextData["a.media.ad.length"] = adInfo.length
            contextData["a.media.ad.playerName"] = _adb_config().mPlayerName
            contextData["a.media.ad.pod"] = podId
            contextData["a.media.ad.podPosition"] = adInfo.position
            contextData["a.media.ad.podSecond"] = adBreakInfo.startTime
            contextData["a.media.ad.view"] = "true"
            contextData["&&pev3"] = "videoAd"
            contextData["&&pe"] = "msa_s"

            ' appending customer ids to support AAM's declared id
            if _adb_audienceManager().getDpid() <> invalid
              contextData["&&cid.userId.id"] = _adb_audienceManager().getDpid()
            end if
            if _adb_audienceManager().getDpuuid() <> invalid
              contextData["&&cid.puuid.id"] = _adb_audienceManager().getDpuuid()
            end if
          end if

          return contextData
        End Function,

        _appendCUserData: Function(resolvedData As Object) As Void
          if _adb_audienceManager().getDpid() <> invalid
            resolvedData[m._cuser_id] = _adb_audienceManager().getDpid()
          end if
          if _adb_audienceManager().getDpuuid() <> invalid
            resolvedData[m._cuser_puuid] = _adb_audienceManager().getDpuuid()
          end if
        End Function,

        _appendAnalyticsData: Function(resolvedData As Object) As Void
          resolvedData[m._analytics_rsid] = _adb_config().reportSuiteIDs
          resolvedData[m._analytics_trackingserver] = _adb_config().trackingServer

          if _adb_config().ssl = true or _adb_config().ssl = 1
            resolvedData[m._analytics_ssl] = 1
          else 
            resolvedData[m._analytics_ssl] = 0
          end if
        End Function,

        _appendUserData: Function(resolvedData As Object) As Void
          resolvedData[m._user_aid] = _adb_aid().aid
          resolvedData[m._user_mid] = _adb_visitor().marketingCloudID()
          resolvedData[m._user_vid] = _adb_config().userIdentifier
        End Function,

        _appendServiceData: Function(resolvedData As Object) As Void
          resolvedData[m._service_sdk] = _adb_config().mSdk
          resolvedData[m._service_apilevel] = _adb_media_version().getApiLevel()
          resolvedData[m._service_channel] =  _adb_config().mChannel
          resolvedData[m._service_ovp] = _adb_config().ovp
          resolvedData[m._service_playername] = _adb_config().mPlayerName
          resolvedData[m._service_hbversion] =  ADBMobile().version
        End Function,

        _appendCommonStreamData: Function(resolvedData As Object) As Void

          mediaInfo = _adb_mediacontext().getMediaInfo()
          if mediaInfo <> invalid
            resolvedData[m._stream_type] = mediaInfo["streamType"]
          end if
          
          qosInfo = _adb_mediacontext().getQoSInfo()
          if qosInfo <> invalid
             resolvedData[m._stream_droppedFrames] = qosInfo.droppedFrames
             resolvedData[m._stream_startup_time] = qosInfo.startupTime
             resolvedData[m._stream_fps] = qosInfo.fps
             resolvedData[m._stream_bitrate] = qosInfo.bitrate
          end if
        End Function,

        _appendCommonAssetData: Function(resolvedData As Object) As Void
          mediaInfo = _adb_mediacontext().getMediaInfo()
          resolvedData[m._asset_type] = "main"
          if mediaInfo <> invalid
            resolvedData[m._asset_mediaid] = mediaInfo.id
            resolvedData[m._asset_duration] = mediaInfo.length
            resolvedData[m._asset_name] = mediaInfo.name
          end if

          resolvedData[m._asset_publisher] = _adb_config().mPublisher
        End Function,

        _appendEventData: Function(resolvedData As Object, eventName as String) As Void
          
          currPlayhead = _adb_mediacontext().getCurrentPlayhead()
          if currPlayhead <> invalid
            resolvedData[m._event_playhead] = currPlayhead
          end if
          
          resolvedData[m._event_type] = eventName
        End Function,

        _appendEventTS: Function(resolvedData As Object, eventName as String) As Void   
          currTS = _adb_util().getTimestampInMillis()
          prevTS = _adb_mediacontext().getTimeStampForEvent(eventName)
          refTS = _adb_mediacontext().getRefTSForEvent(eventName)

          'for some events, event duration = 0 even if prev_ts != -1. In these cases, reference ts = current ts.
          if refTS = "-1"
            refTS = prevTS
          end if

          resolvedData[m._event_prevts] = prevTS
          resolvedData[m._event_ts] = currTS

          if refTS = "-1"
            resolvedData[m._event_duration] = 0
          else
            resolvedData[m._event_duration] = _adb_util().calculateTimeDiffInMillis(currTS, refTS)
          end if

          _adb_mediacontext().updateTimeStampForEvent(eventName, currTS)
        End Function

        _appendAdAssetData: Function(resolvedData As Object) As Void
          resolvedData[m._asset_type] = "ad"

          adBreakInfo = _adb_mediacontext().getAdBreakInfo()
          if adBreakInfo <> invalid
            resolvedData[m._asset_resolver] = _adb_config().mPlayerName

            resolvedData[m._asset_podposition] = adBreakInfo.position
            resolvedData[m._asset_podname] = adBreakInfo.name
            resolvedData[m._asset_podoffset] = adBreakInfo.startTime
      
            assetIdMD5 = _adb_util().generateMD5(resolvedData[m._asset_mediaid])
            resolvedData[m._asset_podid] = assetIdMD5 + "_" + Str(resolvedData[m._asset_podposition]).Trim()
          end if

          adInfo = _adb_mediacontext().getAdInfo()
          if adInfo <> invalid 
            resolvedData[m._asset_adid] = adInfo.id
            resolvedData[m._asset_adname] = adInfo.name
            resolvedData[m._asset_adlength] = adInfo.length
          end if

          resolvedData[m._asset_adsid] = m._adSessionId()
        End Function,

        _appendChapterStreamData: Function(resolvedData As Object) As Void
          
          resolvedData[m._stream_chaptersid] =  m._chapterSessionId()

          chapterInfo = _adb_mediacontext().getChapterInfo()
          if chapterInfo <> invalid
            resolvedData[m._stream_chapterpos] = chapterInfo.position
            ''' TODO: resolvedData[m._stream_chaptersid] = MD5 hash of media-id and chapterInfo["position"]
            mediaIdMD5 = _adb_util().generateMD5(resolvedData[m._asset_mediaid])
            resolvedData[m._stream_chapterid] = mediaIdMD5 + "_" + Str(resolvedData[m._stream_chapterpos]).Trim()
            resolvedData[m._stream_chaptername] = chapterInfo.name
            resolvedData[m._stream_chapteroffset] = chapterInfo.offset
            resolvedData[m._stream_chapterlength] = chapterInfo.length
          end if
        End Function,

        _appendMetadata: Function(resolvedData As Object) As Void
            m._appendMediaMetadata(resolvedData)

            if _adb_mediacontext().isInAd() = true
              m._appendAdMetadata(resolvedData)
            end if

            if _adb_mediacontext().isInChapter() = true
              m._appendChapterMetadata(resolvedData)
            end if
        End Function,

        _appendMediaMetadata: Function(resolvedData As Object) As Void
          mediaMetadata = _adb_mediacontext().getMediaContextData()
            if mediaMetadata <> invalid
              for each key in mediaMetadata
                  paramKey = m["metaKey"] + key
                  resolvedData[paramKey] = mediaMetadata[key]
              end for
            end if
        End Function,

        _appendAdMetadata: Function(resolvedData As Object) As Void
          adMetadata = _adb_mediacontext().getAdContextData()
            if adMetadata <> invalid
              for each key in adMetadata
                  paramKey = m["metaKey"] + key
                  resolvedData[paramKey] = adMetadata[key]
              end for
            end if        
        End Function,

        _appendChapterMetadata: Function(resolvedData As Object) As Void
          chapterMetadata = _adb_mediacontext().getChapterContextData()
            if chapterMetadata <> invalid
              for each key in chapterMetadata
                  paramKey = m["metaKey"] + key
                  resolvedData[paramKey] = chapterMetadata[key]
              end for
            end if  
        End Function,

        _mediaSessionId: Function() As Object
          if m["_mediaSessionIdValue"] = invalid 
            m["_mediaSessionIdValue"] = _adb_util().generateSessionId()
          end if

          return m["_mediaSessionIdValue"]
        End Function,

        _chapterSessionId: Function() As Object
          if m["_chapterSessionIdValue"] = invalid 
            m["_chapterSessionIdValue"] = _adb_util().generateSessionId()
          end if

          return m["_chapterSessionIdValue"]
        End Function,

        _adSessionId: Function() As Object
          if m["_adSessionIdValue"] = invalid 
            m["_adSessionIdValue"] = _adb_util().generateSessionId()
          end if

          return m["_adSessionIdValue"]
        End Function,

        _init:Function() As Void
          m["_analytics_rsid"] = "s:sc:rsid"
          m["_analytics_trackingserver"] = "s:sc:tracking_server"
          m["_analytics_ssl"] = "h:sc:ssl"

          m["_user_aid"] = "s:user:aid"
          m["_user_mid"] = "s:user:mid"
          m["_user_vid"] = "s:user:id"

          m["_cuser_id"] = "s:cuser:userId.id"
          m["_cuser_puuid"] = "s:cuser:puuid.id"

          m["_service_sdk"] = "s:sp:sdk"
          m["_service_apilevel"] = "l:sp:hb_api_lvl"
          m["_service_channel"] = "s:sp:channel"
          m["_service_ovp"] = "s:sp:ovp"
          m["_service_playername"] = "s:sp:player_name"
          m["_service_hbversion"] = "s:sp:hb_version"

          m["_asset_type"] = "s:asset:type"
          m["_asset_publisher"] = "s:asset:publisher"
          m["_asset_mediaid"] = "s:asset:video_id"
          m["_asset_duration"] = "s:asset:duration"
          m["_asset_name"] = "s:asset:name"

          m["_stream_type"] = "s:stream:type"
          m["_stream_droppedFrames"] = "l:stream:dropped_frames"
          m["_stream_startup_time"] = "l:stream:startup_time"
          m["_stream_fps"] = "l:stream:fps"
          m["_stream_bitrate"] = "l:stream:bitrate"

          '''chapter sepecific stream info
          m["_stream_chaptersid"] = "s:stream:chapter_sid"
          m["_stream_chapterid"] = "s:stream:chapter_id"
          m["_stream_chaptername"] = "s:stream:chapter_name"
          m["_stream_chapteroffset"] = "l:stream:chapter_offset"
          m["_stream_chapterpos"] = "l:stream:chapter_pos"
          m["_stream_chapterlength"] = "l:stream:chapter_length"

          m["_asset_type"] = "s:asset:type"
          m["_asset_publisher"] = "s:asset:publisher"
          m["_asset_duration"] = "l:asset:length"

          '''ToDo : Keep the key on backend as video / media?
          m["_asset_mediaid"] = "s:asset:video_id"

          '''ad sepecific asset info
          m["_asset_resolver"] = "s:asset:resolver"
          m["_asset_adid"] = "s:asset:ad_id"
          m["_asset_adsid"] = "s:asset:ad_sid"
          m["_asset_podid"] = "s:asset:pod_id"
          m["_asset_podposition"] = "s:asset:pod_position"
          m["_asset_type"] = "s:asset:type"
          m["_asset_adname"] = "s:asset:ad_name"
          m["_asset_adlength"] = "l:asset:ad_length"
          m["_asset_podname"] = "s:asset:pod_name"
          m["_asset_podoffset"] = "l:asset:pod_offset"
          

          m["_event_sid"] = "s:event:sid"
          m["_event_ts"] = "l:event:ts"
          m["_event_prevts"] = "l:event:prev_ts"
          m["_event_type"] = "s:event:type"
          m["_event_duration"] = "l:event:duration"
          m["_event_playhead"] = "l:event:playhead"

          m["_mediaSessionIdValue"] = invalid
          m["_chapterSessionIdValue"] = invalid
          m["_adSessionIdValue"] = invalid
          m["metaKey"] = "s:meta:"

          m["_aa_start"] = "aa_start"
          m["_aa_ad_start"] = "aa_ad_start"
          m["_bitrate_change"] = "bitrate_change"
          m["_chapter_start"] = "chapter_start"
          m["_chapter_complete"] = "chapter_complete"


        End Function
      }

      instance._init()

      GetGlobalAA()["_paramsResolver"] = instance
  end if

  return GetGlobalAA()._paramsResolver
End Function

Function _adb_playerData() As Object
  if GetGlobalAA()._playerData = invalid
      instance = {
        
        _init: Function() As Void
          m["_mediaInfoCallback"] = invalid
          m["_adInfoCallback"] = invalid
          m["_adBreakInfoCallback"] = invalid
          m["_chapterInfoCallback"] = invalid
          m["_qosInfoCallback"] = invalid
          m["_chapterCustomMetadataCallback"] = invalid
          m["_adCustomMetadataCallback"] = invalid
          m["_mediaCustomMetadataCallback"] = invalid
        End Function,

        ''' getter methods to get the player info
        getMediaInfo: Function() As Object
          result = invalid

          if m._mediaInfoCallback <> invalid 
            result = m._mediaInfoCallback()
            if _adb_mediaPlayerDataValidator().isValidMediaInfoObject(result) = false
              _adb_logger().warning("Media - MediaInfo object is not valid")
              result = invalid
            end if
          else
            _adb_logger().warning("Media - MediaInfo callback method is invalid")
          end if

          return result
        End Function,

        getAdBreakInfo: Function() As Object
          result = invalid
          if m._adBreakInfoCallback <> invalid 
            result = m._adBreakInfoCallback()
            if _adb_mediaPlayerDataValidator().isValidAdBreakInfoObject(result) = false
              _adb_logger().warning("Media - AdBreak Info object is not valid")
              result = invalid
            end if
          else
            _adb_logger().warning("Media - AdBreak Info callback method is invalid")
          end if

          return result
        End Function

        getAdInfo: Function() As Object
          result = invalid
          
          if m._adInfoCallback <> invalid 
            result = m._adInfoCallback()
            if _adb_mediaPlayerDataValidator().isValidAdInfoObject(result) = false
              _adb_logger().warning("Media - Ad Info object is not valid")
              result = invalid
            end if
          else
            _adb_logger().warning("Media - Ad Info callback method is invalid")
          end if
          
          return result
        End Function

        getChapterInfo: Function() As Object
          result = invalid
          
          if m._chapterInfoCallback <> invalid 
            result = m._chapterInfoCallback()
            
            if _adb_mediaPlayerDataValidator().isValidChapterInfoObject(result) = false
              _adb_logger().warning("Media - Chapter Info object is not valid")
              result = invalid
            end if
          else
            _adb_logger().warning("Media - Chapter Info callback method is invalid")
          end if
          
          return result
        End Function

        getQoSInfo: Function() As Object
          result = invalid
          
          if m._qosInfoCallback <> invalid 
            result = m._qosInfoCallback()
            
            if _adb_mediaPlayerDataValidator().isValidQoSInfoObject(result) = false
              _adb_logger().warning("Media - QoS Info object is not valid")
              result = invalid
            end if
          else
            _adb_logger().warning("Media - QoS Info callback method is invalid")
          end if
          
          return result
        End Function

        getMediaMetadata: Function() As Object
          if m._mediaCustomMetadataCallback = invalid
            _adb_logger().warning("Media - MediaMetadata callback not set")
            return invalid
          end if

          return m._mediaCustomMetadataCallback()
        End Function,

        getChapterMetadata: Function() As Object
          if m._chapterCustomMetadataCallback = invalid
            _adb_logger().warning("Media - MediaMetadata callback not set")
            return invalid
          end if

          return m._chapterCustomMetadataCallback()
        End Function

        getAdMetadata: Function() As Object
          if m._adCustomMetadataCallback = invalid
            _adb_logger().warning("Media - MediaMetadata callback not set")
            return invalid
          end if

          return m._adCustomMetadataCallback()
        End Function

        ''' setter methods to set the player info/metadata callbacks
        setMediaInfoCallback: Function(callback As Function) As Void
          if callback <> invalid
            m["_mediaInfoCallback"] = callback
          end if
        End Function,

        setAdBreakInfoCallback: Function(callback As Function) As Void
          if callback <> invalid
            m["_adBreakInfoCallback"] = callback
          end if
        End Function,

        setAdInfoCallback: Function(callback As Function) As Void
          if callback <> invalid
            m["_adInfoCallback"] = callback
          end if
        End Function,

        setChapterInfoCallback: Function(callback As Function) As Void
          if callback <> invalid
            m["_chapterInfoCallback"] = callback
          end if
        End Function,

        setQoSInfoCallback: Function(callback As Function) As Void
          if callback <> invalid
            m["_qosInfoCallback"] = callback
          end if
        End Function,

        setMediaMetadaCallback: Function(callback As Function) As Void
          if callback <> invalid
            m["_mediaCustomMetadataCallback"] = callback
          end if
        End Function,

        setAdMetadaCallback: Function(callback As Function) As Void
          if callback <> invalid
            m["_adCustomMetadataCallback"] = callback
          end if
        End Function,

        setChapterMetadaCallback: Function(callback As Function) As Void
          if callback <> invalid
            m["_chapterCustomMetadataCallback"] = callback
          end if
        End Function
    }

    instance._init()

    GetGlobalAA()["_playerData"] = instance
  end if

  return GetGlobalAA()._playerData
End Function

Function _adb_mediaPlayerDataValidator() As Object
  if GetGlobalAA()._mediaPlayerDataValidator = invalid
      
      instance = {

        isValidMediaInfoObject:Function(mediaInfo As Object) As Boolean
          if mediaInfo.id = invalid
            _adb_logger().warning("Media - MediaInfo does not have a value for media-id")
            return false
          end if

          if mediaInfo.playhead = invalid
            _adb_logger().warning("Media - MediaInfo does not have a value for playhead")
            return false
          end if

          if mediaInfo.length = invalid
            _adb_logger().warning("Media - MediaInfo does not have a value for the length of the content")
            return false
          end if

          return true
        End Function,

        isValidAdBreakInfoObject:Function(adBreakInfo As Object) As Boolean
          if adBreakInfo["position"] = invalid
            _adb_logger().warning("Media - AdBreak Info does not have value for position")
            return false
          end if
          
          return true
        End Function,

        isValidAdInfoObject:Function(adInfo As Object) As Boolean
          if adInfo["id"] = invalid
            _adb_logger().warning("Media - Ad Info does not have value for ad id")
            return false
          end if
          
          return true
        End Function,

        isValidChapterInfoObject:Function(chapterInfo As Object) As Boolean
          if chapterInfo["position"] = invalid
            _adb_logger().warning("Media - Chapter Info does not have value for chapter position")
            return false
          end if

          if chapterInfo["name"] = invalid
            _adb_logger().warning("Media - Chapter Info does not have value for chapter name")
            return false
          end if

          if chapterInfo["offset"] = invalid
            _adb_logger().warning("Media - Chapter Info does not have value for chapter offset")
            return false
          end if

          if chapterInfo["length"] = invalid
            _adb_logger().warning("Media - Chapter Info does not have value for chapter length")
            return false
          end if

          return true
        End Function,

        isValidQoSInfoObject:Function(qosInfo As Object) As Boolean
          if qosInfo["droppedFrames"] = invalid
            _adb_logger().warning("Media - QoS Info does not have value for dropped frames")
            return false
          end if

          if qosInfo["startupTime"] = invalid
            _adb_logger().warning("Media - QoS Info does not have value for startup time")
            return false
          end if

          if qosInfo["fps"] = invalid
            _adb_logger().warning("Media - QoS Info does not have value for frames per second")
            return false
          end if

          if qosInfo["bitrate"] = invalid
            _adb_logger().warning("Media - QoS Info does not have value for bitrate")
            return false
          end if

          return true
        End Function
    }
    
    GetGlobalAA()["_mediaPlayerDataValidator"] = instance
  end if

  return GetGlobalAA()._mediaPlayerDataValidator
End Function

Function ADBVideoPlayer()
    this = m.handler_Instance
    if this = INVALID
        this = {
        'member variables
            playerId   		: INVALID
            hbInitialized 	: false         

        'Functions
            handleMessage   : _adb_player_HandleMessage
			setContent		: _adb_player_SetContent
        }
        
        ' singleton
        m.handler_Instance = this
    end if
    
    return this
    
End Function

Function _adb_player_SetContent(content as Object, ContextData as Object) as Boolean

	mInfo = adb_media_init_mediainfo(content.title, content.contentid, 0, ADBMobile().MEDIA_STREAM_TYPE_VOD)
	
	if content.length <> invalid
		mInfo.length = content.length
	end if
	
	if (content.live <> invalid and content.live = true)
		mInfo.streamType = ADBMobile().MEDIA_STREAM_TYPE_LIVE
	end if
	
	if content[ADBMobile().MEDIA_STANDARD_VIDEO_METADATA] <> invalid
	  mInfo[ADBMobile().MEDIA_STANDARD_VIDEO_METADATA] = content[ADBMobile().MEDIA_STANDARD_VIDEO_METADATA]
	end if

	m["contentInfo"] = mInfo
	m["contextData"] = ContextData
		
End Function

Function _adb_player_HandleMessage(msg as Object) as Boolean

    if type(msg) = "roVideoScreenEvent" OR type(msg) = "roVideoPlayerEvent" then
		_adb_logger().debug("[ADBVideoPlayer] _adb_player_HandleMessage: msg = " + msg.GetMessage())

		if msg.isStreamStarted()
		
			_adb_logger().debug("[ADBVideoPlayer] isStreamStarted: " + " msg: " + msg.GetMessage())
			
			' isStreamStarted after HB initialization is a return event from pause/seek event, hence trackPlay to resume HB tracking.
			if (m.hbInitialized = true)
				ADBMobile().mediaTrackPlay()
			end if

		else if msg.isFullResult()
		
			_adb_logger().debug("[ADBVideoPlayer] is Full Result: " + " msg: " + msg.GetMessage())
			
			ADBMobile().mediaTrackComplete()
		
		else if msg.isPartialResult()
		
			_adb_logger().debug("[ADBVideoPlayer] is Partial Result: " + " msg: " + msg.GetMessage())
		
		else if msg.isPaused()
		
			_adb_logger().debug("[ADBVideoPlayer] is Paused: " + " msg: " + msg.GetMessage())
			ADBMobile().mediaTrackPause()

		else if msg.isResumed()
		
			_adb_logger().debug("[ADBVideoPlayer] is Resumed: " + " msg: " + msg.GetMessage())
			ADBMobile().mediaTrackPlay()
		
        else if msg.isRequestFailed()
        
		    _adb_logger().debug("[ADBVideoPlayer] Video request failure: " + msg.GetIndex().ToStr() + " msg: " + msg.GetMessage())
			ADBMobile().mediaTrackError(msg.GetMessage(), ADBMobile().ERROR_SOURCE_PLAYER)
        
		else if msg.isStatusMessage()
        
		    _adb_logger().debug("[ADBVideoPlayer] Video status: " + " msg: " + msg.GetMessage())
			 
        else if msg.isPlaybackPosition() then
        	playhead = msg.GetIndex()

        	' if hb is not initialized and playhead is 0 that means first frame display and hence call trackStart
        	if (m.hbInitialized = false)
	        	ADBMobile().mediaTrackLoad(m.contentInfo, m.contextData)
				ADBMobile().mediaTrackStart()
				ADBMobile().mediaTrackPlay()
				m.hbInitialized = true
        	end if

			_adb_logger().debug("[ADBVideoPlayer] Playback Position Changed: " + playhead.ToStr())
			if (m.contentInfo.streamType = ADBMobile().MEDIA_STREAM_TYPE_LIVE)
				ADBMobile().mediaUpdatePlayhead(-1)
			else
		    	ADBMobile().mediaUpdatePlayhead(playhead)
			end if
		
		else if msg.isScreenClosed()
		
			_adb_logger().debug("[ADBVideoPlayer] is Screen Closed: " + msg.GetIndex().ToStr() + " msg: " + msg.GetMessage())
			ADBMobile().mediaTrackUnload()
			m.hbInitialized = false

		else if msg.isStreamSegmentInfo()
		
		else if msg.isTimedMetaData()
					
        else
            _adb_logger().debug("[ADBVideoPlayer] Unexpected event type: " + type(msg))
        end if
    else
        _adb_logger().debug("[ADBVideoPlayer] Unexpected message class: " + type(msg))
    end if
	
	return TRUE
		
End Function

Function _adb_message(messageJson As Object) As Object
    
    instance = {
      _init: Function(messageJson As Object) As Boolean
      	m["JSON_CONFIG_TEMPLATE"] = "template"
		m["JSON_CONFIG_MESSAGE_ID"] = "messageId"
		m["JSON_CONFIG_SHOW_RULE"] = "showRule"
		m["JSON_CONFIG_START_DATE"] = "startDate"
		m["MESSAGE_JSON_PAYLOAD"] = "payload"
		m["JSON_CONFIG_END_DATE"] = "endDate"
		m["JSON_CONFIG_SHOW_OFFLINE"] = "showOffline"
		m["JSON_CONFIG_AUDIENCES"] = "audiences"
		m["JSON_CONFIG_TRIGGERS"] = "triggers"
		m["JSON_CONFIG_ASSETS"] = "assets"
		m["MESSAGE_IMAGE_CACHE_DIR"] = "messageImages"
		m["JSON_DEFAULT_START_DATE"] = 0
		m["JSON_DEFAULT_SHOW_OFFLINE"] = "false"
		m["MESSAGE_ENUM_STRING_UNKNOWN"] = "unknown"
		m["MESSAGE_SHOW_RULE_STRING_ALWAYS"] = "always"
		m["MESSAGE_SHOW_RULE_STRING_ONCE"] = "once"
		m["MESSAGE_SHOW_RULE_STRING_UNTIL_CLICK"] = "untilClick"
		m["MESSAGE_TEMPLATE_STRING_ALERT"] = "alert"
		m["MESSAGE_TEMPLATE_STRING_FULLSCREEN"] = "fullscreen"
		m["MESSAGE_TEMPLATE_STRING_LOCAL_NOTIFICATION"] = "local"
		m["MESSAGE_TEMPLATE_STRING_CALLBACK"] = "callback"
		m["MESSAGE_TYPE_HANDLER"] = "handler"
		m["MESSAGE_TYPE"] = "type"
		m["COMBINED_VARS"] = "combinedVars"
 
		m["ADB_TEMPLATE_CALLBACK_URL"]       = "templateurl"
		m["ADB_TEMPLATE_CALLBACK_BODY"]      = "templatebody"
		m["ADB_TEMPLATE_CALLBACK_TYPE"]		 = "contenttype"
		m["ADB_TEMPLATE_CALLBACK_TIMEOUT"]   = "timeout"

		m["ADB_TEMPLATE_TOKEN_START"]        = "{"
		m["ADB_TEMPLATE_TOKEN_END"]          = "}"
		m["ADB_TEMPLATE_TIMEOUT_DEFAULT"]    = 2

		m[m.JSON_CONFIG_MESSAGE_ID] = ""
		m[m.JSON_CONFIG_TEMPLATE] = ""
		m[m.MESSAGE_TYPE_HANDLER] = invalid
		m[m.JSON_CONFIG_START_DATE] = m.JSON_DEFAULT_START_DATE
		m[m.JSON_CONFIG_END_DATE] = invalid
		m[m.JSON_DEFAULT_SHOW_OFFLINE] = m.JSON_DEFAULT_SHOW_OFFLINE
		m[m.JSON_CONFIG_AUDIENCES] = []
		m[m.JSON_CONFIG_TRIGGERS] = []
		m[m.MESSAGE_TYPE] = invalid
		m[m.COMBINED_VARS] = {}

		m["validLetters"] = {}
	  	m.validLetters["a"] = 1
	  	m.validLetters["b"] = 1
	  	m.validLetters["c"] = 1
	  	m.validLetters["d"] = 1
	  	m.validLetters["e"] = 1
	  	m.validLetters["f"] = 1
	  	m.validLetters["g"] = 1
	  	m.validLetters["h"] = 1
	  	m.validLetters["i"] = 1
	  	m.validLetters["j"] = 1
	  	m.validLetters["k"] = 1
	  	m.validLetters["l"] = 1
	  	m.validLetters["m"] = 1
	  	m.validLetters["n"] = 1
		m.validLetters["o"] = 1
		m.validLetters["p"] = 1
		m.validLetters["q"] = 1
		m.validLetters["r"] = 1
		m.validLetters["s"] = 1
		m.validLetters["t"] = 1
		m.validLetters["u"] = 1
		m.validLetters["v"] = 1
		m.validLetters["w"] = 1
		m.validLetters["x"] = 1
		m.validLetters["y"] = 1
		m.validLetters["z"] = 1
		m.validLetters["0"] = 1
		m.validLetters["1"] = 1
		m.validLetters["2"] = 1
		m.validLetters["3"] = 1
		m.validLetters["4"] = 1
		m.validLetters["5"] = 1
		m.validLetters["6"] = 1
		m.validLetters["7"] = 1
		m.validLetters["8"] = 1
		m.validLetters["9"] = 1
		m.validLetters["_"] = 1
		m.validLetters["."] = 1
		m.validLetters["%"] = 1

		m["_http"] = CreateObject("roUrlTransfer")
		m["_port"] = CreateObject("roMessagePort")

       	''' configure        
        m._http.SetMessagePort(m._port)
        m._http.SetCertificatesFile("common:/certs/ca-bundle.crt")

        if messageJson <> invalid
        	if messageJson[m.JSON_CONFIG_TEMPLATE] <> invalid
        		m[m.JSON_CONFIG_TEMPLATE] = messageJson[m.JSON_CONFIG_TEMPLATE]

				if m[m.JSON_CONFIG_TEMPLATE] = m.MESSAGE_TEMPLATE_STRING_CALLBACK
					m[m.MESSAGE_TYPE_HANDLER] = _adb_message_template_callback()
					m[m.MESSAGE_TYPE] = m.MESSAGE_TEMPLATE_STRING_CALLBACK				
				else
					_adb_logger().warning("Message - unable to create instance of message with that template")
					return false
				end if
			else
				_adb_logger().warning("Message - template is required for postback message")
				return false
			end if
      	end if
      	
      	return m.setMsgJson(messageJson)
      End Function,

      setMsgJson: Function(messageJson as Object) As Boolean

      	if messageJson <> invalid
			
			'messageId
			if messageJson[m.JSON_CONFIG_MESSAGE_ID] <> invalid AND messageJson[m.JSON_CONFIG_MESSAGE_ID].ToStr() <> ""
				m[m.JSON_CONFIG_MESSAGE_ID] = messageJson[m.JSON_CONFIG_MESSAGE_ID]
			else 
				_adb_logger().warning("Message - unable to create instance of message without message id")
				return false
			end if

			'payload
			if messageJson[m.MESSAGE_JSON_PAYLOAD] <> invalid
				m[m.MESSAGE_JSON_PAYLOAD] = messageJson[m.MESSAGE_JSON_PAYLOAD]
				payloadParseSuccess = m.setPayload()
				
				if payloadParseSuccess = false
					return false
				end if
			else
				_adb_logger().warning("Data Callback - Unable to create data callback. payload is empty")
				return false
			end if

			'showRule
			if messageJson[m.JSON_CONFIG_SHOW_RULE] <> invalid AND messageJson[m.JSON_CONFIG_SHOW_RULE].ToStr() <> ""
				if messageJson[m.JSON_CONFIG_SHOW_RULE] = m[m.MESSAGE_ENUM_STRING_UNKNOWN]
					_adb_logger().warning("Message - Messages - Unable to create message. showrule is invalid")
					return false
				end if

				isValidShowRule = m.checkValidShowRule(messageJson[m.JSON_CONFIG_SHOW_RULE])

				if isValidShowRule = false
					_adb_logger().warning("Message - unsupported message rule")
					return false
				end if

				m[m.JSON_CONFIG_SHOW_RULE] = messageJson[m.JSON_CONFIG_SHOW_RULE]
			end if

			'startDate
			if messageJson[m.JSON_CONFIG_START_DATE] <> invalid AND messageJson[m.JSON_CONFIG_START_DATE].ToStr() <> ""
				startDate = messageJson[m.JSON_CONFIG_START_DATE]
			else
				startDate = m["JSON_DEFAULT_START_DATE"]				
			end if
			m[m.JSON_CONFIG_START_DATE] = startDate

			'endDate
			if messageJson[m.JSON_CONFIG_END_DATE] <> invalid AND messageJson[m.JSON_CONFIG_END_DATE].ToStr() <> ""			
				endDate = messageJson[m.JSON_CONFIG_END_DATE]
				m[m.JSON_CONFIG_END_DATE] = endDate
			else
				_adb_logger().warning("Message - cannot create message. endDate is invalid.")
				return false
			end if

			'showOffline
			if messageJson[m.JSON_CONFIG_SHOW_OFFLINE] <> invalid AND messageJson[m.JSON_CONFIG_SHOW_OFFLINE].ToStr() <> ""
				m[m.JSON_CONFIG_SHOW_OFFLINE] = messageJson[m.JSON_CONFIG_SHOW_OFFLINE]
			else
				m[m.JSON_CONFIG_SHOW_OFFLINE] = m[m.JSON_DEFAULT_SHOW_OFFLINE]
			end if

			'audiences
			if messageJson[m.JSON_CONFIG_AUDIENCES] <> invalid AND messageJson[m.JSON_CONFIG_AUDIENCES].count() > 0
				audiencesArray = messageJson[m.JSON_CONFIG_AUDIENCES]

				for each audience in audiencesArray
					matcher = _adb_message_matcher(audience)
					m[m.JSON_CONFIG_AUDIENCES].Push(matcher)
				endFor
			end if

			'triggers
			if messageJson[m.JSON_CONFIG_TRIGGERS] <> invalid AND messageJson[m.JSON_CONFIG_TRIGGERS].count() > 0
				triggersArray = messageJson[m.JSON_CONFIG_TRIGGERS]

				for each trigger in triggersArray
					matcher = _adb_message_matcher(trigger)
					m[m.JSON_CONFIG_TRIGGERS].Push(matcher)
				endFor
			end if

			if m[m.JSON_CONFIG_TRIGGERS].count() <= 0
				_adb_logger().warning("Messages - Unable to load message - at least one valid trigger is required for a message.")
				return false
			else
				_adb_logger().warning("Messages - " + m[m.JSON_CONFIG_TRIGGERS].count().toStr() + " triggers found")
			end if

			return true
		end if

		_adb_logger().warning("Messages - empty messages")
		return false
	  End Function,

	  setPayload: Function() As Boolean
	  	payload = m[m.MESSAGE_JSON_PAYLOAD]
	  	
	  	'templateURL		
		if payload[m.ADB_TEMPLATE_CALLBACK_URL] <> invalid AND payload[m.ADB_TEMPLATE_CALLBACK_URL] <> ""
			m[m.ADB_TEMPLATE_CALLBACK_URL] = payload[m.ADB_TEMPLATE_CALLBACK_URL]
		else
			_adb_logger().warning("Data Callback - Unable to create data callback. templateurl is required")
			return false
		end if

		'timeout
		if payload[m.ADB_TEMPLATE_CALLBACK_TIMEOUT] <> invalid
			m[m.ADB_TEMPLATE_CALLBACK_TIMEOUT] = payload[m.ADB_TEMPLATE_CALLBACK_TIMEOUT]
		else
			_adb_logger().warning("Data Callback - setting default timeout")
			m[m.ADB_TEMPLATE_CALLBACK_TIMEOUT] = m[m.ADB_TEMPLATE_TIMEOUT_DEFAULT]
		end if

		'templatebody
		if payload[m.ADB_TEMPLATE_CALLBACK_BODY] <> invalid AND payload[m.ADB_TEMPLATE_CALLBACK_BODY].toStr() <> ""
			m[m.ADB_TEMPLATE_CALLBACK_BODY] = payload[m.ADB_TEMPLATE_CALLBACK_BODY]
			m[m.ADB_TEMPLATE_CALLBACK_TYPE] = payload[m.ADB_TEMPLATE_CALLBACK_TYPE]
		else
			_adb_logger().warning("Data Callback - Unable to read templatebody. This is not a required field")
		end if

		return true
	  End Function,

	  checkValidShowRule: Function(ruleName As String) As Boolean
	  	if ruleName = m.MESSAGE_SHOW_RULE_STRING_ALWAYS OR ruleName = MESSAGE_SHOW_RULE_STRING_ONCE
	  		return true
	  	end if

	  	return false
	  End Function,

	  shouldShowForVariables: Function(vars As Object, cData As Object) As Boolean
          if cData <> invalid
            m[m.COMBINED_VARS].append(cData)
          end if

          if vars <> invalid
            m[m.COMBINED_VARS].append(vars)
          end if

          m.putMapForTemplatedTokens(m[m.COMBINED_VARS])

          'check within valid date
          dt = CreateObject ("roDateTime")
          secsGmt = dt.AsSeconds()

          startDate = m[m.JSON_CONFIG_START_DATE]
          if startDate <> invalid             
            if secsGmt < startDate
          		return false
	        end if
	      end if

		  endDate = m[m.JSON_CONFIG_END_DATE]
	      if endDate <> invalid	      	
	      	if secsGmt > endDate
          		return false
          	end if
	      end if

	      'check audiences

          'check triggers
          triggers = m[m.JSON_CONFIG_TRIGGERS]
          if triggers <> invalid AND triggers.Count() > 0

          	'ToDo(Prerna) check if we need to clean cData keys
          	cdataCleaned = m.cleanContextDataDictionary(cData)
          	
          	for each matcher in triggers
				if matcher.matchesInMaps(vars, cdataCleaned) = false
					return false
					exit for
				end if
          	end for
          end if
		 
          return true
	  End Function,

	  cleanContextDataDictionary : Function(cData As Object) As Object
	  	return cData
	  End Function,

	  putMapForTemplatedTokens: Function(vars As Object) As Void
	  	mapForTemplatedTokens = {}
	  	
	  	mapForTemplatedTokens["%mcid%"] = _adb_visitor().marketingCloudID()

	  	dt = CreateObject ("roDateTime")
	  	secsGmt = dt.AsSeconds()

	  	dtISO8601String = dt.ToISOString()	  

        'Convert the current time to ISO8601 format
		mapForTemplatedTokens["%timestampz%"] = dtISO8601String

		mapForTemplatedTokens["%timestampu%"] = secsGmt

		'Convert the current time to ISO8601 format
	  	mapForTemplatedTokens["%sdkver%"] = ADBMobile().version
        mapForTemplatedTokens["%cachebust%"] = Rnd(100000000).toStr()

        joinedVars = _adb_urlEncoder().serializeParameters(vars)
        if joinedVars.Len() > 2
          joinedVars = joinedVars.Mid(1)
        end if        
       	mapForTemplatedTokens["%all_url%"] = joinedVars

		if vars<> invalid
	       	joinedVarsJsonString = FormatJson(vars)
	       	if joinedVarsJsonString <> invalid
	       		mapForTemplatedTokens["%all_json%"] = joinedVarsJsonString
	       	end if
		end if
        
        m[m.COMBINED_VARS].append(mapForTemplatedTokens)
	  End Function,

	  show: Function() As Void
	  	templateURL = m[m.ADB_TEMPLATE_CALLBACK_URL]
	  	expandedURL = templateURL

	  	tokens = m.findTokensForExpansion(templateURL)
	  	urlExapnsions = m.buildExpansionsForTokens(tokens, true)

	  	nonEncodedParamsList = []
	  	nonEncodedParamsList.push("{%all_url%}")
	  	nonEncodedURLExpansions = m.buildExpansionsForTokens(nonEncodedParamsList,false)

		urlExapnsions.append(nonEncodedURLExpansions)

	  	if urlExapnsions <> invalid AND urlExapnsions.Count() > 0
	  		expandedURL = m.expandURL(templateURL,urlExapnsions)
	  	end if

	  	templateBody = m[m.ADB_TEMPLATE_CALLBACK_BODY]
	  	expandedBody = templateBody

	  	if templateBody <> invalid
	  		decodedBody = _adb_util().decodeBase64String(templateBody.toStr())
	  		bodyTokens = m.findTokensForExpansion(decodedBody)
	  		contentType = m[m.ADB_TEMPLATE_CALLBACK_TYPE]
	  		shouldEncodeBodyTokens = true

	  		if contentType <> invalid and LCase(contentType).Instr("application/json") <> -1
	  			shouldEncodeBodyTokens = false
	  		end if

	  		bodyExapnsions = m.buildExpansionsForTokens(bodyTokens,shouldEncodeBodyTokens)

	  		nonEncodedBodyParamsList = []
	  		nonEncodedBodyParamsList.push("{%all_url%}")
	  		nonEncodedBodyParamsList.push("{%all_json%}")
		  	nonEncodedBodyExpansions = m.buildExpansionsForTokens(nonEncodedBodyParamsList,false)

			bodyExapnsions.append(nonEncodedBodyExpansions)
	  		
	  		if bodyExapnsions <> invalid AND bodyExapnsions.Count() > 0
	  			expandedBody = m.expandURL(decodedBody,bodyExapnsions)
	  		end if

	  	end if	 
	  	m._sendCallback(expandedURL,expandedBody)

	  End Function,

	  findTokensForExpansion: Function(stringWithTokens As Object) As Object
	  	tokens = []
	  	singleQuote = chr(34)

	  	if stringWithTokens <> invalid AND stringWithTokens.toStr() <> ""
	  		templateURLLength = stringWithTokens.Len()

	  		For i=0 To templateURLLength Step 1
			    s = stringWithTokens.Mid(i,1)

			    if s = m.ADB_TEMPLATE_TOKEN_START
			    	For j=i+1 to templateURLLength Step 1
			    		e = stringWithTokens.Mid(j,1)

						if e = m.ADB_TEMPLATE_TOKEN_END
							exit for
			    		end if
			    	End For

		    		if j = templateURLLength
			    		exit for
			    	end if

			    	token = stringWithTokens.Mid(i,j-i+1)

			    	if m.isValidToken(token.Mid(1,token.Len()-2)) = true
			    		tokens.push(token)
			    		i = j			    	
			    	end if	
			    end if	    
			End For
	  	else
	  		_adb_logger().warning("findTokensForExpansion: empty string with tokens")
	  	end if

	  	return tokens
	  End Function,

	  buildExpansionsForTokens: Function(tokens As Object, urlEncodeExpansions As Boolean) As Object
	  	expansions = {}
	  	combinedVars = m[m.COMBINED_VARS]

         for each key in combinedVars.keys()
             keyStr = key.toStr()
             keyStr = LCase(keyStr)

             if type(keyStr) = "roString" OR type(keyStr) = "String"
                val = combinedVars[keyStr]      
            end if
        end for
	  
	  	combinedVarKeys = combinedVars.keys()

	  	for each token in tokens
	  		cleanToken = token.Mid(1,token.Len()-2).toStr()
	  		cleanToken = LCase(cleanToken)
	  		tokenObject = m[m.COMBINED_VARS].LookupCI(cleanToken)

	  		if tokenObject <> invalid
	  			if urlEncodeExpansions = true
	  				expansions[token] = _adb_urlEncoder()._serializeValue(tokenObject)
	  			else
	  				expansions[token] = tokenObject
	  			end if
	  		else
		  		expansions[token] = ""
		  	end if
	  	end for

	  	return expansions
	  End Function,

	  expandURL: Function(stringWithTokens As Object, expansions As Object) As Object
	  		resultExpandedURL = stringWithTokens

	  		for each expansion in expansions.keys()

	  			while (resultExpandedURL.Instr(expansion) <> -1)
	  				startIndex = resultExpandedURL.Instr(expansion)
	  				expansionValue = expansions.Lookup(expansion)

	  				preExpansionString = resultExpandedURL.Left(startIndex)
	  				postExpansionString = resultExpandedURL.Right(resultExpandedURL.Len() - (startIndex + expansion.Len()))
	  				
	  				if expansionValue <> ""
		  				resultExpandedURL = preExpansionString + expansionValue + postExpansionString
		  			else
		  				resultExpandedURL = preExpansionString + postExpansionString
		  			end if
	  			end while
	  			
	  		end for
	  		return resultExpandedURL
	  End Function,

	  _sendCallback: Function(expandedURL As Dynamic, expandedBody As Dynamic) As Void             
            
             if ADBMobile().getPrivacyStatus() <> ADBMobile().PRIVACY_STATUS_OPT_OUT
             	m._http.SetUrl(expandedURL)
             	
             	_adb_logger().debug("Messaging - Sending signal request (" + expandedURL.toStr() + ")")

             	if expandedBody <> invalid AND expandedBody <> ""
             		m._http.SetRequest("POST")
             		m._http.AsyncPostFromString(expandedBody.toStr())
     			else
	     			m._http.SetRequest("GET")
        			if m._http.AsyncGetToString() = false
            			_adb_logger().error("Messaging - Unable to execute GET request to URL (" + expandedURL.toStr() + ")")
        			end if
    			end if

            end if
      End Function,

	  isValidToken: Function(token As Object) As Boolean
	  	result = true	  	

	  	For i=0 To token.Len()-1 Step 1
	  		s = token.Mid(i,1)
	  		s = LCase(s)

	  		if m.validLetters[s] = invalid
	  			result = false
	  			exit for
	  		end if
	  	End For

	  	return result
	  End Function,
    }

	if instance._init(messageJson) = true
		GetGlobalAA()["_adb_message"] = instance
		return GetGlobalAA()._adb_message
    else
    	_adb_logger().warning("Messages - initialization falied!")
    	return invalid
    end if

End Function

Function _adb_message_matcher(dictionary As Object) As Object
	instance = {
		_init: Function(dictionary As Object) As Void

      		m["MESSAGE_JSON_KEY"] = "key"
      		m["MESSAGE_JSON_MATCHES"] = "matches"
      		m["MESSAGE_JSON_VALUES"] = "values"
      		m["MESSAGE_MATCHER_STRING_EQUALS"] = "eq"
      		m["MESSAGE_MATCHER_STRING_NOT_EQUALS"] = "ne"
      		m["MESSAGE_MATCHER_STRING_GREATER_THAN"] = "gt"
      		m["MESSAGE_MATCHER_STRING_LESS_THAN"] = "lt"
      		m["MESSAGE_MATCHER_STRING_GREATER_THAN_OR_EQUALS"] = "ge"
      		m["MESSAGE_MATCHER_STRING_LESS_THAN_OR_EQUALS"] = "le"
      		m["MESSAGE_MATCHER_STRING_CONTAINS"] = "co"
      		m["MESSAGE_MATCHER_STRING_NOT_CONTAINS"] = "nc"
      		m["MESSAGE_MATCHER_STRING_STARTS_WITH"] = "sw"
      		m["MESSAGE_MATCHER_STRING_ENDS_WITH"] = "ew"
      		m["MESSAGE_MATCHER_STRING_EXISTS"] = "ex"
      		m["MESSAGE_MATCHER_STRING_NOT_EXISTS"] = "nx"
                  m["MESSAGE_MATCHER_STRING_UNKNOWN"] = ""
                  m["MESSAGE_MATCHER_HANDLER"] = "handler"

                  m["MESSAGE_MATCHER_STRING"] = m.MESSAGE_MATCHER_STRING_UNKNOWN
                  m[m.MESSAGE_MATCHER_HANDLER] = invalid

                  m._initMatchers()
                  m.messageMatcherWithJsonObject(dictionary)
		End Function,

            _initMatchers:Function() As Void
                  matchers = {}   
                  matchers[m.MESSAGE_MATCHER_STRING_EQUALS] = _adb_message_matcher_equals() 
                  matchers[m.MESSAGE_MATCHER_STRING_NOT_EQUALS] = _adb_message_matcher_notEquals()
                  matchers[m.MESSAGE_MATCHER_STRING_LESS_THAN] = _adb_message_matcher_lessThan()
                  matchers[m.MESSAGE_MATCHER_STRING_LESS_THAN_OR_EQUALS] = _adb_message_matcher_lessThanEqualTo()
                  matchers[m.MESSAGE_MATCHER_STRING_GREATER_THAN] = _adb_message_matcher_greaterThan()
                  matchers[m.MESSAGE_MATCHER_STRING_GREATER_THAN_OR_EQUALS] = _adb_message_matcher_greaterThanEqualTo()
                  matchers[m.MESSAGE_MATCHER_STRING_CONTAINS] = _adb_message_matcher_contains()
                  matchers[m.MESSAGE_MATCHER_STRING_NOT_CONTAINS] = _adb_message_matcher_notContains()
                  matchers[m.MESSAGE_MATCHER_STRING_STARTS_WITH] = _adb_message_matcher_startsWith()
                  matchers[m.MESSAGE_MATCHER_STRING_ENDS_WITH] = _adb_message_matcher_endsWith()
                  matchers[m.MESSAGE_MATCHER_STRING_EXISTS] = _adb_message_matcher_exists()
                  matchers[m.MESSAGE_MATCHER_STRING_NOT_EXISTS] = _adb_message_matcher_notExists()
                  matchers[m.MESSAGE_MATCHER_STRING_UNKNOWN] = _adb_message_matcher_unknown()
                  
                  m["_matchersDictionary"] = matchers
            End Function,

		messageMatcherWithJsonObject: Function(dictionary as Object) As Void			

                  if dictionary[m.MESSAGE_JSON_MATCHES] <> invalid AND dictionary[m.MESSAGE_JSON_MATCHES].toStr() <> ""
                        _adb_logger().debug("Messages - message matcher type found " + dictionary[m.MESSAGE_JSON_MATCHES])
                        m["MESSAGE_MATCHER_STRING"] = dictionary[m.MESSAGE_JSON_MATCHES].toStr()
                  else
                        _adb_logger().warning("Messages - message matcher type is required. Setting to default unknown")
                        m["MESSAGE_MATCHER_STRING"] = m.MESSAGE_MATCHER_STRING_UNKNOWN
			end if

                  matcherHandler = m.matcherHandlerForMatcherString(m.MESSAGE_MATCHER_STRING.toStr())

                  if matcherHandler <> invalid
                        jsonKeyStr = dictionary[m.MESSAGE_JSON_KEY].toStr()
                        if jsonKeyStr <> invalid AND jsonKeyStr.Len() > 0
                              matcherHandler.key = LCase(dictionary[m.MESSAGE_JSON_KEY].toStr())
                        else
                              _adb_logger().warning("Messages - error creating matcher, key is empty or null")
                        end if

                        'if this is an exists matcher, we know we don't have anything in the values array
                        if m.MESSAGE_MATCHER_STRING = m.MESSAGE_MATCHER_STRING_EXISTS
                              m[m.MESSAGE_MATCHER_HANDLER] = matcherHandler
                              return
                        end if

                        jsonValuesArray = dictionary[m.MESSAGE_JSON_VALUES]
                        if jsonValuesArray <> invalid AND jsonValuesArray.count() > 0
                              matcherHandler.setValues(jsonValuesArray)
                        end if
                  else
                        _adb_logger().debug("Messages - no matcher type found for given string: " + m.MESSAGE_MATCHER_STRING)
                  end if

                  m[m.MESSAGE_MATCHER_HANDLER] = matcherHandler
		End Function,

            matcherHandlerForMatcherString: Function(matcherString as String) As Object
                  result = invalid                  
                  if matcherString <> invalid AND matcherString <> ""
                        result = m["_matchersDictionary"][matcherString]                 
                  end if
                 
                  return result
            End Function,

            matchesInMaps: Function(vars As Object, cData As Object) As Boolean
                  handler = m[m.MESSAGE_MATCHER_HANDLER]

                  if handler <> invalid
                        maps = {}
                        maps.append(vars)
                        maps.append(cData)
                        matchKey = handler["key"]
                        matchKeyStr = matchKey.toStr()

                        value = maps.LookupCI(matchKeyStr)
                        return handler.matches(value)
                  end if

                  return false
            End Function
	}

	instance._init(dictionary)
	GetGlobalAA()["_adb_message_matcher"] = instance
	return GetGlobalAA()._adb_message_matcher
End Function

Function _adb_message_matcher_contains() As Object
	instance = {

		_init: Function() As Void
			m["key"] = ""
			m["values"] = invalid
		End Function,

		setValues: Function(jsonValuesArray As Object) As Void
			if jsonValuesArray <> invalid
				m["values"] = jsonValuesArray
			end if			
		End Function,

		matches: Function(expectedValue As Object) As Boolean
			if expectedValue = invalid
                 return false
            end if

			charsRegex = CreateObject("roRegex", "[a-z]+", "i")

			values = m["values"]

			for each potentialValue in values
				instringIndex = expectedValue.Instr(potentialValue)

				if instringIndex <> -1
					return true
				end if
			end for
			return false
		End Function
	}

	instance._init()
	GetGlobalAA()["_adb_message_matcher_contains"] = instance
	return GetGlobalAA()._adb_message_matcher_contains
End Function

Function _adb_message_matcher_endsWith() As Object
	instance = {

		_init: Function() As Void
			m["key"] = ""
			m["values"] = invalid
		End Function,

		setValues: Function(jsonValuesArray As Object) As Void
			if jsonValuesArray <> invalid
				m["values"] = jsonValuesArray
			end if			
		End Function,

		matches: Function(expectedValue As Object) As Boolean
			values = m["values"]

			for each potentialValue in values
				if m.stringEndsWith(potentialValue, expectedValue) = true
					return true
				end if
			end for

			return false
		End Function,

		stringEndsWith: Function(mainString, searchString) As Boolean
			instringIndex = searchString.Instr(mainString)

			if instringIndex <> -1
				endStringIndex = instringIndex + mainString.Len() - 1

				if endStringIndex = searchString.Len() - 1
					return true
				end if
			end if

			return false

		End Function
	}

	instance._init()
	GetGlobalAA()["_adb_message_matcher_endsWith"] = instance
	return GetGlobalAA()._adb_message_matcher_endsWith
End Function

Function _adb_message_matcher_equals() As Object
	instance = {

		_init: Function() As Void
			m["key"] = ""
			m["values"] = invalid
		End Function,

		setValues: Function(jsonValuesArray As Object) As Void
			if jsonValuesArray <> invalid
				m["values"] = jsonValuesArray
			end if			
		End Function,

		matches: Function(expectedValue As Object) As Boolean			
			if expectedValue = invalid
                 return false
            end if

			values = m["values"]

			for each potentialValue in values
				if potentialValue.toStr() = expectedValue.toStr()
					return true
				end if
			end for

			return false
		End Function
	}

	instance._init()
	GetGlobalAA()["_adb_message_matcher_equals"] = instance
	return GetGlobalAA()._adb_message_matcher_equals
End Function

Function _adb_message_matcher_exists() As Object
	instance = {

		_init: Function() As Void
			m["key"] = ""
			m["values"] = invalid
		End Function,

		setValues: Function(jsonValuesArray As Object) As Void
			if jsonValuesArray <> invalid
				m["values"] = jsonValuesArray
			end if			
		End Function,

		matches: Function(expectedValue As Object) As Boolean
			if expectedValue = invalid
                 return false
            end if	

            return true	
         End Function
	}

	instance._init()
	GetGlobalAA()["_adb_message_matcher_exists"] = instance
	return GetGlobalAA()._adb_message_matcher_exists
End Function

Function _adb_message_matcher_greaterThan() As Object
	
	instance = {
		
		_init: Function() As Void
			m["key"] = ""
			m["values"] = invalid
		End Function,

		setValues: Function(jsonValuesArray As Object) As Void
			if jsonValuesArray <> invalid
				m["values"] = jsonValuesArray
			end if			
		End Function,

		matches: Function(expectedValue As Object) As Boolean
			if expectedValue = invalid
                 return false
            end if

			values = m["values"]

			for each potentialValue in values
				if expectedValue > potentialValue
					return true
				end if
			end for

			return false
		End Function
	}

	instance._init()
	GetGlobalAA()["_adb_message_matcher_greaterThan"] = instance
	return GetGlobalAA()._adb_message_matcher_greaterThan
End Function

Function _adb_message_matcher_greaterThanEqualTo() As Object
		
	instance = {
		_init: Function() As Void
			m["key"] = ""
			m["values"] = invalid
		End Function,

		setValues: Function(jsonValuesArray As Object) As Void
			if jsonValuesArray <> invalid
				m["values"] = jsonValuesArray
			end if			
		End Function,

		matches: Function(expectedValue As Object) As Boolean
			if expectedValue = invalid
                 return false
            end if

			values = m["values"]

			for each potentialValue in values
				if expectedValue >= potentialValue
					return true
				end if
			end for

			return false
		End Function
	}

	instance._init()
	GetGlobalAA()["_adb_message_matcher_greaterThanEqualTo"] = instance
	return GetGlobalAA()._adb_message_matcher_greaterThanEqualTo
End Function

Function _adb_message_matcher_lessThan() As Object
	instance = {

		_init: Function() As Void
			m["key"] = ""
			m["values"] = invalid
		End Function,

		setValues: Function(jsonValuesArray As Object) As Void
			if jsonValuesArray <> invalid
				m["values"] = jsonValuesArray
			end if			
		End Function,

		matches: Function(expectedValue As Object) As Boolean
			if expectedValue = invalid
                 return false
            end if

			values = m["values"]

			for each potentialValue in values
				if expectedValue < potentialValue
					return true
				end if
			end for
			return false
		End Function
	}

	instance._init()
	GetGlobalAA()["_adb_message_matcher_lessThan"] = instance
	return GetGlobalAA()._adb_message_matcher_lessThan
End Function

Function _adb_message_matcher_lessThanEqualTo() As Object
	
	instance = {
		_init: Function() As Void
			m["key"] = ""
			m["values"] = invalid
		End Function,

		setValues: Function(jsonValuesArray As Object) As Void
			if jsonValuesArray <> invalid
				m["values"] = jsonValuesArray
			end if			
		End Function,

		matches: Function(expectedValue As Object) As Boolean
			
			if expectedValue = invalid
                 return false
            end if

			values = m["values"]

			for each potentialValue in values
				if expectedValue <= potentialValue
					return true
				end if
			end for
			
			return false
		End Function
	}

	instance._init()
	GetGlobalAA()["_adb_message_matcher_lessThanEqualTo"] = instance
	return GetGlobalAA()._adb_message_matcher_lessThanEqualTo
End Function

Function _adb_message_matcher_notContains() As Object
	instance = {

		_init: Function() As Void
			m["containsHandler"] = _adb_message_matcher_contains()
		End Function,

		setValues: Function(jsonValuesArray As Object) As Void
			m["containsHandler"].setValues(jsonValuesArray)
		End Function,

		matches: Function(expectedValue As Object) As Boolean
			return NOT m["containsHandler"].matches(expectedValue)
		End Function
	}

	instance._init()
	GetGlobalAA()["_adb_message_matcher_notContains"] = instance
	return GetGlobalAA()._adb_message_matcher_notContains
End Function

Function _adb_message_matcher_notEquals() As Object
	instance = {

		_init: Function() As Void
			m["equalsHandler"] = _adb_message_matcher_equals()
		End Function,

		setValues: Function(jsonValuesArray As Object) As Void
			m["equalsHandler"].setValues(jsonValuesArray)
		End Function,

		matches: Function(expectedValue As Object) As Boolean
			return NOT m["equalsHandler"].matches(expectedValue)
		End Function
	}

	instance._init()
	GetGlobalAA()["_adb_message_matcher_notEquals"] = instance
	return GetGlobalAA()._adb_message_matcher_notEquals
End Function

Function _adb_message_matcher_notExists() As Object
	instance = {

		_init: Function() As Void
			m["existssHandler"] = _adb_message_matcher_exists()
		End Function,

		setValues: Function(jsonValuesArray As Object) As Void
			m["existssHandler"].setValues(jsonValuesArray)
		End Function,

		matches: Function(expectedValue As Object) As Boolean
			return NOT m["existssHandler"].matches(expectedValue)
		End Function
	}

	instance._init()
	GetGlobalAA()["_adb_message_matcher_notExists"] = instance
	return GetGlobalAA()._adb_message_matcher_notExists
End Function

Function _adb_message_matcher_startsWith() As Object
	instance = {

		_init: Function() As Void
			m["key"] = ""
			m["values"] = invalid
		End Function,

		setValues: Function(jsonValuesArray As Object) As Void
			if jsonValuesArray <> invalid
				m["values"] = jsonValuesArray
			end if			
		End Function,

		matches: Function(expectedValue As Object) As Boolean
			values = m["values"]

			for each potentialValue in values
				if m.stringStartsWith(potentialValue, expectedValue) = true
					return true
				end if
			end for

			return false
		End Function,

		stringStartsWith: Function(mainString, searchString) As Boolean
			instringIndex = searchString.Instr(mainString)
			if instringIndex <> -1 AND instringIndex = 0
				return true
			end if

			return false
		End Function
	
	}

	instance._init()
	GetGlobalAA()["_adb_message_matcher_startsWith"] = instance
	return GetGlobalAA()._adb_message_matcher_startsWith
End Function

Function _adb_message_matcher_unknown() As Object
	instance = {

		_init: Function() As Void
			m["key"] = ""
			m["values"] = invalid
		End Function,

		setValues: Function(jsonValuesArray As Object) As Void
			if jsonValuesArray <> invalid
				m["values"] = jsonValuesArray
			end if
			
		End Function
	}

	instance._init()
	GetGlobalAA()["_adb_message_matcher_unknown"] = instance
	return GetGlobalAA()._adb_message_matcher_unknown
End Function

Function _adb_message_template_callback() As Object
      instance = {
	      _init: Function() As Void
    	  End Function,
      
	      setPayloadObject: Function(messageJson as Object) As Void
    	  End Function,

    	  shouldShowForVariables: Function(vars As Object, cData As Object) As Boolean
    	  End Function,

        putMapForTemplatedTokens: Function(combinedVars)
        End Function
      }

      instance._init()
      GetGlobalAA()["_adb_message_template_callback"] = instance

      return GetGlobalAA()._adb_message_template_callback
End Function

Function _adb_messages() As Object
   
    if GetGlobalAA()._adb_messages = invalid 
    	instance = {

            _init: Function() As Void                
            End Function,

    		checkFor3rdPartyCallbacks: Function(vars as Object, cData as Object) As Void
    			callbacks = _adb_config().getCallbackTemplates()
    			if callbacks = invalid OR callbacks.count() = 0
    				return
    			end if

                  for each key in vars.keys()
                    keyStr = key.toStr()

                    if type(keyStr) = "roString" OR type(keyStr) = "String"
                         val = vars[keyStr]      
                    end if
                end for

                lowercaseVars = m.lowercaseKeysForMap(vars)
                lowercaseContextData= m.lowercaseKeysForMap(cData)


                  for each key in lowercaseVars.keys()
                    keyStr = key.toStr()

                    if type(keyStr) = "roString" OR type(keyStr) = "String"
                         val = lowercaseVars[keyStr]
                    end if
                end for



                for each msg in callbacks
                    if msg.shouldShowForVariables(lowercaseVars,lowercaseContextData) = true
                        msg.show()                    
                    end if
                end for
    		End Function,

            lowercaseKeysForMap: Function(vars As Object) As Object
                if vars = invalid OR vars.count() = 0
                    return vars
                end if

                result = {}

                for each key in vars.keys()
                    keyStr = key.toStr()
                    keyStr = LCase(keyStr)

                    if type(keyStr) = "roString" OR type(keyStr) = "String"
                        val = vars[keyStr]
      
                        if val <> invalid
                            result[keyStr] = val
                        end if
                    end if
                end for

                return result
            End Function
    	}

 	instance._init()
    GetGlobalAA()["_adb_messages"] = instance
  end if

  return GetGlobalAA()._adb_messages
End Function

Function _adb_aid() as Object
  if GetGlobalAA()._adb_aid = invalid
    instance = {
      _init: Function() as Void
          aid = _adb_persistenceLayer().readValue("aid")
          ignoreAID = _adb_persistenceLayer().readValue("ignoreAid")

          if aid = invalid AND ignoreAID = invalid
            ''' attempt to retrieve AID from analytics
            aid = m._retrieveremoteAID()

            ''' check if we have aid to save
            if aid <> invalid
              _adb_persistenceLayer().writeValue("aid", aid)
            else
              ''' no aid to save, write the ignore value
              _adb_persistenceLayer().writeValue("ignoreAid", "true")
            end if

          end if

          ''' save our local copy (to whatever it is, could be invalid)
          m["aid"] = aid

          ''' perform id sync if needed.
          m._syncAIDIfNeeded()
        End Function,

      ''' syncs the recently retrieved AID to visitor id service
      _syncAIDIfNeeded: Function() as Void
          if m["aid"] = invalid
            return
          end if

          ''' we need to sync
          if _adb_persistenceLayer().readValue("aid_synced") = invalid AND _adb_config().visitorIDServiceEnabled() = true
            syncPacket = {}
            syncPacket["AVID"] = m["aid"]

            _adb_visitor().idSync(syncPacket)

            _adb_persistenceLayer().writeValue("aid_synced", "true")
          end if
        End Function,

      _retrieveRemoteAID: Function() as Dynamic
          ''' fast out if analytics is disabled
          if _adb_config().analyticsEnabled() = false
            return invalid
          end if

          url = ""
          if _adb_config().ssl = true
            url = "https"
          else
            url = "http"
          end if

          url = url + "://" + _adb_config().trackingServer + "/id" + _adb_visitor().analyticsIDRequestParameterString()

          ''' TODO: handle visitor ID service addition here

          mp = CreateObject("roMessagePort")
          http = CreateObject("roUrlTransfer")
          http.SetMessagePort(mp)
          http.SetUrl(url)
          http.SetCertificatesFile("common:/certs/ca-bundle.crt")
          http.SetRequest("GET")
          
          success = http.AsyncGetToString()

          identifier = invalid
          if success = true
            response = wait(500, mp)

            if type(response) = "roUrlEvent" AND response.GetResponseCode() = 200
              responseString = response.GetString()
              jsonResponse = ParseJson(responseString)
              if jsonResponse <> invalid
                identifier = jsonResponse["id"]
              end if
            end if
          end if

          ''' if we don't have an identifier and visitor id service is enabled, we're not going to generate one
          if identifier = invalid AND _adb_config().visitorIDServiceEnabled() = true
            return invalid
          end if

          ''' if we get here, we need to generate an id
          if identifier = invalid
            identifier = m._generateLocalAID()
          end if

          return identifier
        End Function,
      _generateLocalAID: Function() as String
          uuid = CreateObject("roDeviceInfo").GetRandomUUID()
          dashRegex = CreateObject("roRegex", "[\-]", "i")

          uuid = UCase(dashRegex.ReplaceAll(uuid, ""))

          HI_ALLOWED_CHARS = ["0", "1", "2", "3", "4", "5", "6", "7"]
          LO_ALLOWED_CHARS = ["0", "1", "2", "3"]

          first16 = HI_ALLOWED_CHARS[Rnd(8) - 1] + Right(Left(uuid, 16), 15)
          last16 = LO_ALLOWED_CHARS[Rnd(4) - 1] + Right(uuid, 15)

          return first16 + "-" + last16
        End Function
    }

    instance._init()

    GetGlobalAA()["_adb_aid"] = instance
  end if

  return GetGlobalAA()._adb_aid
End Function

Function _adb_config() as Object
  if GetGlobalAA()._adb_config = invalid
    instance = {
      ''' shared
      version: "4.0.0",
      debugEnabled: false,
 
      ''' Analytics
      userIdentifier: invalid,
      reportSuiteIDs: invalid,
      trackingServer: invalid,
      characterSet: "UTF-8",
      ssl: false,
      offlineTrackingEnabled: false,
      lifecycleTimeout: 300,
      privacyDefault: "optedin",
 
      ''' Audience Manager
      aamServer: invalid,
 
      ''' marketing cloud
      marketingCloudOrganizationIdentifier: invalid,
      visitorIDServiceEnabled: false,
 
      ''' Media Heartbeat
      mHeartbeatConfigUrl: invalid,
      mTrackingServer: invalid,
      mPublisher: invalid,
      mChannel: invalid,
      mPlayerName: invalid,
      mSSL: false,    
      ovp: invalid,
      mSdk: invalid,
      _config: invalid,

      MESSAGE_TYPE: "type",
 
      ''' internal private
      _parseConfig: Function() As Object
        fs = CreateObject("roFileSystem")
        if fs.exists("tmp:/ADBMobileConfig.json")
          tempConfig = ReadAsciiFile("tmp:/ADBMobileConfig.json")
          if tempConfig <> invalid AND tempConfig <> ""
            return ParseJson(tempConfig)
          end if
        end if

        return ParseJson(ReadAsciiFile("pkg:/ADBMobileConfig.json"))    
      End Function,

      _init: Function() as Void  

          m["_config"] =  m._parseConfig()

          ''' read user identifier
          m["userIdentifier"] = _adb_persistenceLayer().readValue("vid")
 
          if m.userIdentifier <> invalid
            _adb_logger().debug("Config - Found custom visitor id(" + m.userIdentifier + ")")
          end if
 
          ''' need to make sure we have a valid config object
          if m._config = invalid
            _adb_logger().error("Config - Unable to read config file from pkg:/ADBMobileConfig.json")
            return
          end if
 
          ''' analytics data
          if m._config.analytics <> invalid
            if m._config.analytics.offlineEnabled <> invalid
              m["offlineTrackingEnabled"] = m._config.analytics.offlineEnabled
            end if
 
            if m._config.analytics.rsids <> invalid
              m["reportSuiteIDs"] = m._config.analytics.rsids
            end if
 
            if m._config.analytics.server <> invalid
              m["trackingServer"] = m._config.analytics.server
            end if
 
            if m._config.analytics.ssl <> invalid
              m["ssl"] = m._config.analytics.ssl
            end if
 
            if m._config.analytics.lifecycleTimeout <> invalid
              m["lifecycleTimeout"] = m._config.analytics.lifecycleTimeout
            end if
 
            if m._config.analytics.privacyDefault <> invalid
              m["privacyDefault"] = m._config.analytics.privacyDefault
            end if
          end if
 
          if m.reportSuiteIDs <> invalid AND m.trackingServer <> invalid
            _adb_logger().debug("Config - Analytics Enabled")
          else
            _adb_logger().debug("Config - Analytics Disabled")
          end if
 
          ''' audience manager
          if m._config.audienceManager <> invalid
            if m._config.audienceManager.server <> invalid
              m["aamServer"] = m._config.audienceManager.server
            end if
          end if
 
          if m.aamServer <> invalid
            _adb_logger().debug("Config - Audience Manager Enabled")
          else
            _adb_logger().debug("Config - Audience Manager Disabled")
          end if
 
          ''' marketing cloud data
          if m._config.marketingCloud <> invalid
            if m._config.marketingCloud.org <> invalid
              m["marketingCloudOrganizationIdentifier"] = m._config.marketingCloud.org
            end if
          end if

          ''' remote urls
          remotes = m._config.remotes
          messageObjects = invalid

          if remotes <> invalid
            if remotes.messages <> invalid
              msgURL = remotes.messages
              remoteMsgObjects = m.remoteMessages(msgURL)
              if remoteMsgObjects <> invalid
                messageObjects = ParseJson(remoteMsgObjects)
              end if
            end if
          end if

          ''' local messages
          if messageObjects = invalid
            messageObjects = m._config.messages
          end if

          if messageObjects <> invalid
            if (messageObjects.count() > 0)
              
              tempCallbackMessages = []

              for each msg in messageObjects
                msgObject = _adb_message(msg)
                if msgObject <> invalid
                  if msgObject[m.MESSAGE_TYPE] = "callback"
                    tempCallbackMessages.Push(msgObject)
                  end if
                else
                  _adb_logger().debug("Invalid message object.")
                end if
              end for

              m["callbackMessages"] = tempCallbackMessages
            end if

          end if          

          ''' media heartbeat data
          _adb_media_setErrorState(false)

          if m._config.mediaHeartbeat <> invalid            
             m.configureMediaHeartbeat(m._config.mediaHeartbeat)
          else
            _adb_logger().warning("Config - Media Heartbeat config missing in JSON.")
            _adb_media_setErrorState(true)
          end if

          if m._config.remotes <> invalid and m._config.remotes.mediaHeartbeat <> invalid
            mHeartbeatConfigUrl = m._config.remotes.mediaHeartbeat
            _adb_logger().debug("Config - Fetching media heartbeat config form JSON Url: " + mHeartbeatConfigUrl)
 
            ' Todo: change this to an async call in future
            url_object = CreateObject("roUrlTransfer")
            url_object.SetCertificatesFile("common:/certs/ca-bundle.crt")
            url_object.setUrl(mHeartbeatConfigUrl)
            media_config_json = ParseJson(url_object.GetToString())
            m.configureMediaHeartbeat(media_config_json)
          end if
 
          ''' log status
          if m.visitorIDServiceEnabled() = true
            _adb_logger().debug("Config - Visitor ID Service Enabled")
          else
            _adb_logger().debug("Config - Visitor ID Service Disabled")
          end if
 
        End Function,
 
      visitorIDServiceEnabled: Function() as Boolean
          return m.marketingCloudOrganizationIdentifier <> invalid AND Len(m.marketingCloudOrganizationIdentifier) > 0
        End Function,
      analyticsEnabled: Function() as Boolean
          return m.trackingServer <> invalid AND m.reportSuiteIDs <> invalid
        End Function,
      audienceManagerEnabled: Function() as Boolean
          return m.aamServer <> invalid AND Len(m.aamServer) > 0
        End Function,
      setUserIdentifier: Function(id as Dynamic) as Void
          m["userIdentifier"] = id
          _adb_persistenceLayer().writeValue("vid", id)
        End Function,
      configureMediaHeartbeat: Function(mediaConfig as Dynamic) as Void            
          if mediaConfig <> invalid
            if mediaConfig.server <> invalid
              m["mTrackingServer"] = mediaConfig.server
            end if
            if mediaConfig.publisher <> invalid
              m["mPublisher"] = mediaConfig.publisher
            end if
            if mediaConfig.channel <> invalid
              m["mChannel"] = mediaConfig.channel
            end if  
            if mediaConfig.ovp <> invalid
              m["ovp"] = mediaConfig.ovp
            end if
            if mediaConfig.sdkVersion <> invalid
              m["mSdk"] = mediaConfig.sdkVersion
            end if
            if mediaConfig.ssl <> invalid
              m["mSSL"] = mediaConfig.ssl
            end if
            if mediaConfig.playerName <> invalid
              m["mPlayerName"] = mediaConfig.playerName
            end if            
          else
            _adb_logger().debug("Config - Invalid media config object.")            
          end if
		  
			' basic check to see if config was set
			if m.mTrackingServer <> invalid AND m.mPublisher <> invalid
			  _adb_logger().debug("Config - Media Heartbeat Enabled")
			else 
			  _adb_logger().debug("Config - Media Heartbeat Disabled")
			  _adb_media_setErrorState(true)
			end if		            
        End Function,

      getCallbackTemplates: Function() as Object
        return m["callbackMessages"]
      End Function,

      remoteMessages: Function(msgURL as Object) as Object

        if msgURL <> invalid AND msgURL.toStr().Len() > 0
            url_object = CreateObject("roUrlTransfer")
            url_object.SetCertificatesFile("common:/certs/ca-bundle.crt")
            url_object.setUrl(msgURL)

            messages_json = ParseJson(url_object.GetToString())
            if messages_json <> invalid
              messagesObject = FormatJson(messages_json.messages)

              if messagesObject <> invalid
                return messagesObject
              end if
            
            end if

        end if

        return invalid
      End Function
    }
 
    instance._init()
 
    GetGlobalAA()["_adb_config"] = instance
  end if
 
  return GetGlobalAA()._adb_config
End Function

Function _adb_logger() as Object
  if GetGlobalAA()._adb_logger = invalid
    instance = {
      debugLoggingEnabled: false,
      warning: Function(message as String) as Void
          if m.debugLoggingEnabled = true
            print "ADBMobile Warning: " + message
          end if
        End Function,
      error: Function(message as String) as Void
          print "ADBMobile Error: " + message
        End Function,
      debug: Function(message as String) as Void
          if m.debugLoggingEnabled = true
            print "ADBMobile Debug: " + message
          end if
        End Function
    }

    GetGlobalAA()["_adb_logger"] = instance
  end if

  return GetGlobalAA()._adb_logger
End Function

Function _adb_media_version() as Object
  if GetGlobalAA()._adb_media_version = invalid
    instance = {

      getVersion: Function() as String
          return m._platform + "-" + m._major + "." + m._minor + "." + m._micro + "." + m._patch + "-" + m._build
        End Function,

      getApiLevel: Function() as Integer
          return m._api_level
        End Function,

      ''' initialize the private variables
      _init: Function() As Void
          m["_platform"] = "roku"
          m["_major"] = "1"
          m["_minor"] = "0"
          m["_micro"] = "0"
          m["_patch"] = "0"
          m["_build"] = "0"
          m["_api_level"] = 3
        End Function
    }

    instance._init()
    GetGlobalAA()["_adb_media_version"] = instance
  end if

  return GetGlobalAA()._adb_media_version
End Function

Function _adb_persistenceLayer() as Object
  if GetGlobalAA()._adb_persistenceLayer = invalid
    instance = {
      ''' private internal variables
      _registry: CreateObject("roRegistrySection", "adbmobile"),

      ''' public Functions
      writeValue: Function(key as String, value as Dynamic) as Dynamic
          m._registry.Write(key, value)
          m._registry.Flush()
        End Function,
      readValue: Function(key as String) as Dynamic
          if m._registry.Exists(key)
            return m._registry.Read(key)
          end if

          return invalid
        End Function,
      removeValue: Function(key as String) as Void
          m._registry.Delete(key)
        End Function
    }
    GetGlobalAA()["_adb_persistenceLayer"] = instance
  end if

  return GetGlobalAA()._adb_persistenceLayer
End Function

Function _adb_timer() As Object
  instance = {

    ''' public Functions
    start: Function(interval as Integer, name as String) As Void
        if m._enabled = false
          _adb_logger().debug("Timer - starting " + name + " timer with interval (" + interval.ToStr() + ")")
          m._interval = interval
          m._name = name
          m._ts.Mark()
          m._nextTick = m._interval 
          m._enabled = true
        else 
          _adb_logger().debug("Timer -  " + m._name + " timer already started.")
        end if
      End Function,

    stop: Function() As Void
        if m._enabled = true
          _adb_logger().debug("Timer - stoping " + m._name + " timer.")
          m._enabled = false
          m._nextTick = invalid
        else 
          _adb_logger().debug("Timer -  " + m._name + " timer already stopped.")
        end if
      End Function,

    restartWithNewInterval: Function(newInterval as Integer) As Void
        _adb_logger().debug("Timer - restarting " + m._name + " timer with interval (" + newInterval.ToStr() + ")")
        m._interval = newInterval
        m._ts.Mark()          
        m._nextTick = m._interval 
        m._enabled = true
      End Function,

    reset: Function() As Void        
        _adb_logger().debug("Timer - resetting " + m._name)          
        m._ts.Mark()          
        m._nextTick = m._interval
        m._enabled = true         
      End Function,

    ticked: Function() As Boolean
        ticked = false
        milliseconds = m._ts.TotalMilliseconds()
        
        if milliseconds >= m._nextTick
          m._nextTick = milliseconds + m._interval
          ticked = true
        end if

        return ticked
      End Function,

    elapsedTime: Function() As Integer
        return m._ts.TotalMilliseconds()
      End Function,

    ''' initialize the private variables
    _init: Function() As Void
        m["_ts"] = CreateObject ("roTimespan")
        m["_interval"] = invalid
        m["_name"] = invalid
        m["_enabled"] = false
        m["_nextTick"] = invalid
      End Function

  }

  instance._init()

  return instance
End Function

Function _adb_util() as Object
  if GetGlobalAA()._adb_util = invalid
    instance = {
      getTimestampInMillis: Function() as String
          dateTime = CreateObject("roDateTime")
          curr_millis = dateTime.GetMilliseconds()
          timeInSeconds = CreateObject("roDateTime").AsSeconds()
          timeInMillis = timeInSeconds.ToStr()

          if curr_millis > 99
            timeInMillis = timeInMillis + curr_millis.ToStr()
          else if curr_millis > 9 AND curr_millis < 100
            timeInMillis = timeInMillis + "0" + curr_millis.ToStr()
          else if curr_millis >= 0 AND curr_millis < 10
            timeInMillis = timeInMillis + "00" + curr_millis.ToStr()
          end if

          return timeInMillis
        End Function,

      generateMD5: Function(input As String) As String
          ba = CreateObject("roByteArray")
          ba.FromAsciiString(input)
          digest = CreateObject("roEVPDigest")
          digest.Setup("md5")
          digest.Update(ba)

          return digest.Final()
        End Function,

      generateSessionId: Function() As String
          currTime = m.getTimestampInMillis()
          randomNumber = Rnd(1000000000).ToStr()
          result$ = currTime + randomNumber

          return result$
        End Function,

      calculateTimeDiffInMillis: Function(ts1 As String, ts2 As String) As Integer          
          result% = Mid(ts1, 5).ToInt() - Mid(ts2, 5).ToInt()          
          return result%
        End Function,

      decodeBase64String: Function(encodedString As String) As Object
        ba=CreateObject("roByteArray")
        ba.FromBase64String(encodedString)
        return ba.ToAsciiString()
      End Function
    }

    GetGlobalAA()["_adb_util"] = instance
  end if

  return GetGlobalAA()._adb_util
End Function


Function _adb_visitor() as Object
  if GetGlobalAA()._adb_visitor = invalid
    instance = {
      ''' private vars
      _mid: _adb_persistenceLayer().readValue("visitor_mid"),
      _blob: _adb_persistenceLayer().readValue("visitor_blob"),
      _hint: _adb_persistenceLayer().readValue("visitor_hint"),
      _ttl: _adb_persistenceLayer().readValue("visitor_ttl"),
      _lastSync: _adb_persistenceLayer().readValue("visitor_sync"),
      _urlEncoder: CreateObject("roUrlTransfer"),
      _supportsCount: false,

      ''' init Function
      _init: Function() as Void
          if m._lastSync = invalid : m._lastSync = "0" : end if
          if m._ttl = invalid : m._ttl = "0" : end if

          m._supportsCount = type(Eval("test = {} : test.Count()")) <> "roList"

          m.idSync({})
        End Function,

      ''' private methods

      ''' saves the given key/value to persistent storage
      ''' auto converts value to string, if value is invalid the key will be removed.
      _saveIfValid: Function(key as string, value as dynamic) as Void
          if value <> invalid
            if type(value) = "Integer" OR type(value) = "roInteger"
              value = value.ToStr()
            end if

            _adb_persistenceLayer().writeValue(key, value)
          else
            _adb_persistenceLayer().removeValue(key)
          end if
        End Function,

      ''' generate 63 bit random integer as a strong (64 bit signed positive only)
      _makeRandInt: Function() as String
          ''' ensure that we don't get 9 as a starting value, which could make an out of bounds int
          padVal = Rnd(9) - 1
          returnVal = padVal.ToStr()
          for i = 1 to 18
            newval = Rnd(10) - 1
            returnVal = returnVal + newval.ToStr()
          end for
          return returnVal
        End Function,

      ''' generates a marketing cloud visitor id locally
      _generateLocalMid: Function() as String
          return m._makeRandInt() + m._makeRandInt()
        End Function,

      ''' public methods

      ''' performs an identifier sync
      idSync: Function(identifiers as Dynamic) as Void
          ''' fail fast if we're not provisioned for visitor id service
          if _adb_config().visitorIDServiceEnabled() = false
            return
          end if

          ''' get org id
          orgId = _adb_config().marketingCloudOrganizationIdentifier

          ''' check if we need to resync based on ttl.  this only occurs on blind sync (when no identifiers are passed)
          needResync = (CreateObject("roDateTime").AsSeconds() - m._lastSync.ToInt()) > m._ttl.ToInt()


          if m._mid <> invalid AND m._supportsCount AND identifiers.Count() = 0 AND needResync = false
            return
          end if

          url = ""
          if _adb_config().ssl = true
            url = "https"
          else
            url = "http"
          end if

          url = url + "://dpm.demdex.net/id?d_rtbd=json&d_ver=2&d_orgid=" + orgId

          ''' apply url parameters
          if m._blob <> invalid
            url = url + _adb_urlEncoder()._serializeKeyValuePair("d_blob", m._blob)
          end if

          if m._mid <> invalid
            url = url + _adb_urlEncoder()._serializeKeyValuePair("d_mid", m._mid)
          end if

          if m._hint <> invalid
            url = url + _adb_urlEncoder()._serializeKeyValuePair("dcs_region", m._hint)
          end if

          ''' append identifiers
          for each key in identifiers
            url = url + "&d_cid_ic=" + m._urlEncoder.Escape(key) + "%01" + m._urlEncoder.Escape(identifiers[key])
          end for

          ''' create connection for syncing ids
          mp = CreateObject("roMessagePort")
          http = CreateObject("roUrlTransfer")
          http.setUrl(url)
          http.SetCertificatesFile("common:/certs/ca-bundle.crt")
          http.setRequest("GET")
          http.setMessagePort(mp)

          ''' make the call
          _adb_logger().debug("ID Service - Sending id sync call (" + url + ")")
          success = http.AsyncGetToString()

          if success = false
            _adb_logger().error("ID Service - Failed to attempt id sync call, url failed to parse")
          end if

          ''' wait for response
          response = wait(500, mp)

          ''' parse response
          responseString = invalid
          if type(response) = "roUrlEvent"
            if response.GetResponseCode() <> 200
              _adb_logger().error("ID Service - Error connecting to service (" + response.GetFailureReason() + ")")
            else
              responseString = response.GetString()
            end if
          end if

          ''' parse json object
          responseObject = invalid
          if responseString <> invalid
            responseObject = ParseJson(responseString)
          end if

          ''' look for identifiers
          if responseObject <> invalid AND responseObject.d_mid <> invalid
            m._mid = responseObject.d_mid

            if responseObject.d_blob <> invalid
              m._blob = responseObject.d_blob
            else
              m._blob = invalid
            end if

            if responseObject.dcs_region <> invalid
              m._hint = responseObject.dcs_region
            else
              m._hint = invalid
            end if

            if responseObject.id_sync_ttl <> invalid
              m._ttl = responseObject.id_sync_ttl.toStr()
            else
              m._ttl = "0"
            end if

          else if m._mid = invalid
            m._mid = m._generateLocalMid()
            m._blob = invalid
            m._hint = invalid
            m._ttl = "600"

            _adb_logger().debug("ID Service - No response from server, generated local mid(" + m._mid + ")")
          end if

          m._lastSync = CreateObject("roDateTime").AsSeconds().toStr()

          ''' persist
          m._saveIfValid("visitor_mid", m._mid)
          m._saveIfValid("visitor_blob", m._blob)
          m._saveIfValid("visitor_hint", m._hint)
          m._saveIfValid("visitor_ttl", m._ttl)
          m._saveIfValid("visitor_sync", m._lastSync)

        End Function,

      ''' getter Function for marketing cloud id
      marketingCloudID: Function () as String
          return m._mid
        End Function,

      analyticsIDRequestParameterString: Function () as String
          if m._mid <> invalid
            return "?mid=" + m._mid + "&mcorgid=" + _adb_config().marketingCloudOrganizationIdentifier
          end if
          return ""
        End Function,

      analyticsParameters: Function () as Object
          responseParameters = {}

          if m._mid <> invalid
            responseParameters["mid"] = m._mid
          else
            return responseParameters
          end if

          if m._blob <> invalid
            responseParameters["aamb"] = m._blob
          end if

          if m._hint <> invalid
            responseParameters["aamlh"] = m._hint
          end if

          return responseParameters
        End Function,
      aamParameters: Function () as String
          response = ""

          if m._mid <> invalid
            response = response + _adb_urlEncoder()._serializeKeyValuePair("d_mid", m._mid)
          else
            return response
          end if

          if m._blob <> invalid
            response = response + _adb_urlEncoder()._serializeKeyValuePair("d_blob", m._blob)
          end if

          if m._hint <> invalid
            response = response + _adb_urlEncoder()._serializeKeyValuePair("dcs_region", m._hint)
          end if

          return response
        End Function
    }

    instance._init()

    GetGlobalAA()["_adb_visitor"] = instance
  end if

  return GetGlobalAA()._adb_visitor
End Function
