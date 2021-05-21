Jacquard™ by Google weaves new digital experiences into the things you
love, wear, and use every day to give you the power to do more and be
more.  Jacquard SDK is a way to connect Jacquard interactions within
your apps.  Create an app and bring it to life with swipes and taps
through the Jacquard SDK.

# What do I need to get started?

The iOS Jacquard SDK supports iOS versions 13 and greater.[^1]

[^1]: The [Android Jacquard
    SDK](https://github.com/google/JacquardSDKAndroid) supports
    Android versions 10 and greater.

You will need the Jacquard Tag with a supported Jacquard product (all
come with one tag). Currently supported products are:

* Levi's Trucker Jacket
* Samsonite Konnect-i backpack
* Saint Laurent Cit-e Backpack

You can find links to purchase these products on the [Google Jacquard
website](https://atap.google.com/jacquard/products/).

> If you have just opened a new retail Jacquard product, your tag
> probably needs a firmware update (and perhaps charging). Review the
> steps in the [Updating Firmware](updating-firmware.html) page.

# Join the Jacquard community!

Join the [Jacquard iOS SDK
discussion](https://github.com/google/JacquardSDKiOS/discussions/) on
GitHub.

Learn more about Google Jaquard and sign up for Jacquard updates at
the [Jacquard by Google website](https://atap.google.com/jacquard/).

# Building the Sample App

![Screenshots of sample app](assets/sample-app.jpg)

The sample app allows you to explore the functionality of the SDK and
Jacquard gear. It also serves as a code example of how you can use the
SDK in your own app. The sample app has some dependencies which need
to be installed via CocoaPods. (You can use either CocoaPods or Swift
Package Manager when you integrate with your own app, but CocoaPods is
currently required for building the sample app).

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

# Next Steps

The best way to get started with the Jacquard SDK is to follow our
[tutorial](tutorial.html).

Or, jump straight to [integrating the Jacquard SDK](integration.html)
into your Xcode project.

Once you have completed the tutorial, the best place to go next is the
[API Overview](api-overview.html) which will explain the features of
your Jacquard tag and gear, and how to use the API. After that, check
out the API Documentation (available in the table of contents on the
left of every page) and build your awesome app :)
