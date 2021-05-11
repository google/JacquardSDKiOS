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

import XCTest

@testable import JacquardSDK

final class GearInternalTests: XCTestCase {

  struct CatchLogger: Logger {
    func log(level: LogLevel, file: String, line: Int, function: String, message: () -> String) {
      let _ = message()
      if level == .assertion || level == .preconditionFailure {
        expectation.fulfill()
      }
    }

    var expectation: XCTestExpectation
  }

  override func setUp() {
    super.setUp()

    let logger = PrintLogger(
      logLevels: [.debug, .info, .warning, .error, .assertion, .preconditionFailure],
      includeSourceDetails: true
    )
    setGlobalJacquardSDKLogger(logger)
  }

  override func tearDown() {
    // Other tests may run in the same process. Ensure that any fake logger fulfillment doesn't
    // cause any assertions later.
    JacquardSDK.setGlobalJacquardSDKLogger(JacquardSDK.createDefaultLogger())

    super.tearDown()
  }

  func testVerifyGearCapabilitiesForYSL() {
    let capabilities = GearCapabilities.gearData(
      vendorID: "fb-57-a1-12",
      productID: "5c-d8-78-b0"
    ).product.capabilities

    // Capabilities for YSL should be 4.
    XCTAssertEqual(capabilities.count, 4)
    XCTAssert(capabilities[0] == .led)
    XCTAssert(capabilities[1] == .gesture)
    XCTAssert(capabilities[2] == .touchDataStream)
    XCTAssert(capabilities[3] == .haptic)
  }

  func testVerifyGearCapabilitiesForLevis() {
    let capabilities = GearCapabilities.gearData(
      vendorID: "74-a8-ce-54",
      productID: "8a-66-50-f4"
    ).product.capabilities

    // Capabilities for Levi's should be 3.
    XCTAssertEqual(capabilities.count, 3)
    XCTAssert(capabilities[0] == .gesture)
    XCTAssert(capabilities[1] == .touchDataStream)
    XCTAssert(capabilities[2] == .haptic)
  }

  func testVerifyGearCapabilitiesForUnknownVendor() {
    let gearCapabilitiesForUnknownVendorExpectation = expectation(
      description: "GearCapabilitiesForUnknownVendorExpectation"
    )
    jqLogger = CatchLogger(expectation: gearCapabilitiesForUnknownVendorExpectation)

    let capabilities = GearCapabilities.gearData(
      vendorID: "74-a8-ce-67",
      productID: "8a-66-50-f4"
    ).product.capabilities

    // Capabilities for unknown vendor should be 0.
    XCTAssertEqual(capabilities.count, 0)

    wait(for: [gearCapabilitiesForUnknownVendorExpectation], timeout: 1.0)
  }

  func testVerifyGearData() {
    let gearData = GearCapabilities.gearData(vendorID: "fb-57-a1-12", productID: "5c-d8-78-b0")
    XCTAssertEqual(gearData.vendor.id, "fb-57-a1-12")
    XCTAssertEqual(gearData.vendor.name, "Saint Laurent")

    XCTAssertEqual(gearData.product.id, "5c-d8-78-b0")
    XCTAssertEqual(gearData.product.name, "Cit-e Backpack")
    XCTAssertEqual(gearData.product.capabilities.count, 4)
    XCTAssert(gearData.product.capabilities[0] == .led)
    XCTAssert(gearData.product.capabilities[1] == .gesture)
    XCTAssert(gearData.product.capabilities[2] == .touchDataStream)
    XCTAssert(gearData.product.capabilities[3] == .haptic)
  }

  func testVerifyGearDataForUnknownProduct() {
    let gearDataForUnknownVendorExpectation = expectation(
      description: "gearDataForUnknownVendorExpectation"
    )
    jqLogger = CatchLogger(expectation: gearDataForUnknownVendorExpectation)

    let gearData = GearCapabilities.gearData(vendorID: "fb-57-a1-13", productID: "5c-d8-78-b0")

    // Data should be blank for unknown vendor.
    XCTAssertEqual(gearData.vendor.id, "")
    XCTAssertEqual(gearData.product.id, "")
    XCTAssertEqual(gearData.product.capabilities.count, 0)

    wait(for: [gearDataForUnknownVendorExpectation], timeout: 1.0)
  }
}
