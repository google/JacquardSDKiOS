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

final class TagConnectionStateMachineTests: XCTestCase {

  private let connectionTimeoutDuration = 60.0
  let uuid = UUID(uuidString: "BD415750-8EF1-43EE-8A7F-7EF1E365C35E")!
  let deviceName = "Fake Device"
  var observations = [Cancellable]()
  var tagConnectionStateMachine: TagConnectionStateMachine?

  var service: CBService {
    let service = CBMutableService(type: JacquardServices.v2Service, primary: true)

    let commandCharacteristic = CBMutableCharacteristic(
      type: JacquardServices.commandUUID,
      properties: [.write, .writeWithoutResponse],
      value: nil,
      permissions: .writeable
    )

    let responseCharacteristic = CBMutableCharacteristic(
      type: JacquardServices.responseUUID,
      properties: [.notify],
      value: nil,
      permissions: .readable
    )

    let notifyCharacteristic = CBMutableCharacteristic(
      type: JacquardServices.notifyUUID,
      properties: [.notify],
      value: nil,
      permissions: .readable
    )

    let rawDataCharacteristic = CBMutableCharacteristic(
      type: JacquardServices.rawDataUUID,
      properties: [.notify],
      value: nil,
      permissions: .readable
    )

    service.characteristics = [
      commandCharacteristic, responseCharacteristic, notifyCharacteristic, rawDataCharacteristic,
    ]

    return service
  }

  func testTagDidConnect() {
    let preparingToConnectExpectation = expectation(description: "PreparingToConnectExpectation")
    let connectingExpectation = expectation(description: "ConnectingExpectation")
    connectingExpectation.expectedFulfillmentCount = 5

    let helloCommandRequestExpectation = expectation(description: "HelloCommandRequestExpectation")
    let helloCommandResponseExpectation = expectation(
      description: "HelloCommandResponseExpectation"
    )

    let beginCommandRequestExpectation = expectation(description: "BeginCommandRequestExpectation")
    let componentInfoCommandRequestExpectation = expectation(
      description: "componentInfoCommandRequestExpectation")

    let configTagCommandRequestExpectation = expectation(
      description: "configTagCommandRequestExpectation"
    )
    let configTagCommandResponseExpectation = expectation(
      description: "ConfigTagCommandResponseExpectation"
    )

    let connectedTagExpectation = expectation(description: "connectedTagExpectation")
    let disconnectedTagExpectation = expectation(description: "disconnectedTagExpectation")

    let centralManagerConnect: (Peripheral, [String: Any]?) -> Void = { peripheral, options in
      guard let peripheral = peripheral as? FakePeripheralImplementation else {
        preconditionFailure("Unexpected peripheral")
      }
      self.tagConnectionStateMachine?.didConnect(peripheral: peripheral)
    }

    let peripheral = FakePeripheralImplementation(identifier: uuid, name: deviceName)
    peripheral.services = [service]

    let connectionStateMachine = TagConnectionStateMachine(
      peripheral: peripheral,
      userPublishQueue: .main,
      sdkConfig: config,
      connectionTimeoutDuration: connectionTimeoutDuration,
      connectionMethod: centralManagerConnect
    )

    tagConnectionStateMachine = connectionStateMachine
    connectionStateMachine.statePublisher.sink { state in
      switch state {
      case .preparingToConnect:
        preparingToConnectExpectation.fulfill()
      case .connecting(0...4, _):
        connectingExpectation.fulfill()
      case .initializing(5, _):
        peripheral.callbackType = .didWriteValue(.helloCommand)
        helloCommandRequestExpectation.fulfill()
        peripheral.postUpdateForHelloCommandResponse()
      case .initializing(6, _):
        helloCommandResponseExpectation.fulfill()
      case .initializing(7, _):
        beginCommandRequestExpectation.fulfill()
        peripheral.callbackType = .didWriteValue(.beginCommand)
        peripheral.postUpdateForBeginCommandResponse()
      case .initializing(8, _):
        componentInfoCommandRequestExpectation.fulfill()
        peripheral.callbackType = .didWriteValue(.componentInfoCommand)
        peripheral.postUpdateForComponentInfoResponse()
      case .initializing(9, _):
        configTagCommandRequestExpectation.fulfill()
        peripheral.callbackType = .didWriteValue(.none)
        peripheral.postConfigTagCommandResponse()
      case .configuring(10, _):
        configTagCommandResponseExpectation.fulfill()
      case .connected(let tag):
        XCTAssertEqual(tag.name, peripheral.name)
        XCTAssertNotNil(tag.tagComponent.product)
        XCTAssertNotNil(tag.tagComponent.vendor)
        XCTAssertEqual(tag.tagComponent.product.name, TagConstants.product)
        XCTAssertEqual(tag.tagComponent.vendor.name, FakePeripheralImplementation.tagVendorName)
        XCTAssertEqual(tag.tagComponent.version, FakePeripheralImplementation.tagVersion)
        XCTAssertEqual(tag.tagComponent.uuid, FakePeripheralImplementation.tagUUID)
        connectedTagExpectation.fulfill()

        // Once connected, queue up a disconnection
        DispatchQueue.main.async {
          // Ensure reconnection doesn't happen.
          connectionStateMachine.context.isUserDisconnect = true
          connectionStateMachine.disconnect { _, _ in
            self.tagConnectionStateMachine?.didDisconnect(error: nil)
          }
        }
      case .disconnected(let error):
        XCTAssertNil(error)
        disconnectedTagExpectation.fulfill()
      default:
        XCTFail("Failed with state \(state)")
      }
    }.addTo(&observations)

    connectionStateMachine.connect()

    wait(
      for: [
        preparingToConnectExpectation, connectingExpectation, helloCommandRequestExpectation,
        helloCommandResponseExpectation, beginCommandRequestExpectation,
        componentInfoCommandRequestExpectation, configTagCommandRequestExpectation,
        configTagCommandResponseExpectation, connectedTagExpectation, disconnectedTagExpectation,
      ],
      timeout: 5.0,
      enforceOrder: true
    )
  }

