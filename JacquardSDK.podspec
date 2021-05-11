#
# Jacquard iOS SDK
#
# https://atap.google.com/jacquard/
#
# This SDK allows you to connect to your Jacquard product from your own iOS app.
#

Pod::Spec.new do |s|
  s.name             = 'JacquardSDK'
  s.version          = '0.1.0'
  s.summary          = 'This SDK allows you to connect to your Jacquard product from your own iOS app.'
  s.description      = <<-DESC
Jacquard by Google weaves new digital experiences into the things you love, wear, and use every day to give you
the power to do more and be more. Jacquard SDK is a way to connect Jacquard interactions within your apps.
Create an app and bring it to life with gestures, haptics and more through the Jacquard SDK.
                       DESC

  s.homepage         = 'https://google.github.io/JacquardSDKiOS'
  s.license          = { :type => 'Jacquard Software Development Kit License Agreement', :file => 'LICENSE.md' }
  s.author           = { 'Mark Aufflick' => 'maufflick@google.com' }
  s.source           = { :http => 'https://github.com/google/JacquardSDKiOS/releases/download/v0.1.0/jacquard-sdk-0.1.0-xcframework.zip' }

  s.swift_version = "5"
  s.platform = :ios
  s.ios.deployment_target = '13.0'
  s.ios.vendored_frameworks = 'JacquardSDK.xcframework'
  s.ios.frameworks = 'Foundation', 'CoreBluetooth'
  s.dependency 'SwiftProtobuf', '~> 1.0'
end
