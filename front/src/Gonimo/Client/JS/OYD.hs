{-# LANGUAGE CPP   #-}
{-# LANGUAGE GADTs #-}
module Gonimo.Client.JS.OYD where


import           GHCJS.DOM.MediaStream       as MediaStream
import qualified Language.Javascript.JSaddle as JS
-- import GHCJS.DOM.AudioContext             as Ctx
-- import GHCJS.DOM.GainNode             as GainNode
-- import GHCJS.DOM.AudioParam             as AudioParam
import qualified Data.Text                   as T

import           Gonimo.Client.Prelude





-- | TODO: We should check for a stream with no audio track here too!
oyd :: (MonadJSM m) => Text -> MediaStream -> m (Text -> m ())
oyd babyName stream = liftJSM $ do
  jsOYD <- JS.eval . T.unlines $
           [ "(function (babyName, stream) {"
           , "    function getValues(oyd, stream, context) {"
           , "        try {"
           , "            var source = context.createMediaStreamSource(stream);"
           , "            var script = context.createScriptProcessor(2048, 1, 1);"
           , "            source.connect(script);"
           , "            script.connect(context.destination);"
           , "            var currentMax =0;"
           , ""
           , "            function sendAndReset() {"
           , "                if (currentMax > oyd.threshold) {"
           , "                    try {"
           , "                         oyd.sendValue(oyd, babyName, currentMax);"
           , "                    }"
           , "                    catch(e) {"
           , "                        console.log(e.stack);"
           , "                    }"
           , "                }"
           , "                currentMax = 0;"
           , "            }"
           , "            var timer = setInterval(sendAndReset, oyd.interval);"
           , ""
           , "            var audioTracks = stream.getAudioTracks();"
           , "            var u =0;"
           , "            function closeOYD() {"
           , "                try {"
           , "                    source.disconnect();"
           , "                    script.disconnect();"
           , "                    clearInterval(timer);"
           , "                }"
           , "                catch(e) {"
           , "                    console.log(e.stack);"
           , "                    try { clearInterval(timer); } catch(e) {}"
           , "                }"
           , "            }"
           , "            for (; u< audioTracks.length; ++u) {"
           , "                audioTracks[u].addEventListener('ended', closeOYD, false);"
           , "            }"
           , ""
           , "            script.onaudioprocess = function(event) {"
           , "                try {"
           , "                    var input = event.inputBuffer.getChannelData(0);"
           , "                    var i;"
           , "                    var sum = 0.0;"
           , "                    for (i = 0; i < input.length; ++i) {"
           , "                        sum += input[i] * input[i];"
           , "                    }"
           , ""
           , "                    var instant = Math.sqrt(sum / input.length);"
           , "                    if (instant > currentMax) {"
           , "                        currentMax = instant;"
           , "                    }"
           , "                } catch (e) {"
           , "                    console.log(e.stack);"
           , "                }"
           , ""
           , "            };"
           , "        } "
           , "        catch(e) {"
           , "            console.log(e.stack);"
           , "        }"
           , "    }"
           , ""
           , "    function sendValue (oyd, babyName, val) {"
           , "      var pia_url = oyd.piaURL;"
           , "      var app_key = 'eu.ownyourdata.gonimo';"
           , "      var app_secret = oyd.appSecret;"
           , "      var repo = app_key;"
           , "      var request = new XMLHttpRequest();"
           , "      request.open('POST', pia_url + '/oauth/token?' + "
           , "                   'grant_type=client_credentials&' + "
           , "                   'client_id=' + app_key + '&' +"
           , "                   'client_secret=' + app_secret, true);"
           , "      request.send('');"
           , "      request.onreadystatechange = function () {"
           , "        if (request.readyState == 4) {"
           , "          var token = JSON.parse(request.responseText).access_token;"
           , "          var req2 = new XMLHttpRequest();"
           , "          req2.open('POST', pia_url + '/api/repos/' + repo + '/items', true);"
           , "          req2.setRequestHeader('Accept', '*/*');"
           , "          req2.setRequestHeader('Content-Type', 'application/json');"
           , "          req2.setRequestHeader('Authorization', 'Bearer ' + token);"
           , "          var data = JSON.stringify({volume: val,"
           , "                                     name: babyName, "
           , "                                     time: Date.now(), "
           , "                                     _oydRepoName: 'Gonimo'});"
           , "          req2.send(data);"
           , "        }"
           , "      }"
           , "    }"
           , ""
           , "    function setDefaultValues(oyd) {"
           , "        if(typeof oyd.interval  === 'undefined')"
           , "            oyd.interval = 2000;"
           , "        if(typeof oyd.threshold === 'undefined')"
           , "            oyd.threshold = 0.00;"
           -- , "        if(typeof oyd.sendValue === 'undefined') // Just for testing:"
           -- , "            oyd.sendValue = '(function (oyd, value) {console.log(\"Sending to oyd: \" + value.toString());})';"
           , "    }"
           , ""
           , "    var setBabyNameCallBack = function (newName) {"
           , "        babyName = newName;"
           , "    }"
           , "    try {"
           , "        var oyd = JSON.parse(localStorage.getItem('OYD'));"
           , "        if (oyd == null || typeof oyd.appSecret === 'undefined' || typeof oyd.piaURL === 'undefined')"
           , "            return function () {};"
           , "        if (typeof gonimoAudioContext === 'undefined') {gonimoAudioContext = new AudioContext();}"
           , "        var audioCtx = gonimoAudioContext;"
           , "        setDefaultValues(oyd);"
           -- , "        oyd.sendValue = eval(oyd.sendValue);"
           , "        oyd.sendValue = sendValue;"
           , "        getValues(oyd,stream,audioCtx);"
           , "        return setBabyNameCallBack"
           , "    }"
           , "    catch(e) {"
           , "        console.log(e.stack);"
           , "        return function () {};"
           , "    }"
           , "})"
           ]
  jsSetName <- JS.call jsOYD JS.obj (babyName, stream)
  pure (liftJSM . void . JS.call jsSetName JS.obj . (:[]))
