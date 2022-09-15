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

class SetCustomConfigCommandTests: XCTestCase {

  struct CatchLogger: Logger {
    func log(
      level: LogLevel, file: StaticString, line: UInt, function: String, message: () -> String
    ) {
      let _ = message()
      if level == .assertion {
        expectation.fulfill()
      }
    }

    var expectation: XCTestExpectation
  }

  override func setUp() {
    super.setUp()

    let logger = PrintLogger(
      logLevels: [.debug, .info, .warning, .error, .assertion],
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

  func testRequestCreation() {
    let expectedDomain: Google_Jacquard_Protocol_Domain = .base
    let expectedOpcode: Google_Jacquard_Protocol_Opcode = .configSet
    let expectedKey = "Test"
    let expectedVendorID = "11-78-30-c8"
    let expectedProductID = "28-3b-e7-a0"

    // Compose the request.
    let setConfigRequest = SetCustomConfigCommand(
      config: DeviceConfigElement(
        vendorID: expectedVendorID,
        productID: expectedProductID,
        key: expectedKey,
        value: .string("test value")
      )
    )

    guard let request = setConfigRequest.request as? Google_Jacquard_Protocol_Request else {
      XCTFail("Unexpected type for the set custom config request.")
      return
    }

    // Validate the request.
    XCTAssertEqual(request.domain, expectedDomain, "Set custom config request has wrong domain.")
    XCTAssertEqual(request.opcode, expectedOpcode, "Set custom config has wrong opcode.")
    XCTAssert(request.hasGoogle_Jacquard_Protocol_ConfigSetRequest_configSetRequest)
    let setCustomConfigRequest = request.Google_Jacquard_Protocol_ConfigSetRequest_configSetRequest
    XCTAssertEqual(
      setCustomConfigRequest.vid,
      ComponentImplementation.convertToDecimal(expectedVendorID),
      "Received wrong vendorID for set custom config command.")
    XCTAssertEqual(
      setCustomConfigRequest.pid,
      ComponentImplementation.convertToDecimal(expectedProductID),
      "Received wrong productID for set custom config command.")
    XCTAssertEqual(
      setCustomConfigRequest.config.key,
      expectedKey,
      "Received wrong key for set custom config command.")
    XCTAssertEqual(
      setCustomConfigRequest.config.stringVal,
      "test value",
      "Received wrong value of the config for set custom config command.")
  }

  func testGoodResponse() {
    let goodResponseExpectation = expectation(description: "goodResponseExpectation")

    let setConfigRequest = SetCustomConfigCommand(
      config: DeviceConfigElement(
        vendorID: "11-78-30-c8",
        productID: "28-3b-e7-a0",
        key: "Test",
        value: .string("test value")
      )
    )
    let goodResponse = Google_Jacquard_Protocol_Response()
    setConfigRequest.parseResponse(outerProto: goodResponse).assertSuccess { _ in
      goodResponseExpectation.fulfill()
    }

    wait(for: [goodResponseExpectation], timeout: 0.5)
  }

  /// Proto payload is Any type, so we need to ensure a bad payload is safely ignored.
  func testBadResponse() {
    let badResponseExpectation = expectation(description: "badResponseExpectation")

    jqLogger = CatchLogger(expectation: badResponseExpectation)

    let setConfigRequest = SetCustomConfigCommand(
      config: DeviceConfigElement(
        vendorID: "11-78-30-c8",
        productID: "28-3b-e7-a0",
        key: "Test",
        value: .string("test value")
      )
    )
    let badResponse = Google_Jacquard_Protocol_Color()
    setConfigRequest.parseResponse(outerProto: badResponse).assertFailure()

    wait(for: [badResponseExpectation], timeout: 0.5)
  }
}
