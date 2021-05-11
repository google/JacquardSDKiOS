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

import CoreBluetooth
import XCTest

@testable import JacquardSDK

class AdvertisedTagModelTests: XCTestCase {

  private let uuid = UUID(uuidString: "BD415750-8EF1-43EE-8A7F-7EF1E365C35E")!
  private let deviceName = "Fake Device"

  func testInitAdvertisedTagModel() {
    let peripheral = FakePeripheralImplementation(identifier: uuid, name: deviceName)
    let advertisementData =
      [CBAdvertisementDataManufacturerDataKey: Data([224, 0, 0, 32, 12, 63])]
    let advertisedTag =
      AdvertisedTagModel(peripheral: peripheral, advertisementData: advertisementData)

    XCTAssertNotNil(advertisedTag)
    XCTAssertEqual(advertisedTag?.identifier, uuid)
    XCTAssertEqual(advertisedTag?.peripheral.identifier, uuid)
    XCTAssertEqual(advertisedTag?.peripheral.name, deviceName)
  }

  func testInitTagWithoutAdvertisingData() {
    let peripheral = FakePeripheralImplementation(identifier: uuid, name: deviceName)
    let emptyAdvertisementData = [String: Any]()
    let advertisedTag =
      AdvertisedTagModel(peripheral: peripheral, advertisementData: emptyAdvertisementData)
    XCTAssertNil(advertisedTag)
  }

  func testDecodeSerialNumber() {
    let peripheral = FakePeripheralImplementation(identifier: uuid, name: deviceName)
    let serialNumbers = [
      "0023": Data([224, 0, 0, 32, 12, 63]),
      "0086": Data([224, 0, 0, 128, 24, 63]),
    ]
    for (serial, data) in serialNumbers {
      let advertisingData = [CBAdvertisementDataManufacturerDataKey: data]
      let advertisedTag =
        AdvertisedTagModel(peripheral: peripheral, advertisementData: advertisingData)
      XCTAssertEqual(serial, advertisedTag?.pairingSerialNumber)
    }
  }
}
