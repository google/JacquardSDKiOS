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

import Combine
import XCTest

@testable import JacquardSDK

class JacquardTagInternalTests: XCTestCase {

  struct FakeAdvertisedTag: AdvertisedTag {
    var rssi: Float = -72.0
    var pairingSerialNumber = "FakePairingSerialNumber"
    var identifier = UUID()
  }

  func testDisplayName() {
    let transport = FakeTransport()
    XCTAssertEqual(FakeAdvertisedTag().displayName, FakeAdvertisedTag().pairingSerialNumber)
    XCTAssertEqual(
      FakeConnectedTag(transport: transport).displayName,
      FakeConnectedTag(transport: transport).name
    )
  }
}
