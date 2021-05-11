Jacquard™ by Google weaves new digital experiences into the things you
love, wear, and use every day to give you the power to do more and be
more.  Jacquard SDK is a way to connect Jacquard interactions within
your apps.  Create an app and bring it to life with swipes and taps
through the Jacquard SDK.


# What are the system requirements?

The iOS Jacquard SDK supports iOS version 13 and greater.[^1]

[^1]: The [Android Jacquard
    SDK](https://github.com/google/JacquardSDKAndroid) supports
    Android version 10 and higher.
    
# What do I need to get started?

You will need the Jacquard Tag with a supported Jacquard product. Each
product comes with one tag.

Supported products include:

* Levi's Trucker Jacket
* Samsonite Konnect-i Backpack
* Saint Laurent Cit-e Backpack

You will find links to purchase these products on the [Google Jacquard
website](https://atap.google.com/jacquard/products/).

>Tags that come with your store bought Jacquard product will need a
>firmware update. Please review the steps on the [Updating
>Firmware](updating-firmware.html) page.

# Join the Jacquard community!

Join the [Jacquard iOS SDK
discussion](https://github.com/google/JacquardSDKiOS/discussions/) on
GitHub.

Learn more about Jaquard and sign up for Jacquard updates at
the [Jacquard by Google website](https://atap.google.com/jacquard/).

# Building the Jacquard SDK Sample App

![Screenshots of sample app](assets/sample-app.jpg)

The sample app allows you to explore the functionality of the SDK and
your Jacquard product. It also serves as a code example of how you can use the
SDK in your own app. Note: The sample app has some dependencies which need
to be installed via CocoaPods.

```
git clone https://github.com/google/JacquardSDKiOS.git
cd JacquardSDKiOS/Example
pod install
open JacquardSDK.xcworkspace
```

Be sure to open the `.xcworkspace`, not the `.xcodeproj`. If you are
unfamiliar with CocoaPods or do not have the `pod` command installed,
visit [cocoapods.org](https://cocoapods.org/).

The app needs to run on a physical device to connect to the tag via
Bluetooth. This requires you to set code signing portion of the Xcode
project to use your own developer certificate. You can obtain a
certificate from Apple via either of the free or paid Apple Developer
programs. See [developer.apple.com](https://developer.apple.com/) and
[developer.apple.com/support/compare-memberships](https://developer.apple.com/support/compare-memberships/)
for more information.

# Next steps

The best way to get started with the Jacquard SDK is to follow our
[tutorial](tutorial.html).

Or, go straight to [integrating the Jacquard SDK](Integration.html)
in your Xcode project.

Once you complete the tutorial, go to [API
Overview](api-overview.html), which will explain the features of
your Jacquard tag and gear, as well as how to use the API. After that,
check out the API Documentation (available in the table of contents on
the left of every page) and build that awesome app!
