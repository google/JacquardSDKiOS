// swift-tools-version:5.4
//
// Copyright 2021 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import PackageDescription

let package = Package(
  name: "JacquardSDK",
  platforms: [
    .iOS(.v13),
  ],
  products: [
    .library(
      name: "JacquardSDK",
      targets: ["JacquardSDK"]),
    .library(
      name: "JacquardSDKCore",
      targets: ["JacquardSDKCore"]),
  ],
  dependencies: [
    .package(
      name: "SwiftProtobuf",
      url: "https://github.com/apple/swift-protobuf.git",
      from: "1.16.0")
  ],
  targets: [
    .target(
      name: "JacquardSDKCore",
      dependencies: [
        "JacquardSDK",
        "SwiftProtobuf",
      ]
    ),
    .binaryTarget(
      name: "JacquardSDK",
      url: "https://github.com/google/JacquardSDKiOS/releases/download/v0.1.0/jacquard-sdk-0.1.0-xcframework.zip",
      checksum: "6df09d335f73d916c645c648e690eff5081e3a548d3eb29eb4008005bd0f1d40"
    ),
  ],
  swiftLanguageVersions: [.v5]
)
