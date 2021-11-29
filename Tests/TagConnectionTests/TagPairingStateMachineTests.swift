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

final class TagPairingStateMachineTests: XCTestCase {

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

  var observations = [Cancellable]()
  let uuid = UUID(uuidString: "BD415750-8EF1-43EE-8A7F-7EF1E365C35E")!
  let deviceName = "Fake Device"

  func testVerifyDidConnect() {
    let peripheral = FakePeripheralImplementation(identifier: uuid, name: deviceName)
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

    peripheral.services = [service]

    let disconnectedStateExpectation = expectation(description: "DisconnectedStateExpectation")
    let bluetoothConnectedExpectation = expectation(description: "BluetoothConnectedExpectation")
    let servicesDiscoveredExpectation = expectation(description: "ServicesDiscoveredExpectation")
    let awaitingNotificationUpdatesExpectation = expectation(
      description: "AwaitingNotificationUpdatesExpectation"
    )
    awaitingNotificationUpdatesExpectation.expectedFulfillmentCount = 3

    let tagPairedExpectation = expectation(description: "TagPairedExpectation")

    let pairingStateMachine = TagPairingStateMachine(peripheral: peripheral)
    pairingStateMachine.statePublisher.sink { state in
      switch state {
      case .disconnected:
        disconnectedStateExpectation.fulfill()
      case .bluetoothConnected:
        bluetoothConnectedExpectation.fulfill()
      case .servicesDiscovered:
        servicesDiscoveredExpectation.fulfill()
      case .awaitingNotificationUpdates:
        // This state called 2 times (for each characteristics).
        awaitingNotificationUpdatesExpectation.fulfill()
      case .tagPaired(_, _):
        tagPairedExpectation.fulfill()
      default:
        XCTFail("Failed with state \(state)")
      }
    }.addTo(&observations)

    pairingStateMachine.didConnect(peripheral: peripheral)

    wait(
      for: [
        disconnectedStateExpectation, bluetoothConnectedExpectation,
        servicesDiscoveredExpectation, awaitingNotificationUpdatesExpectation,
        tagPairedExpectation,
      ],
      timeout: 1.0,
      enforceOrder: true
    )
  }

  func testVerifyDidFailToConnect() {
    let disconnectedStateExpectation = expectation(description: "DisconnectedStateExpectation")
    let failToConnectExpectation = expectation(description: "FailToConnectExpectation")

    let peripheral = FakePeripheralImplementation(identifier: uuid, name: deviceName)
    let pairingStateMachine = TagPairingStateMachine(peripheral: peripheral)
    pairingStateMachine.statePublisher.sink { state in
      switch state {
      case .disconnected:
        disconnectedStateExpectation.fulfill()
      case .error(let error):
        XCTAssertNotNil(error)
        XCTAssert(error is TagConnectionError)
        XCTAssert(state.isTerminal)
        failToConnectExpectation.fulfill()
      default:
        XCTFail("Failed with state \(state)")
      }
    }.addTo(&observations)

    pairingStateMachine.didFailToConnect(
      peripheral: peripheral,
      error: TagConnectionError.unknownCoreBluetoothError
    )

    wait(
      for: [disconnectedStateExpectation, failToConnectExpectation],
      timeout: 1.0,
      enforceOrder: true
    )
  }

  func testVerifyNoServicesFound() {
    let disconnectedStateExpectation = expectation(description: "DisconnectedStateExpectation")
    let bluetoothConnectedExpectation = expectation(description: "BluetoothConnectedExpectation")
    let noServiceFoundExpectation = expectation(description: "NoServiceFoundExpectation")

    let peripheral = FakePeripheralImplementation(identifier: uuid, name: deviceName)
    let pairingStateMachine = TagPairingStateMachine(peripheral: peripheral)
    pairingStateMachine.statePublisher.sink { state in
      switch state {
      case .disconnected:
        disconnectedStateExpectation.fulfill()
      case .bluetoothConnected:
        bluetoothConnectedExpectation.fulfill()
      case .error(let error):
        XCTAssertNotNil(error)
        XCTAssert(error is TagConnectionError)
        noServiceFoundExpectation.fulfill()
      default:
        XCTFail("Failed with state \(state)")
      }
    }.addTo(&observations)

    pairingStateMachine.didConnect(peripheral: peripheral)

    wait(
      for: [
        disconnectedStateExpectation, bluetoothConnectedExpectation, noServiceFoundExpectation,
      ],
      timeout: 1.0,
      enforceOrder: true
    )
  }

