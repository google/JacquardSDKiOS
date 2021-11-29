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

class DFUCommandTests: XCTestCase {

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

  func testDFUStatusRequestCreation() {
    let expectedVendorID: UInt32 = 293_089_480
    let expectedProductID: UInt32 = 675_014_560
    let expectedDomain: Google_Jacquard_Protocol_Domain = .dfu
    let expectedOpcode: Google_Jacquard_Protocol_Opcode = .dfuStatus

    // Compose the request.
    let dfuStatusRequest = DFUStatusCommand(
      vendorID: expectedVendorID,
      productID: expectedProductID
    )

    guard let request = dfuStatusRequest.request as? Google_Jacquard_Protocol_Request else {
      XCTFail("Unexpected type for the dfu status request.")
      return
    }

    // Validate the request.
    XCTAssertEqual(request.domain, expectedDomain, "DFU status request has wrong domain.")
    XCTAssertEqual(request.opcode, expectedOpcode, "DFU status request has wrong opcode.")
    XCTAssert(request.hasGoogle_Jacquard_Protocol_DFUStatusRequest_dfuStatus)
    let statusRequest = request.Google_Jacquard_Protocol_DFUStatusRequest_dfuStatus
    XCTAssertEqual(
      statusRequest.vendorID,
      expectedVendorID,
      "Received wrong vendor ID in DFU status command.")
    XCTAssertEqual(
      statusRequest.productID,
      expectedProductID,
      "Received wrong product ID in DFU status command.")
  }

  func testDFUStatusGoodResponse() {
    let goodResponseExpectation = expectation(description: "goodResponseExpectation")
    let dfuStatusRequest = DFUStatusCommand(vendorID: 293_089_480, productID: 675_014_560)

    let goodProto = Google_Jacquard_Protocol_Response.with {
      let dfuStatus = Google_Jacquard_Protocol_DFUStatusResponse.with {
        $0.component = 0
        $0.currentCrc = 0
        $0.currentSize = 0
        $0.finalCrc = 0
        $0.finalSize = 0
      }
      $0.Google_Jacquard_Protocol_DFUStatusResponse_dfuStatus = dfuStatus
    }
    dfuStatusRequest.parseResponse(outerProto: goodProto).assertSuccess { _ in
      goodResponseExpectation.fulfill()
    }
    wait(for: [goodResponseExpectation], timeout: 0.5)
  }

  func testDFUStatusMalformedResponse() {
    let malformedResponseExpectation = expectation(description: "malformedResponseExpectation")
    let dfuStatusRequest = DFUStatusCommand(vendorID: 293_089_480, productID: 675_014_560)

    let malformedResponse = Google_Jacquard_Protocol_Response.with {

      // Providing wrong response(config write command response).
      let config = Google_Jacquard_Protocol_BleConfiguration()
      let ujtConfigResponse = Google_Jacquard_Protocol_UJTConfigResponse.with {
        $0.bleConfig = config
      }
      $0.Google_Jacquard_Protocol_UJTConfigResponse_configResponse = ujtConfigResponse
    }
    dfuStatusRequest.parseResponse(outerProto: malformedResponse).assertFailure { _ in
      malformedResponseExpectation.fulfill()
    }

    wait(for: [malformedResponseExpectation], timeout: 0.5)
  }

  func testDFUStatusBadResponse() {
    let badResponseExpectation = expectation(description: "badResponseExpectation")
    let dfuStatusRequest = DFUStatusCommand(vendorID: 293_089_480, productID: 675_014_560)
    jqLogger = CatchLogger(expectation: badResponseExpectation)

    // Provide bad proto as response.
    let badResponse = Google_Jacquard_Protocol_Color()
    dfuStatusRequest.parseResponse(outerProto: badResponse).assertFailure()
    wait(for: [badResponseExpectation], timeout: 0.5)
  }

