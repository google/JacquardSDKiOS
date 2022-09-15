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

class ComponentInfoCommandTests: XCTestCase {

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
    let expectedComponentID: UInt32 = 0
    let expectedDomain = Google_Jacquard_Protocol_Domain.base
    let expectedOpcode = Google_Jacquard_Protocol_Opcode.deviceinfo

    // Compose the request.
    let componentInfoCommandRequest = ComponentInfoCommand(componentID: expectedComponentID)

    guard let request = componentInfoCommandRequest.request as? Google_Jacquard_Protocol_Request
    else {
      XCTFail("Unexpected type for the request.")
      return
    }

    // Validate the request.
    XCTAssertEqual(request.domain, expectedDomain, "Device info request has wrong domain.")
    XCTAssertEqual(request.opcode, expectedOpcode, "Device info request has wrong opcode.")
    XCTAssertEqual(
      request.componentID, expectedComponentID, "Device info request has wrong componentID.")
    XCTAssert(request.hasGoogle_Jacquard_Protocol_DeviceInfoRequest_deviceInfo)
    let infoRequest = request.Google_Jacquard_Protocol_DeviceInfoRequest_deviceInfo
    XCTAssertEqual(
      infoRequest.component, expectedComponentID, "Wrong component set for device info request.")
  }

  func testGoodResponse() {
    let goodResponseExpectation = expectation(description: "goodResponseExpectation")

    let componentInfoCommandRequest = ComponentInfoCommand(componentID: 0)
    let goodProto = Google_Jacquard_Protocol_Response.with {
      let deviceInfo = Google_Jacquard_Protocol_DeviceInfoResponse.with {
        $0.firmwareMajor = 1
        $0.firmwareMinor = 96
        $0.firmwarePoint = 0
      }
      $0.Google_Jacquard_Protocol_DeviceInfoResponse_deviceInfo = deviceInfo
    }
    componentInfoCommandRequest.parseResponse(outerProto: goodProto).assertSuccess { _ in
      goodResponseExpectation.fulfill()
    }

    wait(for: [goodResponseExpectation], timeout: 0.5)
  }

  func testMalformedResponse() {
    let malformedResponseExpectation = expectation(description: "malformedResponseExpectation")

    let componentInfoCommandRequest = ComponentInfoCommand(componentID: 0)
    let malformedResponse = Google_Jacquard_Protocol_Response.with {
      // Providing wrong response(config write command response).
      let config = Google_Jacquard_Protocol_BleConfiguration()
      let ujtConfigResponse = Google_Jacquard_Protocol_UJTConfigResponse.with {
        $0.bleConfig = config
      }
      $0.Google_Jacquard_Protocol_UJTConfigResponse_configResponse = ujtConfigResponse
    }
    componentInfoCommandRequest.parseResponse(outerProto: malformedResponse).assertFailure { _ in
      malformedResponseExpectation.fulfill()
    }

    wait(for: [malformedResponseExpectation], timeout: 0.5)
  }

  /// Proto payload is Any type, so we need to ensure a bad payload is safely ignored.
  func testBadResponse() {
    let badResponseExpectation = expectation(description: "badResponseExpectation")

    jqLogger = CatchLogger(expectation: badResponseExpectation)
    let componentInfoCommandRequest = ComponentInfoCommand(componentID: 0)
    let badResponse = Google_Jacquard_Protocol_Color()
    componentInfoCommandRequest.parseResponse(outerProto: badResponse).assertFailure()

    wait(for: [badResponseExpectation], timeout: 0.5)
  }
}