  func testVerifyNoCharacteristicsFound() {
    let disconnectedStateExpectation = expectation(description: "DisconnectedStateExpectation")
    let bluetoothConnectedExpectation = expectation(description: "BluetoothConnectedExpectation")
    let servicesDiscoveredExpectation = expectation(description: "ServicesDiscoveredExpectation")
    let noCharacteristicFoundExpectation = expectation(
      description: "NoCharacteristicFoundExpectation"
    )

    let peripheral = FakePeripheralImplementation(identifier: uuid, name: deviceName)
    let service = CBMutableService(type: JacquardServices.v2Service, primary: true)
    peripheral.services = [service]

    let pairingStateMachine = TagPairingStateMachine(peripheral: peripheral)
    pairingStateMachine.statePublisher.sink { state in
      switch state {
      case .disconnected:
        disconnectedStateExpectation.fulfill()
      case .bluetoothConnected:
        bluetoothConnectedExpectation.fulfill()
      case .servicesDiscovered:
        servicesDiscoveredExpectation.fulfill()
      case .error(let error):
        XCTAssertNotNil(error)
        XCTAssert(error is TagConnectionError)
        noCharacteristicFoundExpectation.fulfill()
      default:
        XCTFail("Failed with state \(state)")
      }
    }.addTo(&observations)

    pairingStateMachine.didConnect(peripheral: peripheral)

    wait(
      for: [
        disconnectedStateExpectation, bluetoothConnectedExpectation,
        servicesDiscoveredExpectation, noCharacteristicFoundExpectation,
      ],
      timeout: 1.0,
      enforceOrder: true)
  }

  func testVerifyAnotherPeripheralDidConnect() {
    let disconnectedStateExpectation = expectation(description: "DisconnectedStateExpectation")
    let anotherPeripheralConnectExpectation = expectation(
      description: "AnotherPeripheralConnectExpectation"
    )

    let assetExpectation = expectation(description: "assetExpectation")
    jqLogger = CatchLogger(expectation: assetExpectation)

    let peripheral = FakePeripheralImplementation(identifier: uuid, name: deviceName)
    let pairingStateMachine = TagPairingStateMachine(peripheral: peripheral)
    pairingStateMachine.statePublisher.sink { state in
      switch state {
      case .disconnected:
        disconnectedStateExpectation.fulfill()
      case .error(let error):
        XCTAssertNotNil(error)
        XCTAssert(error is TagConnectionError)
        anotherPeripheralConnectExpectation.fulfill()
      default:
        XCTFail("Failed with state \(state)")
      }
    }.addTo(&observations)

    let anotherFakePeripheral = FakePeripheralImplementation(
      identifier: UUID(uuidString: "BD415750-8EF1-43EE-8A7F-7EF1E365C35F")!,
      name: "Another device"
    )
    pairingStateMachine.didConnect(peripheral: anotherFakePeripheral)

    wait(
      for: [disconnectedStateExpectation, assetExpectation, anotherPeripheralConnectExpectation],
      timeout: 1.0,
      enforceOrder: true
    )
  }

  func testVerifyAnotherServiceDiscover() {
    let disconnectedStateExpectation = expectation(description: "DisconnectedStateExpectation")
    let bluetoothConnectedExpectation = expectation(description: "BluetoothConnectedExpectation")
    let anotherServicesDiscoveredExpectation = expectation(
      description: "AnotherServicesDiscoveredExpectation"
    )

    let peripheral = FakePeripheralImplementation(identifier: uuid, name: deviceName)

    let anotherService = CBMutableService(
      type: CBUUID(string: "D2F2BF0D-D165-445C-B0E1-2D6B642EC57C"),
      primary: true
    )
    peripheral.services = [anotherService]

    let pairingStateMachine = TagPairingStateMachine(peripheral: peripheral)
    pairingStateMachine.statePublisher.sink { state in
      switch state {
      case .disconnected:
        disconnectedStateExpectation.fulfill()
      case .bluetoothConnected:
        bluetoothConnectedExpectation.fulfill()
      case .error(let error):
        XCTAssertNotNil(error)
        XCTAssert(error is TagConnectionError)
        anotherServicesDiscoveredExpectation.fulfill()
      default:
        XCTFail("Failed with state \(state)")
      }
    }.addTo(&observations)

    pairingStateMachine.didConnect(peripheral: peripheral)

    wait(
      for: [
        disconnectedStateExpectation, bluetoothConnectedExpectation,
        anotherServicesDiscoveredExpectation,
      ],
      timeout: 1.0,
      enforceOrder: true
    )
  }

