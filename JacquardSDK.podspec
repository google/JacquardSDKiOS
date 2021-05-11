#
# Jacquard iOS SDK
#
# https://atap.google.com/jacquard/
#
# This SDK allows you to connect to your Jacquard jacket or backpack in your own iOS app.
#

Pod::Spec.new do |s|
  s.name             = 'JacquardSDK'
  s.version          = '0.2.0'
  s.summary          = 'This SDK allows you to connect to your Jacquard jacket or backpack in your own iOS app.'
  s.description      = <<-DESC
Jacquard by Google weaves new digital experiences into the things you love, wear, and use every day to give you
the power to do more and be more. Jacquard SDK is a way to connect Jacquard interactions within your apps.
Create an app and bring it to life with gestures, haptics and more through the Jacquard SDK.
                       DESC

  s.homepage         = 'https://google.github.io/JacquardSDKiOS'
  s.license          = { :type => 'Apache', :file => 'LICENSE' }
  s.author           = { 'Mark Aufflick' => 'maufflick@google.com' }
  s.source           = { :git => 'https://github.com/google/JacquardSDKiOS.git', :tag => s.version.to_s }

  s.swift_version = "5"
  s.ios.deployment_target = '13.0'

  s.default_subspec = 'SDK'

  s.subspec 'SDK' do |sdk|
    sdk.source_files = 'JacquardSDK/Classes/**/*'
    sdk.frameworks = 'Foundation', 'CoreBluetooth'
    sdk.dependency 'JacquardSDK/Protobuf'
  end

  s.subspec 'Protobuf' do |proto|
    proto.source_files = 'JacquardSDK/Protobuf/*'
    s.dependency 'SwiftProtobuf', '~> 1.0'
  end

  s.resources = 'JacquardSDK/Resources/*'

  s.test_spec 'Tests' do |test_spec|
    test_spec.scheme = {
      :code_coverage => true
    }
    test_spec.source_files = 'Tests/**/*.swift'
    test_spec.resources = 'Tests/TestResources/*'
  end
end