  func testDFUPrepareRequestCreation() {
    let expectedVendorID: UInt32 = 293_089_480
    let expectedProductID: UInt32 = 675_014_560
    let expectedComponentID: UInt32 = 0
    let expectedFinalCrc: UInt32 = 34858
    let expectedFinalSize: UInt32 = 179192
    let expectedDomain: Google_Jacquard_Protocol_Domain = .dfu
    let expectedOpcode: Google_Jacquard_Protocol_Opcode = .dfuPrepare

    // Compose the request.
    let dfuPrepareRequest = DFUPrepareCommand(
      vendorID: expectedVendorID,
      productID: expectedProductID,
      componentID: expectedComponentID,
      finalCrc: expectedFinalCrc,
      finalSize: expectedFinalSize
    )

    guard let request = dfuPrepareRequest.request as? Google_Jacquard_Protocol_Request else {
      XCTFail("Unexpected type for the dfu prepare request.")
      return
    }

    // Validate the request.
    XCTAssertEqual(request.domain, expectedDomain, "DFU prepare request has wrong domain.")
    XCTAssertEqual(request.opcode, expectedOpcode, "DFU prepare request has wrong opcode.")
    XCTAssert(request.hasGoogle_Jacquard_Protocol_DFUPrepareRequest_dfuPrepare)
    let prepareRequest = request.Google_Jacquard_Protocol_DFUPrepareRequest_dfuPrepare
    XCTAssertEqual(
      prepareRequest.vendorID,
      expectedVendorID,
      "Received wrong vendor ID in DFU prepare command.")
    XCTAssertEqual(
      prepareRequest.productID,
      expectedProductID,
      "Received wrong product ID in DFU prepare command.")
    XCTAssertEqual(
      prepareRequest.component,
      expectedComponentID,
      "Received wrong component ID in DFU prepare command.")
    XCTAssertEqual(
      prepareRequest.finalCrc,
      expectedFinalCrc,
      "Received wrong final CRC in DFU prepare command.")
    XCTAssertEqual(
      prepareRequest.finalSize,
      expectedFinalSize,
      "Received wrong final size in DFU prepare command.")
  }

  func testDFUPrepareGoodResponse() {
    let goodResponseExpectation = expectation(description: "goodResponseExpectation")

    let dfuPrepareRequest = DFUPrepareCommand(
      vendorID: 293_089_480,
      productID: 675_014_560,
      componentID: 0,
      finalCrc: 34858,
      finalSize: 179192
    )
    let goodResponse = Google_Jacquard_Protocol_Response()
    dfuPrepareRequest.parseResponse(outerProto: goodResponse).assertSuccess { _ in
      goodResponseExpectation.fulfill()
    }

    wait(for: [goodResponseExpectation], timeout: 0.5)
  }

  func testDFUPrepareBadResponse() {
    let badResponseExpectation = expectation(description: "badResponseExpectation")

    let dfuPrepareRequest = DFUPrepareCommand(
      vendorID: 293_089_480,
      productID: 675_014_560,
      componentID: 0,
      finalCrc: 34858,
      finalSize: 179192
    )
    jqLogger = CatchLogger(expectation: badResponseExpectation)

    // Provide bad proto as response.
    let badResponse = Google_Jacquard_Protocol_Color()
    dfuPrepareRequest.parseResponse(outerProto: badResponse).assertFailure()
    wait(for: [badResponseExpectation], timeout: 1)
  }

  func testDFUWriteRequestCreation() {
    let expectedData = Data((0..<128).map { $0 })
    let expectedOffset: UInt32 = 0
    let expectedDomain: Google_Jacquard_Protocol_Domain = .dfu
    let expectedOpcode: Google_Jacquard_Protocol_Opcode = .dfuWrite

    // Compose the request.
    let dfuWriteRequest = DFUWriteCommand(data: expectedData, offset: expectedOffset)

    guard let request = dfuWriteRequest.request as? Google_Jacquard_Protocol_Request else {
      XCTFail("Unexpected type for the dfu write request.")
      return
    }

    // Validate the request.
    XCTAssertEqual(request.domain, expectedDomain, "DFU write request has wrong domain.")
    XCTAssertEqual(request.opcode, expectedOpcode, "DFU write request has wrong opcode.")
    XCTAssert(request.hasGoogle_Jacquard_Protocol_DFUWriteRequest_dfuWrite)
    let writeRequest = request.Google_Jacquard_Protocol_DFUWriteRequest_dfuWrite
    XCTAssertEqual(
      writeRequest.data,
      expectedData,
      "Received wrong data in DFU write command.")
    XCTAssertEqual(
      writeRequest.offset,
      expectedOffset,
      "Received wrong offset in DFU write command.")
  }

