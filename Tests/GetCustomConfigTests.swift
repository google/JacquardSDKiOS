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

class GetCustomConfigCommandTests: XCTestCase {

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
    let expectedOpcode: Google_Jacquard_Protocol_Opcode = .configGet
    let expectedKey = "Test"
    let expectedVendorID: String = "11-78-30-c8"
    let expectedProductID: String = "28-3b-e7-a0"

    // Compose the request.
    let getConfigRequest = GetCustomConfigCommand(
      vendorID: expectedVendorID,
      productID: expectedProductID,
      key: expectedKey
    )

    guard let request = getConfigRequest.request as? Google_Jacquard_Protocol_Request else {
      XCTFail("Unexpected type for the get custom config request.")
      return
    }

    // Validate the request.
    XCTAssertEqual(request.domain, expectedDomain, "Get custom config request has wrong domain.")
    XCTAssertEqual(request.opcode, expectedOpcode, "Get custom config has wrong opcode.")
    XCTAssert(request.hasGoogle_Jacquard_Protocol_ConfigGetRequest_configGetRequest)
    let getCustomConfigRequest = request.Google_Jacquard_Protocol_ConfigGetRequest_configGetRequest
    XCTAssertEqual(
      getCustomConfigRequest.vid.hexString(),
      expectedVendorID,
      "Received wrong vendorID for get custom config command.")
    XCTAssertEqual(
      getCustomConfigRequest.pid.hexString(),
      expectedProductID,
      "Received wrong productID for get custom config command.")
    XCTAssertEqual(
      getCustomConfigRequest.key,
      expectedKey,
      "Received wrong key for get custom config command.")
  }

  func testGoodResponse() {
    let goodResponseExpectation = expectation(description: "goodResponseExpectation")

    let getConfigRequest = GetCustomConfigCommand(
      vendorID: "11-78-30-c8",
      productID: "28-3b-e7-a0",
      key: "Test"
    )
    let goodResponse = Google_Jacquard_Protocol_Response.with {
      let config = Google_Jacquard_Protocol_ConfigGetResponse.with {
        $0.config.stringVal = "test value"
      }
      $0.Google_Jacquard_Protocol_ConfigGetResponse_configGetResponse = config
    }
    getConfigRequest.parseResponse(outerProto: goodResponse).assertSuccess { _ in
      goodResponseExpectation.fulfill()
    }

    wait(for: [goodResponseExpectation], timeout: 0.5)
  }

  func testMalformedResponse() {
    let malformedResponseExpectation = expectation(description: "malformedResponseExpectation")

    let getConfigRequest = GetCustomConfigCommand(
      vendorID: "11-78-30-c8",
      productID: "28-3b-e7-a0",
      key: "Test"
    )
    let malformedResponse = Google_Jacquard_Protocol_Response.with {
      // Providing wrong response(config write command response).
      let config = Google_Jacquard_Protocol_BleConfiguration()
      let ujtConfigResponse = Google_Jacquard_Protocol_UJTConfigResponse.with {
        $0.bleConfig = config
      }
      $0.Google_Jacquard_Protocol_UJTConfigResponse_configResponse = ujtConfigResponse
    }
    getConfigRequest.parseResponse(outerProto: malformedResponse).assertFailure { _ in
      malformedResponseExpectation.fulfill()
    }

    wait(for: [malformedResponseExpectation], timeout: 0.5)
  }

  /// Proto payload is Any type, so we need to ensure a bad payload is safely ignored.
  func testBadResponse() {
    let badResponseExpectation = expectation(description: "badResponseExpectation")

    jqLogger = CatchLogger(expectation: badResponseExpectation)

    let getConfigRequest = GetCustomConfigCommand(
      vendorID: "11-78-30-c8",
      productID: "28-3b-e7-a0",
      key: "Test"
    )
    let badResponse = Google_Jacquard_Protocol_Color()
    getConfigRequest.parseResponse(outerProto: badResponse).assertFailure()

    wait(for: [badResponseExpectation], timeout: 0.5)
  }
}
