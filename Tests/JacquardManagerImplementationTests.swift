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

final class JacquardManagerImplementationTests: XCTestCase {

  struct CatchLogger: Logger {
    func log(level: LogLevel, file: String, line: Int, function: String, message: () -> String) {
      let _ = message()
      if level == .preconditionFailure {
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

  private var commandCharacteristic: FakeCharacteristic {
    let commandUUID = CBUUID(string: "D2F2EABB-D165-445C-B0E1-2D6B642EC57B")
    return FakeCharacteristic(uuid: commandUUID, value: nil)
  }

  private var responseCharacteristic: FakeCharacteristic {
    let responseUUID = CBUUID(string: "D2F2B8D0-D165-445C-B0E1-2D6B642EC57B")
    return FakeCharacteristic(uuid: responseUUID, value: nil)
  }

  private var notifyCharacteristic: FakeCharacteristic {
    let notifyUUID = CBUUID(string: "D2F2B8D1-D165-445C-B0E1-2D6B642EC57B")
    return FakeCharacteristic(uuid: notifyUUID, value: nil)
  }

  private var rawDataCharacteristic: FakeCharacteristic {
    let rawDataUUID = CBUUID(string: "D2F2B8D2-D165-445C-B0E1-2D6B642EC57B")
    return FakeCharacteristic(uuid: rawDataUUID, value: nil)
  }

  private lazy var requiredCharacteristics = RequiredCharacteristics(
    commandCharacteristic: commandCharacteristic,
    responseCharacteristic: responseCharacteristic,
    notifyCharacteristic: notifyCharacteristic,
    rawDataCharacteristic: rawDataCharacteristic
  )

  var observations = [Cancellable]()
  var centralManager: FakeCentralManager?

  func testVerifyPublicJacquardManagerInitializer() throws {
    throw XCTSkip("Test is flaky b/204123001")
    
    let publicInitializerExpectation = expectation(description: "publicInitializerExpectation")
    publicInitializerExpectation.expectedFulfillmentCount = 2

    let jqm = JacquardManagerImplementation()
    jqm.centralState.sink { (state) in
      switch state {
      case .unsupported:
        // Public initializer does not support bluetooth device as Simulator.
        publicInitializerExpectation.fulfill()
      case .unknown:
        // Initial value.
        publicInitializerExpectation.fulfill()
      default:
        XCTFail("Unexpected bluetooth state \(state.rawValue)")
      }
    }.addTo(&observations)
    wait(for: [publicInitializerExpectation], timeout: 1.0)
  }

  func testVerifyBluetoothtPowerStateCallback() {
    let stateExpectation = expectation(description: "StateExpectation")
    // Count 2 is required because centralState is a CurrentValueSubject which publish initial value
    // immediately. Second count is required when user made any changes to the state.
    stateExpectation.expectedFulfillmentCount = 2

    let queue: DispatchQueue = .main
    let jqm = JacquardManagerImplementation(publishQueue: queue, config: config) { delegate in
      centralManager = FakeCentralManager(delegate: delegate, queue: queue, options: nil)
      return centralManager!
    }

    jqm.centralState.sink { (state) in
      switch state {
      case .poweredOn:
        stateExpectation.fulfill()
      case .unknown:
        stateExpectation.fulfill()
      default:
        XCTFail("Unexpected bluetooth state \(state.rawValue)")
      }
    }.addTo(&observations)

    XCTAssertEqual(centralManager?.delegate as? JacquardManagerImplementation, jqm)

    centralManager?.state = .poweredOn

    wait(for: [stateExpectation], timeout: 1.0)
  }

  func testVerifyStartScanWhenBuetoothPowerOff() {
    let stateExpectation = expectation(description: "StateExpectation")
    stateExpectation.expectedFulfillmentCount = 2
    let startScanThrowsExpectation = expectation(description: "startScanThrowsExpectation")

    let queue: DispatchQueue = .main
    let jqm = JacquardManagerImplementation(publishQueue: queue, config: config) { delegate in
      centralManager = FakeCentralManager(delegate: delegate, queue: queue, options: nil)
      return centralManager!
    }

    jqm.centralState.sink { (state) in
      stateExpectation.fulfill()
    }.addTo(&observations)

    centralManager?.state = .poweredOff
    wait(for: [stateExpectation], timeout: 1.0)

    XCTAssertThrowsError(try jqm.startScanning()) { error in
      XCTAssertNotNil(error as? ManagerScanningError)
      switch error as? ManagerScanningError {
      case .bluetoothUnavailable(let state):
        XCTAssertEqual(state, .poweredOff)
        startScanThrowsExpectation.fulfill()
      case .none:
        XCTFail("Switch case with error \(error) state should not executed.")
      }
    }

    wait(for: [startScanThrowsExpectation], timeout: 1.0)
  }

  func testVerifyStartScanWhenBuetoothPowerOn() throws {
    let stateExpectation = expectation(description: "StateExpectation")
    stateExpectation.expectedFulfillmentCount = 2
    let startScanExpectation = expectation(description: "startScanExpectation")

    let queue: DispatchQueue = .main
    let jqm = JacquardManagerImplementation(publishQueue: queue, config: config) { delegate in
      centralManager = FakeCentralManager(delegate: delegate, queue: queue, options: nil)
      return centralManager!
    }

    jqm.centralState.sink { (_) in
      stateExpectation.fulfill()
    }.addTo(&observations)

    centralManager?.state = .poweredOn
    wait(for: [stateExpectation], timeout: 1.0)

    jqm.advertisingTags.sink { (tag) in
      XCTAssertEqual(tag.displayName, "003R")
      XCTAssertEqual(tag.pairingSerialNumber, "003R")
      startScanExpectation.fulfill()
    }.addTo(&observations)

    try jqm.startScanning()

    wait(for: [startScanExpectation], timeout: 1.0)
  }

  func testVerifyStopScan() {
    let stopScanExpectation = expectation(description: "stopScanExpectation")
    let queue: DispatchQueue = .main
    let jqm = JacquardManagerImplementation(publishQueue: queue, config: config) { delegate in
      centralManager = FakeCentralManager(delegate: delegate, queue: queue, options: nil)
      return centralManager!
    }

    centralManager?.stopScanCompletion = { stop in
      XCTAssert(stop)
      stopScanExpectation.fulfill()
    }
    jqm.stopScanning()
    wait(for: [stopScanExpectation], timeout: 1.0)
  }

  func testVerifyPreConnectedTags() {
    let queue: DispatchQueue = .main
    let jqm = JacquardManagerImplementation(publishQueue: queue, config: config) { delegate in
      centralManager = FakeCentralManager(delegate: delegate, queue: queue, options: nil)
      return centralManager!
    }
    let tags = jqm.preConnectedTags()
    XCTAssertEqual(tags.count, 1)
    XCTAssertEqual(tags[0].displayName, "Fake Device")
  }

  func testVerifyPeripheralNotFoundForConnect() {
    let peripheralNotFoundExpectation = expectation(description: "peripheralNotFoundExpectation")
    let queue: DispatchQueue = .main
    let jqm = JacquardManagerImplementation(publishQueue: queue, config: config) { delegate in
      centralManager = FakeCentralManager(delegate: delegate, queue: queue, options: nil)
      return centralManager!
    }

    jqm.connect(UUID(uuidString: "BD415750-8EF1-43EE-8A7F-7EF1E365C35F")!).sink { error in
      if case .failure(let error) = error {
        XCTAssertNotNil(error as? TagConnectionError)
        switch error as? TagConnectionError {
        case .bluetoothDeviceNotFound:
          peripheralNotFoundExpectation.fulfill()
        default:
          XCTFail("Unexpected tag connection error \(error) received.")
        }
      } else {
        XCTFail("Tag connection state success should not received.")
      }
    } receiveValue: { state in
      XCTFail("Tag connection state should not received.")
    }.addTo(&observations)

    wait(for: [peripheralNotFoundExpectation], timeout: 1.0)
  }

  func testVerifyConnectWithPeripheralUsingIdentifier() {
    let stateExpectation = expectation(description: "StateExpectation")
    let peripheralConnectExpectation = expectation(description: "peripheralConnectExpectation")

    let queue: DispatchQueue = .main
    let jqm = JacquardManagerImplementation(publishQueue: queue, config: config) { delegate in
      centralManager = FakeCentralManager(delegate: delegate, queue: queue, options: nil)
      return centralManager!
    }

    jqm.centralState.sink { state in
      switch state {
      case .poweredOn:
        stateExpectation.fulfill()
      default:
        break
      }
    }.addTo(&observations)

    centralManager?.state = .poweredOn
    wait(for: [stateExpectation], timeout: 1.0)

    // setNotifyFor:Characteristics called for 3 characteristics.
    var characteristicCounter = 3

    centralManager?.peripheral.completionHandler = { peripheral, callbackType in
      switch callbackType {
      case .didDiscoverServices:
        peripheral.callbackType = .didDiscoverCharacteristics
      case .didDiscoverCharacteristics:
        peripheral.callbackType = .didUpdateNotificationState
      case .didUpdateNotificationState:
        if characteristicCounter == 1 {
          peripheral.callbackType = .didWriteValue(.helloCommand)
        } else {
          characteristicCounter -= 1
        }
      case .didWriteValue(let responseType):
        peripheral.callbackType = .didUpdateValue(responseType)
        if responseType == .helloCommand {
          peripheral.postUpdateForHelloCommandResponse()
        } else if responseType == .beginCommand {
          peripheral.postUpdateForBeginCommandResponse()
        } else if responseType == .componentInfoCommand {
          peripheral.postUpdateForComponentInfoResponse()
        }
      case .didUpdateValue(let responseType):
        if responseType == .helloCommand {
          peripheral.callbackType = .didWriteValue(.beginCommand)
        } else if responseType == .beginCommand {
          peripheral.callbackType = .didWriteValue(.componentInfoCommand)
        }
      default:
        break
      }
    }

    jqm.connect(centralManager!.uuid).sink { error in
      XCTFail("Tag connection error \(error) should not received.")
    } receiveValue: { state in
      switch state {
      case .connected(let tag):
        XCTAssertEqual(tag.name, "Fake Device")
        XCTAssertNotNil(tag.tagComponent.product)
        XCTAssertNotNil(tag.tagComponent.vendor)
        XCTAssertEqual(tag.tagComponent.product.name, TagConstants.product)
        XCTAssertEqual(tag.tagComponent.vendor.name, FakePeripheralImplementation.tagVendorName)
        XCTAssertEqual(tag.tagComponent.version, FakePeripheralImplementation.tagVersion)
        XCTAssertEqual(tag.tagComponent.uuid, FakePeripheralImplementation.tagUUID)

        peripheralConnectExpectation.fulfill()
      default:
        break
      }
    }.addTo(&observations)
    wait(for: [peripheralConnectExpectation], timeout: 5.0)
  }

  func testVerifyPeripheralNotFoundForDisconnect() {
    let peripheralNotFoundExpectation = expectation(description: "peripheralNotFoundExpectation")
    let queue: DispatchQueue = .main
    let jqm = JacquardManagerImplementation(publishQueue: queue, config: config) { delegate in
      centralManager = FakeCentralManager(delegate: delegate, queue: queue, options: nil)
      return centralManager!
    }
    let notFoundUUID = UUID(uuidString: "BD415750-8EF1-43EE-8A7F-7EF1E365C35F")!
    let transport = TransportV2Implementation(
      peripheral: FakePeripheralImplementation(identifier: notFoundUUID, name: "Fake device"),
      characteristics: requiredCharacteristics
    )
    let connectedTag = ConnectedTagModel(
      transport: transport,
      userPublishQueue: .main,
      tagComponent: FakeConnectedTag(transport: FakeTransport()).tagComponent,
      sdkConfig: config
    )

    jqm.disconnect(connectedTag).sink { error in
      if case .failure(let error) = error {
        XCTAssertNotNil(error as? TagConnectionError)
        switch error as? TagConnectionError {
        case .bluetoothDeviceNotFound:
          peripheralNotFoundExpectation.fulfill()
        default:
          XCTFail("Unexpected tag disconnection error \(error) received.")
        }
      } else {
        XCTFail("Tag connection state success should not received.")
      }
    } receiveValue: { state in
      XCTFail("Tag connection state should not received.")
    }.addTo(&observations)

    wait(for: [peripheralNotFoundExpectation], timeout: 1.0)
  }

  func testVerifyDisconnectPeripheralUsingTag() {
    let stateExpectation = expectation(description: "StateExpectation")
    stateExpectation.expectedFulfillmentCount = 2

    let peripheralConnectExpectation = expectation(description: "peripheralConnectExpectation")
    let queue: DispatchQueue = .main
    let jqm = JacquardManagerImplementation(publishQueue: queue, config: config) { delegate in
      centralManager = FakeCentralManager(delegate: delegate, queue: queue, options: nil)
      return centralManager!
    }

    jqm.centralState.sink { (_) in
      stateExpectation.fulfill()
    }.addTo(&observations)

    centralManager?.state = .poweredOn
    wait(for: [stateExpectation], timeout: 1.0)

    // setNotifyFor:Characteristics called for 2 characteristics.
    var characteristicCounter = 2

    centralManager?.peripheral.completionHandler = { peripheral, callbackType in
      switch callbackType {
      case .didDiscoverServices:
        peripheral.callbackType = .didDiscoverCharacteristics
      case .didDiscoverCharacteristics:
        peripheral.callbackType = .didUpdateNotificationState
      case .didUpdateNotificationState:
        if characteristicCounter == 1 {
          peripheral.callbackType = .didWriteValue(.helloCommand)
        } else {
          characteristicCounter -= 1
        }
      case .didWriteValue(let responseType):
        peripheral.callbackType = .didUpdateValue(responseType)
        if responseType == .helloCommand {
          peripheral.postUpdateForHelloCommandResponse()
        } else if responseType == .beginCommand {
          peripheral.postUpdateForBeginCommandResponse()
        } else if responseType == .componentInfoCommand {
          peripheral.postUpdateForComponentInfoResponse()
        }
      case .didUpdateValue(let responseType):
        if responseType == .helloCommand {
          peripheral.callbackType = .didWriteValue(.beginCommand)
        } else if responseType == .beginCommand {
          peripheral.callbackType = .didWriteValue(.componentInfoCommand)
        }
      default:
        break
      }
    }

    jqm.connect(centralManager!.uuid).sink { error in
      XCTFail("Tag connection error \(error) should not received.")
    } receiveValue: { state in
      switch state {
      case .connected(let tag):
        XCTAssertEqual(tag.name, "Fake Device")
        XCTAssertNotNil(tag.tagComponent.product)
        XCTAssertNotNil(tag.tagComponent.vendor)
        XCTAssertEqual(tag.tagComponent.product.name, TagConstants.product)
        XCTAssertEqual(tag.tagComponent.vendor.name, FakePeripheralImplementation.tagVendorName)
        peripheralConnectExpectation.fulfill()
      default:
        break
      }
    }.addTo(&observations)
    wait(for: [peripheralConnectExpectation], timeout: 5.0)

    let peripheralDisconnectExpectation = expectation(
      description: "peripheralDisconnectExpectation"
    )

    let transport = TransportV2Implementation(
      peripheral: centralManager!.peripheral,
      characteristics: requiredCharacteristics
    )

    let connectedTag = ConnectedTagModel(
      transport: transport,
      userPublishQueue: .main,
      tagComponent: FakeConnectedTag(transport: FakeTransport()).tagComponent,
      sdkConfig: config
    )
    jqm.disconnect(connectedTag).sink { error in
      XCTFail("Tag connection error \(error) should not received.")
    } receiveValue: { state in
      switch state {
      case .disconnected(let error):
        XCTAssertNil(error)
        peripheralDisconnectExpectation.fulfill()
      default:
        break
      }
    }.addTo(&observations)

    wait(for: [peripheralDisconnectExpectation], timeout: 1.0)
  }

  func testVerifyDisconnectPeripheralBeforeConnect() {
    let queue: DispatchQueue = .main
    let jqm = JacquardManagerImplementation(publishQueue: queue, config: config) { delegate in
      centralManager = FakeCentralManager(delegate: delegate, queue: queue, options: nil)
      return centralManager!
    }
    JacquardManagerImplementation.clearConnectionStateMachine(
      for: centralManager!.peripheral.identifier
    )
    let disconnectPeripheralBeforeConnectExpectation = expectation(
      description: "DisconnectPeripheralBeforeConnectExpectation"
    )
    jqLogger = CatchLogger(expectation: disconnectPeripheralBeforeConnectExpectation)
    let peripheralDisconnectExpectation = expectation(
      description: "peripheralDisconnectExpectation"
    )
    let transport = TransportV2Implementation(
      peripheral: centralManager!.peripheral,
      characteristics: requiredCharacteristics
    )

    let connectedTag = ConnectedTagModel(
      transport: transport,
      userPublishQueue: .main,
      tagComponent: FakeConnectedTag(transport: FakeTransport()).tagComponent,
      sdkConfig: config
    )
    jqm.disconnect(connectedTag).sink { error in
      XCTAssertNotNil(error)
      peripheralDisconnectExpectation.fulfill()
    } receiveValue: { _ in
      XCTFail("State callback should not received.")
    }.addTo(&observations)

    wait(
      for: [disconnectPeripheralBeforeConnectExpectation, peripheralDisconnectExpectation],
      timeout: 1.0
    )
  }

  func testVerifyConnectWithPeripheralUsingTag() {
    let stateExpectation = expectation(description: "StateExpectation")
    stateExpectation.expectedFulfillmentCount = 2

    let peripheralConnectExpectation = expectation(description: "peripheralConnectExpectation")
    let queue: DispatchQueue = .main
    let jqm = JacquardManagerImplementation(publishQueue: queue, config: config) { delegate in
      centralManager = FakeCentralManager(delegate: delegate, queue: queue, options: nil)
      return centralManager!
    }

    jqm.centralState.sink { (_) in
      stateExpectation.fulfill()
    }.addTo(&observations)

    centralManager?.state = .poweredOn
    wait(for: [stateExpectation], timeout: 1.0)

    // setNotifyFor:Characteristics called for 2 characteristics.
    var characteristicCounter = 2
    centralManager?.peripheral.completionHandler = { peripheral, callbackType in
      switch callbackType {
      case .didDiscoverServices:
        peripheral.callbackType = .didDiscoverCharacteristics
      case .didDiscoverCharacteristics:
        peripheral.callbackType = .didUpdateNotificationState
      case .didUpdateNotificationState:
        if characteristicCounter == 1 {
          peripheral.callbackType = .didWriteValue(.helloCommand)
        } else {
          characteristicCounter -= 1
        }
      case .didWriteValue(let responseType):
        peripheral.callbackType = .didUpdateValue(responseType)
        if responseType == .helloCommand {
          peripheral.postUpdateForHelloCommandResponse()
        } else if responseType == .beginCommand {
          peripheral.postUpdateForBeginCommandResponse()
        } else if responseType == .componentInfoCommand {
          peripheral.postUpdateForComponentInfoResponse()
        }
      case .didUpdateValue(let responseType):
        if responseType == .helloCommand {
          peripheral.callbackType = .didWriteValue(.beginCommand)
        } else if responseType == .beginCommand {
          peripheral.callbackType = .didWriteValue(.componentInfoCommand)
        }
      default:
        break
      }
    }

    let preConnectedTag = PreConnectedTagModel(peripheral: centralManager!.peripheral)
    jqm.connect(preConnectedTag).sink { (error) in
      XCTFail("Tag connection error \(error) should not received.")
    } receiveValue: { (state) in
      switch state {
      case .connected(let tag):
        XCTAssertEqual(tag.name, "Fake Device")
        XCTAssertNotNil(tag.tagComponent.product)
        XCTAssertNotNil(tag.tagComponent.vendor)
        XCTAssertEqual(tag.tagComponent.product.name, TagConstants.product)
        XCTAssertEqual(tag.tagComponent.vendor.name, FakePeripheralImplementation.tagVendorName)
        peripheralConnectExpectation.fulfill()
      default:
        break
      }
    }.addTo(&observations)

    wait(for: [peripheralConnectExpectation], timeout: 5.0)
  }

  func testVerifyConnectWithPeripheralUsingTagFailure() {
    let peripheralConnectFailureExpectation = expectation(
      description: "PeripheralConnectFailureExpectation"
    )

    let queue: DispatchQueue = .main
    let jqm = JacquardManagerImplementation(publishQueue: queue, config: config) { delegate in
      centralManager = FakeCentralManager(delegate: delegate, queue: queue, options: nil)
      return centralManager!
    }

    struct FakeAdvertisedTag: AdvertisedTag {
      var rssi: Float = -72.0
      var pairingSerialNumber = "FakePairingSerialNumber"
      var identifier = UUID()
    }

    jqm.connect(FakeAdvertisedTag()).sink { error in
      XCTAssertNotNil(error)
      if case .failure(let err) = error {
        switch err as? TagConnectionError {
        case .unconnectableTag:
          peripheralConnectFailureExpectation.fulfill()
        default:
          XCTFail("Error \(error) not expected.")
        }
      } else {
        XCTFail("Unexpected error type \(error)")
      }
    } receiveValue: { _ in
      XCTFail("State closure should not executed.")
    }.addTo(&observations)

    wait(for: [peripheralConnectFailureExpectation], timeout: 1.0)
  }
}
