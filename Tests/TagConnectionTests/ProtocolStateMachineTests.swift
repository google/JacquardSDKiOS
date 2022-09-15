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
import CoreBluetooth
import XCTest

@testable import JacquardSDK

final class ProtocolStateMachineTests: XCTestCase {

  private var commandCharacteristic: FakeCharacteristic {
    return FakeCharacteristic(commandValue: nil)
  }

  private var responseCharacteristic: FakeCharacteristic {
    return FakeCharacteristic(responseValue: nil)
  }

  private var notifyCharacteristic: FakeCharacteristic {
    return FakeCharacteristic(notifyValue: nil)
  }

  private var rawDataCharacteristic: FakeCharacteristic {
    return FakeCharacteristic(rawDataValue: nil)
  }

  private lazy var requiredCharacteristics = RequiredCharacteristics(
    commandCharacteristic: commandCharacteristic,
    responseCharacteristic: responseCharacteristic,
    notifyCharacteristic: notifyCharacteristic,
    rawDataCharacteristic: rawDataCharacteristic
  )

  var observations = [Cancellable]()
  let uuid = UUID(uuidString: "BD415750-8EF1-43EE-8A7F-7EF1E365C35E")!
  let deviceName = "Fake Device"

  func testVerifyInitialState() {
    let stateExpectation = expectation(description: "ProtocolStateMachine")
    let peripheral = FakePeripheralImplementation(identifier: uuid, name: deviceName)
    let initializationProtocolStateMachine = ProtocolInitializationStateMachine(
      peripheral: peripheral,
      characteristics: requiredCharacteristics,
      userPublishQueue: DispatchQueue.main,
      sdkConfig: config
    )

    initializationProtocolStateMachine.statePublisher.sink { initializationState in
      switch initializationState {
      case .paired:
        stateExpectation.fulfill()
      default:
        XCTFail("Failed with state \(initializationState)")
      }
    }.addTo(&observations)

    wait(for: [stateExpectation], timeout: 1.0)
  }

  func testVerifyNegotiationSuccess() {
    let stateExpectation = expectation(description: "ProtocolStateMachine")
    stateExpectation.expectedFulfillmentCount = 6

    let peripheral = FakePeripheralImplementation(identifier: uuid, name: deviceName)
    let initializationProtocolStateMachine = ProtocolInitializationStateMachine(
      peripheral: peripheral,
      characteristics: requiredCharacteristics,
      userPublishQueue: DispatchQueue.main,
      sdkConfig: config
    )

    initializationProtocolStateMachine.statePublisher.sink { initializationState in
      switch initializationState {
      case .paired, .creatingTagInstance:
        stateExpectation.fulfill()
      case .helloSent:
        stateExpectation.fulfill()
        peripheral.callbackType = .didWriteValue(.helloCommand)
        peripheral.postUpdateForHelloCommandResponse()
      case .beginSent:
        stateExpectation.fulfill()
        peripheral.callbackType = .didWriteValue(.beginCommand)
        peripheral.postUpdateForBeginCommandResponse()
      case .componentInfoSent:
        stateExpectation.fulfill()
        peripheral.callbackType = .didWriteValue(.componentInfoCommand)
        peripheral.postUpdateForComponentInfoResponse()
      case .tagInitialized(let tag):
        XCTAssertEqual(tag.name, peripheral.name)
        XCTAssertNotNil(tag.tagComponent.product)
        XCTAssertNotNil(tag.tagComponent.vendor)
        XCTAssertEqual(tag.tagComponent.product.name, TagConstants.product)
        XCTAssertEqual(tag.tagComponent.vendor.name, FakePeripheralImplementation.tagVendorName)
        XCTAssertEqual(tag.tagComponent.version, FakePeripheralImplementation.tagVersion)
        XCTAssertEqual(tag.tagComponent.uuid, FakePeripheralImplementation.tagUUID)
        stateExpectation.fulfill()
      case .error(let error):
        XCTFail("State failure error: \(error)")
      }
    }.addTo(&observations)

    initializationProtocolStateMachine.startNegotiation()

    wait(for: [stateExpectation], timeout: 5.0)
  }

  func testVerifyHelloSentFailure() {
    let stateExpectation = expectation(description: "ProtocolStateMachine")
    stateExpectation.expectedFulfillmentCount = 3

    let peripheral = FakePeripheralImplementation(identifier: uuid, name: deviceName)
    let initializationProtocolStateMachine = ProtocolInitializationStateMachine(
      peripheral: peripheral,
      characteristics: requiredCharacteristics,
      userPublishQueue: DispatchQueue.main,
      sdkConfig: config
    )

    initializationProtocolStateMachine.statePublisher.sink { initializationState in
      switch initializationState {
      case .paired:
        stateExpectation.fulfill()
      case .helloSent:
        stateExpectation.fulfill()
      case .error(let error):
        XCTAssertNotNil(error)
        stateExpectation.fulfill()
      default:
        XCTFail("Failed with state \(initializationState)")
      }
    }.addTo(&observations)

    initializationProtocolStateMachine.startNegotiation()

    wait(for: [stateExpectation], timeout: 3.0)
  }

  func testVerifyStateTerminal() {
    let stateExpectation = expectation(description: "ProtocolStateMachine")
    stateExpectation.expectedFulfillmentCount = 3

    let peripheral = FakePeripheralImplementation(identifier: uuid, name: deviceName)
    let initializationProtocolStateMachine = ProtocolInitializationStateMachine(
      peripheral: peripheral,
      characteristics: requiredCharacteristics,
      userPublishQueue: DispatchQueue.main,
      sdkConfig: config
    )

    initializationProtocolStateMachine.statePublisher.sink { initializationState in
      switch initializationState {
      case .paired:
        stateExpectation.fulfill()
      case .helloSent:
        stateExpectation.fulfill()
      case .error(_):
        XCTAssert(initializationState.isTerminal)
        stateExpectation.fulfill()
      default:
        XCTFail("Failed with state \(initializationState)")
      }
    }.addTo(&observations)

    initializationProtocolStateMachine.startNegotiation()

    wait(for: [stateExpectation], timeout: 3.0)
  }
}