  func testVerifyAnotherCharacteristicDiscover() {
    let disconnectedStateExpectation = expectation(description: "DisconnectedStateExpectation")
    let bluetoothConnectedExpectation = expectation(description: "BluetoothConnectedExpectation")
    let servicesDiscoveredExpectation = expectation(description: "ServicesDiscoveredExpectation")
    let anotherCharacteristicFoundExpectation = expectation(
      description: "anotherCharacteristicFoundExpectation"
    )

    let peripheral = FakePeripheralImplementation(identifier: uuid, name: deviceName)

    let service = CBMutableService(type: JacquardServices.v2Service, primary: true)

    let unknownUUID = CBUUID(string: "D2F2B8D2-D165-445C-B0E1-2D6B642EC57B")
    let unknownCharacteristic = CBMutableCharacteristic(
      type: unknownUUID,
      properties: [.notify],
      value: nil,
      permissions: .readable
    )
    service.characteristics = [unknownCharacteristic]
    peripheral.services = [service]

    let pairingStateMachine = TagPairingStateMachine(peripheral: peripheral)
    pairingStateMachine.statePublisher.sink { state in
      switch state {
      case .disconnected:
        disconnectedStateExpectation.fulfill()
      case .bluetoothConnected:
        bluetoothConnectedExpectation.fulfill()
      case .servicesDiscovered:
        servicesDiscoveredExpectation.fulfill()
      case .error(let error):
        XCTAssertNotNil(error)
        XCTAssert(error is TagConnectionError)
        anotherCharacteristicFoundExpectation.fulfill()
      default:
        XCTFail("Failed with state \(state)")
      }
    }.addTo(&observations)

    pairingStateMachine.didConnect(peripheral: peripheral)

    wait(
      for: [
        disconnectedStateExpectation, bluetoothConnectedExpectation,
        servicesDiscoveredExpectation, anotherCharacteristicFoundExpectation,
      ],
      timeout: 1.0,
      enforceOrder: true
    )
  }

  func testVerifyNotifyStateError() {
    let disconnectedStateExpectation = expectation(description: "DisconnectedStateExpectation")
    let bluetoothConnectedExpectation = expectation(description: "BluetoothConnectedExpectation")
    let servicesDiscoveredExpectation = expectation(description: "ServicesDiscoveredExpectation")
    let awaitingNotificationUpdatesExpectation = expectation(
      description: "AwaitingNotificationUpdatesExpectation"
    )

    let notifyStateErrorExpectation = expectation(description: "NotifyStateErrorExpectation")
    notifyStateErrorExpectation.expectedFulfillmentCount = 3

    let peripheral = FakePeripheralImplementation(identifier: uuid, name: deviceName)

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
    peripheral.services = [service]
    peripheral.notifyStateError = TagConnectionError.internalError

    let pairingStateMachine = TagPairingStateMachine(peripheral: peripheral)
    pairingStateMachine.statePublisher.sink { state in
      switch state {
      case .disconnected:
        disconnectedStateExpectation.fulfill()
      case .bluetoothConnected:
        bluetoothConnectedExpectation.fulfill()
      case .servicesDiscovered:
        servicesDiscoveredExpectation.fulfill()
      case .awaitingNotificationUpdates:
        awaitingNotificationUpdatesExpectation.fulfill()
      case .error(let error):
        // Notify updates is called 2 times for response & notify characteristic. So error comes 2
        // times.
        XCTAssertNotNil(error)
        XCTAssert(error is TagConnectionError)
        notifyStateErrorExpectation.fulfill()
      default:
        XCTFail("Failed with state \(state)")
      }
    }.addTo(&observations)

    pairingStateMachine.didConnect(peripheral: peripheral)

    wait(
      for: [
        disconnectedStateExpectation, bluetoothConnectedExpectation,
        servicesDiscoveredExpectation, awaitingNotificationUpdatesExpectation,
        notifyStateErrorExpectation,
      ],
      timeout: 1.0,
      enforceOrder: true
    )
  }
}
