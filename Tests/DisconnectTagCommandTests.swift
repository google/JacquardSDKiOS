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

final class DisconnectTagCommandTests: XCTestCase {

  func testRequestCreation() throws {
    let expectedTimeoutSecond: UInt32 = 10
    let expectedReconnectOnlyOnWOM = true
    let expectedDomain: Google_Jacquard_Protocol_Domain = .base
    let expectedOpcode: Google_Jacquard_Protocol_Opcode = .requestDisconnect

    // Compose the request.
    let disconnectTagRequest = DisconnectTagCommand(
      timeoutSecond: expectedTimeoutSecond, reconnectOnlyOnWOM: expectedReconnectOnlyOnWOM)

    let request = try XCTUnwrap(
      disconnectTagRequest.request as? Google_Jacquard_Protocol_Request,
      "Unexpected type for the disconnect tag request."
    )

    // Validate the request.
    XCTAssertEqual(request.domain, expectedDomain, "Disconnect tag request has wrong domain.")
    XCTAssertEqual(request.opcode, expectedOpcode, "Disconnect tag request has wrong opcode.")
    XCTAssert(request.hasGoogle_Jacquard_Protocol_BleDisconnectRequest_bleDisconnectRequest)
    let bleDisconnectRequest =
      request.Google_Jacquard_Protocol_BleDisconnectRequest_bleDisconnectRequest
    XCTAssertEqual(
      bleDisconnectRequest.timeoutSecond,
      expectedTimeoutSecond,
      "Received wrong timeout value for Disconnect tag command.")
    XCTAssertEqual(
      bleDisconnectRequest.reconnectOnlyOnWom,
      expectedReconnectOnlyOnWOM,
      "Received wrong reconnectOnlyOnWom value for Disconnect tag command.")
  }

  func testGoodResponse() {
    let goodResponseExpectation = expectation(description: "goodResponseExpectation")

    let disconnectTagRequest = DisconnectTagCommand()
    let goodResponse = Google_Jacquard_Protocol_Response()
    disconnectTagRequest.parseResponse(outerProto: goodResponse).assertSuccess { _ in
      goodResponseExpectation.fulfill()
    }

    wait(for: [goodResponseExpectation], timeout: 0.5)
  }

  func testBadResponse() {
    let badResponseExpectation = expectation(description: "badResponseExpectation")

    let disconnectTagRequest = DisconnectTagCommand()
    // Provide bad proto as response.
    let badResponse = Google_Jacquard_Protocol_Color()
    disconnectTagRequest.parseResponse(outerProto: badResponse).assertFailure { _ in
      badResponseExpectation.fulfill()
    }

    wait(for: [badResponseExpectation], timeout: 0.5)
  }
}
