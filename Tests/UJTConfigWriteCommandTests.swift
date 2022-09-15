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

class UJTConfigWriteCommandTests: XCTestCase {

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

  func testRequestCreation() {
    let expectedDeviceName = "New device name"
    var config = Google_Jacquard_Protocol_BleConfiguration()
    config.customAdvName = expectedDeviceName
    let configWriteRequest = UJTConfigWriteCommand(config: config)

    guard let request = configWriteRequest.request as? Google_Jacquard_Protocol_Request else {
      XCTFail("Unexpected type returned from .request")
      return
    }
    XCTAssertEqual(request.domain, .base)
    XCTAssertEqual(request.opcode, .configWrite)
    XCTAssert(request.hasGoogle_Jacquard_Protocol_UJTConfigWriteRequest_configWrite)

    let bleConfigRequest = request.Google_Jacquard_Protocol_UJTConfigWriteRequest_configWrite
    XCTAssert(bleConfigRequest.hasBleConfig)
    XCTAssertEqual(bleConfigRequest.bleConfig.customAdvName, expectedDeviceName)
  }

  func testGoodResponseProtoContents() {
    let goodProtoExpectation = expectation(description: "Good Proto")

    var config = Google_Jacquard_Protocol_BleConfiguration()
    config.customAdvName = "New device name"
    let configWriteRequest = UJTConfigWriteCommand(config: config)

    let goodProto = Google_Jacquard_Protocol_Response.with {
      let ujtConfig = Google_Jacquard_Protocol_UJTConfigResponse.with {
        $0.bleConfig = config
      }
      $0.Google_Jacquard_Protocol_UJTConfigResponse_configResponse = ujtConfig
    }

    configWriteRequest.parseResponse(outerProto: goodProto).assertSuccess { result in
      goodProtoExpectation.fulfill()
    }

    wait(for: [goodProtoExpectation], timeout: 1.0)
  }

  /// Proto payload is Any type, so we need to ensure a bad payload is safely ignored.
  func testBadResponseProtoContents() {
    let badProtoExpectation = expectation(description: "Bad proto")

    var config = Google_Jacquard_Protocol_BleConfiguration()
    config.customAdvName = "New device name"
    let configWriteRequest = UJTConfigWriteCommand(config: config)

    jqLogger = CatchLogger(expectation: badProtoExpectation)

    let badProto = Google_Jacquard_Protocol_Color()
    configWriteRequest.parseResponse(outerProto: badProto).assertFailure()
    wait(for: [badProtoExpectation], timeout: 1)
  }
}
