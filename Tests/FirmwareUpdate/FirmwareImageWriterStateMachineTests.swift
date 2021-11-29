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

final class FirmwareImageWriterStateMachineTests: XCTestCase {

  private var observations = [Cancellable]()

  func testVerifyInitialState() {
    let initialStateExpectation = expectation(description: "initialStateExpectation")
    let connectedTag = FakeConnectedTag(transport: FakeTransport())

    let imageWriterStateMachine = FirmwareImageWriterStateMachine(
      image: Data((0..<1000).map { UInt8($0 % 255) }),
      tag: connectedTag,
      vendorID: connectedTag.tagComponent.vendor.id,
      productID: connectedTag.tagComponent.product.id,
      componentID: connectedTag.tagComponent.componentID
    )

    imageWriterStateMachine.statePublisher.sink { initialState in
      switch initialState {
      case .idle:
        initialStateExpectation.fulfill()
      default:
        XCTFail("Failed with state \(initialState)")
      }
    }.addTo(&observations)

    wait(for: [initialStateExpectation], timeout: 1.0)
  }

  func testDFUWriteSuccess() {
    let stateChangeExpectation = expectation(description: "stateChangeExpectation")
    let checkingStatusExpectation = expectation(description: "checkingStatusExpectation")
    let preparingForWriteExpectation = expectation(description: "preparingForWriteExpectation")
    let writingExpectation = expectation(description: "writingExpectation")
    let writeSuccessExpectation = expectation(description: "writeSuccessExpectation")
    // Image size / Chunk size: 1000 / 128 ~ 8
    writingExpectation.expectedFulfillmentCount = 8

    let transport = FakeTransport()
    let connectedTag = FakeConnectedTag(transport: transport)
    let image = Data((0..<1000).map { UInt8($0 % 255) })

    transport.enqueueRequestHandler = { (request, _, _) in

      // Safe to force unwrap here as the request will always be of type
      // `Google_Jacquard_Protocol_Request`.
      let request = request as! Google_Jacquard_Protocol_Request

      if request.domain == .dfu && request.opcode == .dfuStatus {
        let expectedStatusRequest = FakeDFUCommands.prepareDFUStatusRequest(
          vid: "11-78-30-c8", pid: "28-3b-e7-a0")

        XCTAssertEqual(request, expectedStatusRequest, "Incorrect status request")

        let dfuStatusResponse = Google_Jacquard_Protocol_DFUStatusResponse.with { response in
          response.finalSize = 0
          response.finalCrc = 0
          response.currentSize = 0
          response.currentCrc = 0
        }
        return
          .success(
            FakeDFUCommands.prepareDFUStatusResponse(
              status: .ok,
              dfuStatusResponse: dfuStatusResponse
            )
          )
      } else if request.domain == .dfu && request.opcode == .dfuPrepare {
        let expectedPrepareRequest = FakeDFUCommands.prepareDFUPrepareRequest(
          componentID: 0, vid: "11-78-30-c8", pid: "28-3b-e7-a0", image: image)

        XCTAssertEqual(request, expectedPrepareRequest, "Incorrect prepare request")

        return .success(FakeDFUCommands.prepareDFUPrepareResponse(status: .ok))
      } else {
        preconditionFailure()
      }
    }

    let imageWriterStateMachine = FirmwareImageWriterStateMachine(
      image: image,
      tag: connectedTag,
      vendorID: connectedTag.tagComponent.vendor.id,
      productID: connectedTag.tagComponent.product.id,
      componentID: connectedTag.tagComponent.componentID
    )

    imageWriterStateMachine.statePublisher.sink { state in
      switch state {
      case .idle:
        stateChangeExpectation.fulfill()
      case .checkingStatus:
        checkingStatusExpectation.fulfill()
      case .preparingForWrite:
        preparingForWriteExpectation.fulfill()
      case .writing(_):
        writingExpectation.fulfill()
      case .complete:
        writeSuccessExpectation.fulfill()
      default:
        XCTFail("Failed with state \(state)")
      }
    }.addTo(&observations)

    imageWriterStateMachine.startWriting()

    wait(
      for: [stateChangeExpectation, checkingStatusExpectation, preparingForWriteExpectation],
      timeout: 1.0,
      enforceOrder: true
    )

    // Assert multiple write requests till entire image is written.
    stride(from: 0, to: image.count, by: FirmwareImageWriterStateMachine.imageChunkSize)
      .forEach { index in
        let offset = min(index + FirmwareImageWriterStateMachine.imageChunkSize, image.count)
        let data = image[index..<offset]
        let expectedWriteRequest = FakeDFUCommands.prepareDFUWriteRequest(
          data: data,
          offset: UInt32(index)
        )
        let dfuWriteRequestExpectation = expectation(description: "dfuWriteRequestExpectation")

        transport.enqueueRequestHandler = { (request, _, _) in

          // Safe to force unwrap here as the request will always be of type
          // `Google_Jacquard_Protocol_Request`.
          let request = request as! Google_Jacquard_Protocol_Request

          if request.domain == .dfu && request.opcode == .dfuWrite {

            XCTAssertEqual(request, expectedWriteRequest, "Incorrect request.")
            dfuWriteRequestExpectation.fulfill()

            let crc = UInt32(CRC16.compute(in: image[0..<offset], seed: 0))
            let writeResponse = Google_Jacquard_Protocol_DFUWriteResponse.with { response in
              response.offset = UInt32(offset)
              response.crc = crc
            }
            return .success(
              FakeDFUCommands.prepareDFUWriteResponse(status: .ok, writeResponse: writeResponse)
            )
          } else {
            preconditionFailure()
          }
        }
        wait(for: [dfuWriteRequestExpectation], timeout: 1.0)
      }

    wait(
      for: [writingExpectation, writeSuccessExpectation],
      timeout: 1.0,
      enforceOrder: true
    )
  }

