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
    .macOS(.v10_15),
  ],
  products: [
    .library(
      name: "JacquardSDK",
      targets: ["JacquardSDK"])
  ],
  dependencies: [
    .package(
      name: "SwiftProtobuf",
      url: "https://github.com/apple/swift-protobuf.git",
      from: "1.16.0"),
    .package(url: "https://github.com/typelift/SwiftCheck.git", from: "0.12.0")
  ],
  targets: [
    .target(
      name: "JacquardSDK",
      dependencies: ["SwiftProtobuf"],
      path: "JacquardSDK",
      resources: [
        .copy("Resources/GearMetadata.json"),
        .copy("Resources/BadFirmwareVersion.json")
      ]
    ),
    .testTarget(
      name: "JacquardSDKTests",
      dependencies: [
        "JacquardSDK",
        "SwiftCheck",
      ],
      path: "Tests",
      resources: [
        .copy("TestResources/imu1.bin"),
        .copy("TestResources/imu2.bin")
      ]),
  ],
  swiftLanguageVersions: [.v5]
)
