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

  let uuid = UUID(uuidString: "BD415750-8EF1-43EE-8A7F-7EF1E365C35E")!
  let deviceName = "Fake Device"
  var observations = [Cancellable]()
  var tagConnectionStateMachine: TagConnectionStateMachine?

  var service: CBService {
    let service = CBMutableService(type: JacquardServices.v2Service, primary: true)

    let commandUUID = CBUUID(string: "D2F2EABB-D165-445C-B0E1-2D6B642EC57B")
    let commandCharacteristic = CBMutableCharacteristic(
      type: commandUUID,
      properties: [.write],
      value: nil,
      permissions: .writeable
    )

    let responseUUID = CBUUID(string: "D2F2B8D0-D165-445C-B0E1-2D6B642EC57B")
    let responseCharacteristic = CBMutableCharacteristic(
      type: responseUUID,
      properties: [.notify],
      value: nil,
      permissions: .readable
    )

    let notifyUUID = CBUUID(string: "D2F2B8D1-D165-445C-B0E1-2D6B642EC57B")
    let notifyCharacteristic = CBMutableCharacteristic(
      type: notifyUUID,
      properties: [.notify],
      value: nil,
      permissions: .readable
    )

    service.characteristics = [
      commandCharacteristic, responseCharacteristic, notifyCharacteristic,
    ]

    return service
  }

  func testTagDidConnect() {
    let preparingToConnectExpectation = expectation(description: "PreparingToConnectExpectation")
    let connectingExpectation = expectation(description: "ConnectingExpectation")
    connectingExpectation.expectedFulfillmentCount = 4

    let writeCommandCharacteristicExpectation = expectation(
      description: "WriteCommandCharacteristicExpectation"
    )

    let helloCommandRequestExpectation = expectation(description: "HelloCommandRequestExpectation")
    let helloCommandResponseExpectation = expectation(
      description: "HelloCommandResponseExpectation"
    )

    let beginCommandRequestExpectation = expectation(description: "BeginCommandRequestExpectation")
    let beginCommandResponseExpectation = expectation(
      description: "BeginCommandResponseExpectation"
    )

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
      connectionMethod: centralManagerConnect
    )

    tagConnectionStateMachine = connectionStateMachine
    connectionStateMachine.statePublisher.sink { (state) in
      switch state {
      case .preparingToConnect:
        preparingToConnectExpectation.fulfill()
      case .connecting(0...3, _):
        connectingExpectation.fulfill()
      case .initializing(4, _):
        helloCommandRequestExpectation.fulfill()
      case .initializing(5, _):
        peripheral.didWriteValue = true
        writeCommandCharacteristicExpectation.fulfill()
      case .initializing(6, _):
        peripheral.postUpdateForHelloCommandResponse()
        helloCommandResponseExpectation.fulfill()
      case .initializing(7, _):
        beginCommandRequestExpectation.fulfill()
      case .initializing(8, _):
        peripheral.postUpdateForBeginCommandResponse()
        beginCommandResponseExpectation.fulfill()
      case .initializing(9, _):
        configTagCommandRequestExpectation.fulfill()
      case .configuring(10, _):
        peripheral.didWriteValue = false
        peripheral.postConfigTagCommandResponse()
        configTagCommandResponseExpectation.fulfill()
      case .connected(let tag):
        XCTAssertEqual(tag.name, peripheral.name)
        XCTAssertNotNil(tag.tagComponent.product)
        XCTAssertNotNil(tag.tagComponent.vendor)
        XCTAssertEqual(tag.tagComponent.product.name, "ujt")
        XCTAssertEqual(tag.tagComponent.vendor.name, "google")
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
        writeCommandCharacteristicExpectation, helloCommandResponseExpectation,
        beginCommandRequestExpectation, beginCommandResponseExpectation,
        configTagCommandRequestExpectation, configTagCommandResponseExpectation,
        connectedTagExpectation, disconnectedTagExpectation,
      ],
      timeout: 2.0,
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
      userPublishQueue: .main
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
      userPublishQueue: .main
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
      self.tagConnectionStateMachine?.didDisconnect(error: nil)
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
      userPublishQueue: .main
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
      self.tagConnectionStateMachine?.didDisconnect(error: nil)
    }
    fsm.disconnect { (_, _) in
      self.tagConnectionStateMachine?.didDisconnect(error: nil)
    }

    wait(for: [stateTerminalExpectation], timeout: 1.0)
  }
}