  func testDFUStatusFailure() {
    let stateChangeExpectation = expectation(description: "stateChangeExpectation")
    let checkingStatusExpectation = expectation(description: "checkingStatusExpectation")
    let statusFailureExpectation = expectation(description: "statusFailureExpectation")

    let transport = FakeTransport()
    let connectedTag = FakeConnectedTag(transport: transport)

    // Provide failure response through enqueue function handler.
    transport.enqueueRequestHandler = { (request, _, _) in
      return .success(
        FakeDFUCommands.prepareDFUStatusResponse(status: .errorHardware, dfuStatusResponse: nil)
      )
    }

    let imageWriterStateMachine = FirmwareImageWriterStateMachine(
      image: Data((0..<1000).map { UInt8($0 % 255) }),
      tag: connectedTag,
      vendorID: connectedTag.tagComponent.vendor.id,
      productID: connectedTag.tagComponent.product.id,
      componentID: connectedTag.tagComponent.componentID
    )

    imageWriterStateMachine.statePublisher.sink { state in
      switch state {
      case .idle:
        stateChangeExpectation.fulfill()
      case .checkingStatus:
        checkingStatusExpectation.fulfill()
      case .error(_):
        statusFailureExpectation.fulfill()
      default:
        XCTFail("Failed with state \(state)")
      }
    }.addTo(&observations)

    imageWriterStateMachine.startWriting()

    wait(
      for: [stateChangeExpectation, checkingStatusExpectation, statusFailureExpectation],
      timeout: 1.0, enforceOrder: true)
  }