  enum TestError: Error {
    case testError
  }

  func testShouldReconnectLogic() {
    let peripheral = FakePeripheralImplementation(identifier: uuid, name: deviceName)
    peripheral.services = [service]

    let fsm = TagConnectionStateMachine(
      peripheral: peripheral,
      userPublishQueue: .main,
      sdkConfig: config,
      connectionTimeoutDuration: connectionTimeoutDuration
    ) { (_, _) in }

    // Currently no errors are deny-listed.
    XCTAssertEqual(fsm.shouldReconnect(for: TestError.testError), true)

    // Currently only user-initiated disconnects prevent reconnection.
    XCTAssertEqual(fsm.shouldReconnectForDisconnection(error: nil), true)
    fsm.context.isUserDisconnect = true
    XCTAssertEqual(fsm.shouldReconnectForDisconnection(error: nil), false)
  }

  func testInvalidTransition() {
    let peripheral = FakePeripheralImplementation(identifier: uuid, name: deviceName)
    peripheral.services = [service]

    let invalidTransitionExpectation = expectation(description: "invalidTransitionExpectation")

    let fsm = TagConnectionStateMachine(
      peripheral: peripheral,
      userPublishQueue: .main,
      sdkConfig: config,
      connectionTimeoutDuration: connectionTimeoutDuration
    ) { (_, _) in }

    fsm.statePublisher.sink { state in
      switch state {
      case .disconnected(let error):
        XCTAssertNotNil(error)
        invalidTransitionExpectation.fulfill()
        break
      default:
        break
      }
    }.addTo(&observations)

    tagConnectionStateMachine = fsm

    fsm.disconnect { (_, _) in
      self.tagConnectionStateMachine?.didDisconnect(error: TagConnectionError.internalError)
    }

    wait(for: [invalidTransitionExpectation], timeout: 1.0)
  }

  func testStateTerminal() {
    let peripheral = FakePeripheralImplementation(identifier: uuid, name: deviceName)
    peripheral.services = [service]

    let stateTerminalExpectation = expectation(description: "stateTerminalExpectation")
    stateTerminalExpectation.expectedFulfillmentCount = 2

    let fsm = TagConnectionStateMachine(
      peripheral: peripheral,
      userPublishQueue: .main,
      sdkConfig: config,
      connectionTimeoutDuration: connectionTimeoutDuration
    ) { _, _ in }

    fsm.statePublisher.sink { state in
      switch state {
      case .disconnected(let error):
        XCTAssertNotNil(error)
        stateTerminalExpectation.fulfill()
        break
      default:
        break
      }
    }.addTo(&observations)

    tagConnectionStateMachine = fsm

    fsm.disconnect { (_, _) in
      self.tagConnectionStateMachine?.didDisconnect(error: TagConnectionError.internalError)
    }
    fsm.disconnect { (_, _) in
      self.tagConnectionStateMachine?.didDisconnect(error: TagConnectionError.internalError)
    }

    wait(for: [stateTerminalExpectation], timeout: 1.0)
  }

  func testTagPairingTimeout() {
    let preparingToConnectExpectation = expectation(description: "PreparingToConnectExpectation")
    let pairingTimeoutExpectation = expectation(description: "pairingTimeoutExpectation")

    let centralManagerConnect: (Peripheral, [String: Any]?) -> Void = { _, _ in }

    let peripheral = FakePeripheralImplementation(identifier: uuid, name: deviceName)
    peripheral.services = [service]

    let connectionStateMachine = TagConnectionStateMachine(
      peripheral: peripheral,
      userPublishQueue: .main,
      sdkConfig: config,
      connectionTimeoutDuration: connectionTimeoutDuration,
      connectionMethod: centralManagerConnect
    )
    connectionStateMachine.shouldReconnect = false

    tagConnectionStateMachine = connectionStateMachine

    connectionStateMachine.statePublisher.sink { state in
      switch state {
      case .preparingToConnect:
        preparingToConnectExpectation.fulfill()
      case .disconnected(let error):
        XCTAssertNotNil(error)
        if let error = error as? TagConnectionError, case .connectionTimeout = error {
          pairingTimeoutExpectation.fulfill()
        } else {
          XCTFail("Failed with state \(state)")
        }
      default:
        XCTFail("Failed with state \(state)")
      }
    }.addTo(&observations)

    connectionStateMachine.connect()

    // Default connection timeout is 60 secs so need to wait 61 seconds for test to complete.
    wait(
      for: [
        preparingToConnectExpectation, pairingTimeoutExpectation,
      ],
      timeout: connectionTimeoutDuration + 1,
      enforceOrder: true
    )
  }
}