  func testDFUWriteGoodResponse() {
    let goodResponseExpectation = expectation(description: "goodResponseExpectation")
    let dfuWriteRequest = DFUWriteCommand(data: Data((0..<128).map { $0 }), offset: 0)

    let goodProto = Google_Jacquard_Protocol_Response.with {
      let dfuWrite = Google_Jacquard_Protocol_DFUWriteResponse.with {
        $0.offset = 128
        $0.crc = 42247
      }
      $0.Google_Jacquard_Protocol_DFUWriteResponse_dfuWrite = dfuWrite
    }
    dfuWriteRequest.parseResponse(outerProto: goodProto).assertSuccess { _ in
      goodResponseExpectation.fulfill()
    }
    wait(for: [goodResponseExpectation], timeout: 0.5)
  }

  func testDFUWriteMalformedResponse() {
    let malformedResponseExpectation = expectation(description: "malformedResponseExpectation")
    let dfuWriteRequest = DFUWriteCommand(data: Data((0..<128).map { $0 }), offset: 0)

    let malformedResponse = Google_Jacquard_Protocol_Response.with {

      // Providing wrong response(config write command response).
      let config = Google_Jacquard_Protocol_BleConfiguration()
      let ujtConfigResponse = Google_Jacquard_Protocol_UJTConfigResponse.with {
        $0.bleConfig = config
      }
      $0.Google_Jacquard_Protocol_UJTConfigResponse_configResponse = ujtConfigResponse
    }
    dfuWriteRequest.parseResponse(outerProto: malformedResponse).assertFailure { _ in
      malformedResponseExpectation.fulfill()
    }

    wait(for: [malformedResponseExpectation], timeout: 0.5)
  }

  func testDFUWriteBadResponse() {
    let badResponseExpectation = expectation(description: "badResponseExpectation")
    let dfuWriteRequest = DFUWriteCommand(data: Data((0..<128).map { $0 }), offset: 0)
    jqLogger = CatchLogger(expectation: badResponseExpectation)

    // Provide bad proto as response.
    let badResponse = Google_Jacquard_Protocol_Color()
    dfuWriteRequest.parseResponse(outerProto: badResponse).assertFailure()
    wait(for: [badResponseExpectation], timeout: 1)
  }

  func testDFUExecuteRequestCreation() {
    let expectedVendorID: UInt32 = 293_089_480
    let expectedProductID: UInt32 = 675_014_560
    let expectedDomain: Google_Jacquard_Protocol_Domain = .dfu
    let expectedOpcode: Google_Jacquard_Protocol_Opcode = .dfuExecute

    // Compose the request.
    let dfuExecuteRequest = DFUExecuteCommand(
      vendorID: expectedVendorID,
      productID: expectedProductID
    )

    guard let request = dfuExecuteRequest.request as? Google_Jacquard_Protocol_Request else {
      XCTFail("Unexpected type for the dfu execute request.")
      return
    }

    // Validate the request.
    XCTAssertEqual(request.domain, expectedDomain, "DFU execute request has wrong domain.")
    XCTAssertEqual(request.opcode, expectedOpcode, "DFU execute request has wrong opcode.")
    XCTAssert(request.hasGoogle_Jacquard_Protocol_DFUExecuteRequest_dfuExecute)
    let executeRequest = request.Google_Jacquard_Protocol_DFUExecuteRequest_dfuExecute
    XCTAssertEqual(
      executeRequest.vendorID,
      expectedVendorID,
      "Received wrong vendor ID in DFU execute command.")
    XCTAssertEqual(
      executeRequest.productID,
      expectedProductID,
      "Received wrong product ID in DFU execute command.")
  }

  func testDFUExecuteGoodResponse() {
    let goodResponseExpectation = expectation(description: "goodResponseExpectation")
    let dfuExecuteRequest = DFUExecuteCommand(vendorID: 293_089_480, productID: 675_014_560)
    let goodResponse = Google_Jacquard_Protocol_Response()
    dfuExecuteRequest.parseResponse(outerProto: goodResponse).assertSuccess { _ in
      goodResponseExpectation.fulfill()
    }

    wait(for: [goodResponseExpectation], timeout: 0.5)
  }

  func testDFUExecuteBadResponse() {
    let badResponseExpectation = expectation(description: "badResponseExpectation")
    let dfuExecuteRequest = DFUExecuteCommand(vendorID: 293_089_480, productID: 675_014_560)
    jqLogger = CatchLogger(expectation: badResponseExpectation)

    // Provide bad proto as response.
    let badResponse = Google_Jacquard_Protocol_Color()
    dfuExecuteRequest.parseResponse(outerProto: badResponse).assertFailure()
    wait(for: [badResponseExpectation], timeout: 0.5)
  }
}
