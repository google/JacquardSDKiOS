# Jacquard Cloud APIs

* The firmware updating portions of the Jacquard SDK rely on access to
  Jacquard Cloud APIs to list and fetch firmware updates for Jacquard
  tags.
* To enable this access, the SDK requires an API Key.
* Use of the Jacquard Cloud API requires agreeing to the below Terms
  of Service.
* The Jacquard Cloud API is designed to be used only via the
  Jacquard SDK and your app code should not access it directly.
* Once you have read and agreed to the Terms of Service, click the
  checkbox below to obtain a temporary API key suitable for testing,
  exploration and/or other such preliminary uses.

<h1 
  id="terms-of-service-for-use-of-the-jacquard-cloud-api-for-use-with-software-development-kit-the-jacquard-sdk-span-class-footnote-ref-id-fnref4-sup-a-href-fn4-1-a-sup-span"
  class="heading"
  style="line-height: 44px;">
  Terms of Service for Use of the Jacquard Cloud API for Use with Software Development Kit (the “Jacquard SDK”)
  <span class="footnote-ref" id="fnref4"><sup><a href="#fn4">1</a></sup></span>
</h1>

**By using the Jacquard Cloud API (and accepting a Google API key), you
agree that your use of Jacquard Cloud API (along with the Google API
key) is governed by the Terms of Service herein.**

### 1. Explanatory Notes – Jacquard SDK, Google API Key & the Jacquard Cloud API.

As background, please note:

<ol type="i">

<li> The portion of the Jacquard SDK that enables firmware updates
     relies on access to the Jacquard Cloud API to list and fetch firmware
     updates to Jacquard Tags.
<li> In order to access the firmware updates to the Jacquard SDK, the
     Jacquard SDK requires you to provide a Google API key to access all of
     the relevant Jacquard Cloud API functions;
<li> The Jacquard Cloud API is designed to, and may only, be used with
     the Jacquard SDK and your app code may not access it directly;
<li> The Jacquard Cloud API is currently a developer preview version
     and can be used for testing, exploration and/or other such preliminary
     uses; and
<li> For purposes of clarity, the API ToS refers solely to the
     Jacquard Cloud API and Google API key, and your access and specific
     use of the Jacquard SDK is governed by a separate license agreement.
</ol>

### 2. Terms of Service of the Jacquard Cloud API.

By downloading, receiving and/or using the Jacquard Cloud API
(including the Google API key), you agree to, and consent to be bound
by, the Google APIs Terms of Service ("API ToS" aka “Terms” as stated
in the API ToS) located at:
https://console.cloud.google.com/tos?id=universal.  In addition, you
acknowledge and agree to comply with the following “additional terms”
(as further defined in the API ToS) apply to your use of the Jacquard
Cloud API (and the Google API key):

<ol type="a">
<li> To only use the Google API key to access and use the Jacquard
     Cloud API in accordance with the API ToS;
<li> Not use the Google API key to ship a final product/app;
<li> The Google API key that you are receiving now is a temporary API
     key, and in the future, a process may become available to obtain a
     production-use API key and this process will most likely require
     registration;
<li> That your use of the API key may be extinguished and/or revoked
     by Google at any time in Google’s sole discretion without liability to
     you or any third party; and
<li> To only use the API key and Jacquard Cloud API with the Jacquard
     SDK.
</ol>

## API Key

<label><input type="checkbox" name="apiKeyCheckbox" value="Agree">In
order to obtain your temporary API key, please “click” this box to
indicate that you acknowledge and agree & consent to these Terms of
Service for Use of the Jacquard Cloud API for Use with Software
Development Kit (the “Jacquard SDK”).</label>

<div id="temporaryAPIKey" style="display: none;">
<h3>Temporary API Key</h3>
<pre>%TEMPORARY_API_KEY%</pre>
</div>

<script>
window.onload = function(){
  $('input[type="checkbox"]').click(function(){
    $("#temporaryAPIKey").show();
    $(this).attr("disabled", true);
  });
};
</script>

<div class="footnotes">
<hr>
<ol>

<li><div class="footnote-def" id="fn4"><p>If you signed an offline agreement with Google for use the
Jacquard Cloud API, then, the terms below do not apply to your use
of Jacquard Cloud API, and your offline terms govern your use of
the Jacquard Cloud API.&nbsp;<a href="#fnref4">↩</a></p></div></li><p></p>

</ol>
</div>