  func testDFUPrepareFailure() throws {
    throw XCTSkip("b/204121008 - flaky tests")

    let stateChangeExpectation = expectation(description: "stateChangeExpectation")
    let checkingStatusExpectation = expectation(description: "checkingStatusExpectation")
    let preparingForWriteExpectation = expectation(description: "preparingForWriteExpectation")
    let prepareFailureExpectation = expectation(description: "prepareFailureExpectation")

    let transport = FakeTransport()
    let connectedTag = FakeConnectedTag(transport: transport)

    // Provide failure response through enqueue function handler.
    transport.enqueueRequestHandler = { (request, _, _) in

      // Safe to force unwrap here as the request will always be of type
      // `Google_Jacquard_Protocol_Request`.
      let request = request as! Google_Jacquard_Protocol_Request

      if request.domain == .dfu && request.opcode == .dfuStatus {
        let dfuStatusResponse = Google_Jacquard_Protocol_DFUStatusResponse.with { response in
          response.finalSize = 0
          response.finalCrc = 0
          response.currentSize = 0
          response.currentCrc = 0
        }
        return
          .success(
            FakeDFUCommands.prepareDFUStatusResponse(
              status: .ok,
              dfuStatusResponse: dfuStatusResponse
            )
          )
      } else if request.domain == .dfu && request.opcode == .dfuPrepare {
        return .success(FakeDFUCommands.prepareDFUPrepareResponse(status: .errorHardware))
      } else {
        preconditionFailure()
      }
    }

    let imageWriterStateMachine = FirmwareImageWriterStateMachine(
      image: Data((0..<1000).map { UInt8($0 % 255) }),
      tag: connectedTag,
      vendorID: connectedTag.tagComponent.vendor.id,
      productID: connectedTag.tagComponent.product.id,
      componentID: connectedTag.tagComponent.componentID
    )

    imageWriterStateMachine.statePublisher.sink { state in
      switch state {
      case .idle:
        stateChangeExpectation.fulfill()
      case .checkingStatus:
        checkingStatusExpectation.fulfill()
      case .preparingForWrite:
        preparingForWriteExpectation.fulfill()
      case .error(_):
        prepareFailureExpectation.fulfill()
      default:
        XCTFail("Failed with state \(state)")
      }
    }.addTo(&observations)

    imageWriterStateMachine.startWriting()

    wait(
      for: [
        stateChangeExpectation, checkingStatusExpectation, preparingForWriteExpectation,
        prepareFailureExpectation,
      ],
      timeout: 1.0,
      enforceOrder: true
    )
  }

  func testDFUWriteFailure() {
    let stateChangeExpectation = expectation(description: "stateChangeExpectation")
    let checkingStatusExpectation = expectation(description: "checkingStatusExpectation")
    let preparingForWriteExpectation = expectation(description: "preparingForWriteExpectation")
    let writingExpectation = expectation(description: "writingExpectation")
    let writeFailureExpectation = expectation(description: "writeFailureExpectation")

    let transport = FakeTransport()
    let connectedTag = FakeConnectedTag(transport: transport)

    // Provide failure response through enqueue function handler.
    transport.enqueueRequestHandler = { (request, _, _) in

      // Safe to force unwrap here as the request will always be of type
      // `Google_Jacquard_Protocol_Request`.
      let request = request as! Google_Jacquard_Protocol_Request

      if request.domain == .dfu && request.opcode == .dfuStatus {
        let dfuStatusResponse = Google_Jacquard_Protocol_DFUStatusResponse.with { response in
          response.finalSize = 0
          response.finalCrc = 0
          response.currentSize = 0
          response.currentCrc = 0
        }
        return
          .success(
            FakeDFUCommands.prepareDFUStatusResponse(
              status: .ok,
              dfuStatusResponse: dfuStatusResponse
            )
          )
      } else if request.domain == .dfu && request.opcode == .dfuPrepare {
        return .success(FakeDFUCommands.prepareDFUPrepareResponse(status: .ok))
      } else if request.domain == .dfu && request.opcode == .dfuWrite {
        return
          .success(
            FakeDFUCommands.prepareDFUWriteResponse(status: .errorBattery, writeResponse: nil)
          )
      } else {
        preconditionFailure()
      }
    }

    let imageWriterStateMachine = FirmwareImageWriterStateMachine(
      image: Data((0..<1000).map { UInt8($0 % 255) }),
      tag: connectedTag,
      vendorID: connectedTag.tagComponent.vendor.id,
      productID: connectedTag.tagComponent.product.id,
      componentID: connectedTag.tagComponent.componentID
    )

    imageWriterStateMachine.statePublisher.sink { state in
      switch state {
      case .idle:
        stateChangeExpectation.fulfill()
      case .checkingStatus:
        checkingStatusExpectation.fulfill()
      case .preparingForWrite:
        preparingForWriteExpectation.fulfill()
      case .writing(_):
        writingExpectation.fulfill()
      case .error(_):
        writeFailureExpectation.fulfill()
      default:
        XCTFail("Failed with state \(state)")
      }
    }.addTo(&observations)

    imageWriterStateMachine.startWriting()

    wait(
      for: [
        stateChangeExpectation, checkingStatusExpectation, preparingForWriteExpectation,
        writingExpectation, writeFailureExpectation,
      ],
      timeout: 1.0,
      enforceOrder: true
    )
  }
}
