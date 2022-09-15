# Jacquard iOS SDK

Jacquard™ by Google weaves new digital experiences into the things you
love, wear, and use every day to give you the power to do more and be
more.  Jacquard SDK is a way to connect Jacquard interactions within
your apps.  Create an app and bring it to life with swipes and taps
through the Jacquard SDK.

# What do I need to get started?

The iOS Jacquard SDK supports iOS versions 13 and greater.

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

## Sample App

To run the example project, clone the repo, and run `pod install` from
the Example directory first. For more detailed instructions, see the
full documentation at https://google.github.io/JacquardSDKiOS

## Documentation & Tutorial

Full documentation including a tutorial is available at
https://google.github.io/JacquardSDKiOS

## Android SDK

There is an Android equivalent to this SDK available at
https://github.com/google/JacquardSDKAndroid



# Integrate JacquardSDK into your Xcode project

## CocoaPods

JacquardSDK can be integrated into your code using
[CocoaPods](https://cocoapods.org) dependency management. This early
release version has not yet been added to the CocoaPods directory, the
best way to integrate it is using a git url. Simply add the following
line to your `Podfile`:

```ruby
pod 'JacquardSDK'
```

## Swift Package Manager - with Xcode project

If you are using the Swift Package Manager with an Xcode project file,
for xcode 13, navigate to your project settings, where you will see a new menu called Package Dependencies.
Click the + button to add JacquardSDK package.

Enter the repository URL
`https://github.com/google/JacquardSDKiOS.git`.

As soon as you enter the URL, xcode will find the `JacquardSDKiOS` package, 
for the dependancy rule, use the default values : "Up to Next Major Version" and again click `Add Package`.

Check the `JacquardSDK` Library and click `Add Package`.

Xcode will now download all the relevant files and integrate them into your project.

## Swift Package Manager - with Package.swift

If you are using the Swift Package Manager with a `Package.swift`
file, you need to add a dependency to your and import the
`JacquardSDK` library into the desired targets.

```swift
dependencies: [
    .package(name: "JacquardSDK", url: "https://github.com/google/JacquardSDKiOS.git", from: "0.2.0"),
],
targets: [
    .target(name: "MyTarget", dependencies: ["JacquardSDK"]),
]
```

## Copyright

Copyright 2021 Google LLC

## License

JacquardSDK is licensed under the Apache License, Version 2.0.
See the LICENSE file for more info.
