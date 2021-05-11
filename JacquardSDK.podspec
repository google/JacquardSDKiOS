#
# Jacquard iOS SDK
#
# https://atap.google.com/jacquard/
#
# This SDK allows you to connect to your Jacquard jacket or backpack in your own iOS app.
#

Pod::Spec.new do |s|
  s.name             = 'JacquardSDK'
  s.version          = '0.1.0'
  s.summary          = 'This SDK allows you to connect to your Jacquard jacket or backpack in your own iOS app.'
  s.description      = <<-DESC
This SDK allows you to connect to your Jacquard jacket or backpack in your own iOS app.
                       DESC

  s.homepage         = 'https://github.com/google/JacquardSDK'
  # s.screenshots     = 'www.example.com/screenshots_1', 'www.example.com/screenshots_2'
  s.license          = { :type => 'Apache', :file => 'LICENSE' }
  s.author           = { 'Mark Aufflick' => 'maufflick@google.com' }
  s.source           = { :git => 'https://github.com/google/JacquardSDK.git', :tag => s.version.to_s }

  s.swift_version = "5"
  s.ios.deployment_target = '13.0'
  s.osx.deployment_target = '10.15'

  s.default_subspec = 'SDK'

  s.subspec 'SDK' do |sdk|
    sdk.source_files = 'JacquardSDK/Classes/**/*'
    sdk.osx.source_files = 'JacquardSDK/Classes/**/*'
    sdk.frameworks = 'Foundation', 'CoreBluetooth'
    sdk.dependency 'JacquardSDK/Protobuf'
  end

  s.subspec 'Protobuf' do |proto|
    proto.source_files = 'JacquardSDK/Protobuf/*'
    proto.osx.source_files = 'JacquardSDK/Protobuf/*'
    s.dependency 'SwiftProtobuf', '~> 1.0'
  end

  s.resources = 'JacquardSDK/Resources/*'

  s.test_spec 'Tests' do |test_spec|
    test_spec.scheme = {
      :code_coverage => true
    }
    test_spec.source_files = 'Tests/**/*.swift'
  end
end
