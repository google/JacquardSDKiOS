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

final class ConnectedTagModelTests: XCTestCase {

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

  private let disconnectCommandSuccessResponse = Data([192, 6, 8, 2, 16, 0, 24, 0])
  private let commandFailureResponse = Data([192, 9, 8, 1, 16, 2, 24, 0, 234, 68, 0])

  private let nameConfigWriteCommandSuccessResponse = Data(
    [
      192, 56, 8, 1, 16, 0, 24, 0, 234, 68, 47, 18, 45, 10, 9, 84, 101, 115, 116, 32, 110, 97,
      109, 101, 16, 244, 255, 255, 255, 255, 255, 255, 255, 255, 1, 24, 0, 37, 0, 0,
      160, 65, 40, 60, 53, 0, 160, 160, 68, 56, 60, 64, 6, 72, 144, 3, 80, 14,
    ]
  )

  private let dataChannelUpdateSuccessResponse = Data(
    [
      192, 48, 8, 6, 16, 0, 24, 6, 218, 56, 39, 8, 0, 16, 1, 26, 33, 10, 6, 8, 15, 16, 32, 24,
      8, 10, 6, 8, 13, 16, 8, 24, 11, 18, 13, 6, 0, 1, 1, 2, 2, 2, 3, 3, 7, 5, 9, 9, 24, 1,
    ]
  )

  private let notificationQueueDepthSetSuccessResponse = Data(
    [
      192, 50, 8, 7, 16, 0, 24, 0, 234, 68, 41, 18, 39, 10, 3, 97, 97, 97, 16, 244, 255, 255,
      255, 255, 255, 255, 255, 255, 1, 24, 0, 37, 0, 0, 160, 65, 40, 60, 53, 0, 160, 160, 68,
      56, 60, 64, 6, 72, 144, 3, 80, 2,
    ]
  )

  private let uuid = UUID(uuidString: "BD415750-8EF1-43EE-8A7F-7EF1E365C35E")!
  private let deviceName = "Fake Device"
  private var observers = [Cancellable]()

  private let yslGearData = FakeComponentHelper.gearData(
    vendorID: "fb-57-a1-12", productID: "5c-d8-78-b0")

  private let yslGearCapabilities = FakeComponentHelper.capabilities(
    vendorID: "fb-57-a1-12", productID: "5c-d8-78-b0")

  private lazy var fakeGearComponent = FakeGearComponent(
    componentID: 1,
    vendor: yslGearData.vendor,
    product: yslGearData.product,
    isAttached: true)

  func testName() {
    let peripheral = FakePeripheralImplementation(identifier: uuid, name: deviceName)
    let transport = TransportV2Implementation(
      peripheral: peripheral,
      characteristics: requiredCharacteristics
    )
    let connectedTag = ConnectedTagModel(
      transport: transport,
      userPublishQueue: .main,
      tagComponent: FakeConnectedTag(transport: FakeTransport()).tagComponent,
      sdkConfig: config
    )

    // Test name.
    XCTAssertEqual(connectedTag.name, deviceName)

    // Test namePublisher.
    let e = expectation(description: "Waiting for name")
    connectedTag.namePublisher.sink { name in
      XCTAssertEqual(name, self.deviceName)
      e.fulfill()
    }.addTo(&observers)
    wait(for: [e], timeout: 1)
  }

  func testRSSI() {
    let peripheral = FakePeripheralImplementation(identifier: uuid, name: deviceName)
    let transport = TransportV2Implementation(
      peripheral: peripheral,
      characteristics: requiredCharacteristics
    )
    let connectedTag = ConnectedTagModel(
      transport: transport,
      userPublishQueue: .main,
      tagComponent: FakeConnectedTag(transport: FakeTransport()).tagComponent,
      sdkConfig: config
    )
    // Test rssiPublisher.
    let e = expectation(description: "Waiting for rssi")
    connectedTag.rssiPublisher.sink { rssiValue in
      XCTAssertEqual(rssiValue, -72.0)
      e.fulfill()
    }.addTo(&observers)
    connectedTag.readRSSI()
    wait(for: [e], timeout: 1)
  }

  func testIdentifier() {
    let peripheral = FakePeripheralImplementation(identifier: uuid, name: deviceName)
    let transport = TransportV2Implementation(
      peripheral: peripheral,
      characteristics: requiredCharacteristics
    )
    let connectedTag = ConnectedTagModel(
      transport: transport,
      userPublishQueue: .main,
      tagComponent: FakeConnectedTag(transport: FakeTransport()).tagComponent,
      sdkConfig: config
    )
    XCTAssertEqual(connectedTag.identifier, uuid)
  }

  func testTagComponent() {
    let peripheral = FakePeripheralImplementation(identifier: uuid, name: deviceName)
    let transport = TransportV2Implementation(
      peripheral: peripheral,
      characteristics: requiredCharacteristics
    )
    let connectedTag = ConnectedTagModel(
      transport: transport,
      userPublishQueue: .main,
      tagComponent: FakeConnectedTag(transport: FakeTransport()).tagComponent,
      sdkConfig: config
    )
    let component = connectedTag.tagComponent
    XCTAssertEqual(component.componentID, TagConstants.FixedComponent.tag.rawValue)
    XCTAssertEqual(component.vendor.id, TagConstants.vendor)
    XCTAssertEqual(component.vendor.name, TagConstants.vendor)
    XCTAssertEqual(component.capabilities, [.led])
  }

  func testSetNameSuccess() throws {
    let peripheral = FakePeripheralImplementation(identifier: uuid, name: deviceName)
    let transport = TransportV2Implementation(
      peripheral: peripheral,
      characteristics: requiredCharacteristics
    )
    let connectedTag = ConnectedTagModel(
      transport: transport,
      userPublishQueue: .main,
      tagComponent: FakeConnectedTag(transport: FakeTransport()).tagComponent,
      sdkConfig: config
    )
    let setNameExpectation = expectation(description: "setNameExpectation")
    let nameConfigWriteExpectation = expectation(description: "nameConfigWriteExpectation")

    let customName = "Test name"
    let transportState = JacquardTransportState()

    // Construct config write request for setting the custom name.
    var config = Google_Jacquard_Protocol_BleConfiguration()
    config.customAdvName = customName
    let configWriteRequest = UJTWriteConfigCommand(config: config)

    // Modify the original request by adding the id for it.
    var request = configWriteRequest.request
    request.id = transportState.nextRequestId()

    // Form the expected data to be written on the peripheral.
    var expectedData: Data
    var packet = try request.serializedData(partial: false)
    expectedData = transportState.commandFragmenter.fragments(fromPacket: packet).first!

    peripheral.writeValueHandler = { data, characteristic, type in

      // Validate the config write request received on the peripheral.
      XCTAssertEqual(data, expectedData, "Received wrong request for renaming the tag.")
      XCTAssertEqual(
        characteristic.uuid,
        self.commandCharacteristic.uuid,
        "Name config set on the wrong characteristic.")
      XCTAssertEqual(type, .withoutResponse, "Received wrong request type.")

      // Create the response characteristic with config write success data.
      let response = FakeCharacteristic(responseValue: self.nameConfigWriteCommandSuccessResponse)
      peripheral.delegate?.peripheral(peripheral, didUpdateValueFor: response, error: nil)

      nameConfigWriteExpectation.fulfill()
    }

    // Call the setName API.
    try connectedTag.setName(customName).sink { (error) in
      XCTFail("Renaming tag failed with error: \(error)")
    } receiveValue: { (_) in
      setNameExpectation.fulfill()
    }.addTo(&observers)

    wait(for: [nameConfigWriteExpectation], timeout: 0.5)

    let disconnectTagExpectation = expectation(description: "disconnectTagExpectation")

    // Construct the disconnect request to make tag reboot and reflect the custom name set.
    let disconnectTagRequest = DisconnectTagCommand()

    // Modify the original request by adding the id for it.
    request = disconnectTagRequest.request
    request.id = transportState.nextRequestId()

    // Form the expected data to be written on the peripheral.
    packet = try request.serializedData(partial: false)
    expectedData = transportState.commandFragmenter.fragments(fromPacket: packet).first!

    peripheral.writeValueHandler = { data, characteristic, type in

      // Validate the disconnect request received on the peripheral.
      XCTAssertEqual(data, expectedData, "Received wrong request.")
      XCTAssertEqual(
        characteristic.uuid,
        self.commandCharacteristic.uuid,
        "Disconnect request made on the wrong characteristic")
      XCTAssertEqual(type, .withoutResponse, "Received wrong request type.")

      // Create the response characteristic with disconnect success data.
      let response = FakeCharacteristic(responseValue: self.disconnectCommandSuccessResponse)
      peripheral.delegate?.peripheral(peripheral, didUpdateValueFor: response, error: nil)

      disconnectTagExpectation.fulfill()
    }

    wait(for: [disconnectTagExpectation, setNameExpectation], timeout: 0.5, enforceOrder: true)
  }

  func testSetNameFailureDueToConfigWriteFailure() throws {
    let peripheral = FakePeripheralImplementation(identifier: uuid, name: deviceName)
    let transport = TransportV2Implementation(
      peripheral: peripheral,
      characteristics: requiredCharacteristics
    )
    let connectedTag = ConnectedTagModel(
      transport: transport,
      userPublishQueue: .main,
      tagComponent: FakeConnectedTag(transport: FakeTransport()).tagComponent,
      sdkConfig: config
    )
    let setNameExpectation = expectation(description: "setNameExpectation")
    let nameConfigWriteExpectation = expectation(description: "nameConfigWriteExpectation")

    let customName = "Test name"

    peripheral.writeValueHandler = { _, _, _ in

      // Create the response characteristic with config write failure data.
      let response = FakeCharacteristic(responseValue: self.commandFailureResponse)
      peripheral.delegate?.peripheral(peripheral, didUpdateValueFor: response, error: nil)

      nameConfigWriteExpectation.fulfill()
    }

    // Call the setName API.
    try connectedTag.setName(customName).sink { (error) in
      XCTAssertNotNil(error, "Error is expected.")
      setNameExpectation.fulfill()
    } receiveValue: { (_) in
      XCTFail("Rename tag success is not expected.")
    }.addTo(&observers)

    wait(for: [nameConfigWriteExpectation, setNameExpectation], timeout: 0.5, enforceOrder: true)
  }

  func testSetNameFailureDueToDisconnectCommandFailure() throws {
    let peripheral = FakePeripheralImplementation(identifier: uuid, name: deviceName)
    let transport = TransportV2Implementation(
      peripheral: peripheral,
      characteristics: requiredCharacteristics
    )
    let connectedTag = ConnectedTagModel(
      transport: transport,
      userPublishQueue: .main,
      tagComponent: FakeConnectedTag(transport: FakeTransport()).tagComponent,
      sdkConfig: config
    )
    let setNameExpectation = expectation(description: "setNameExpectation")
    let nameConfigWriteExpectation = expectation(description: "nameConfigWriteExpectation")

    let customName = "Test name"

    peripheral.writeValueHandler = { _, _, _ in

      // Create the response characteristic with config write success data.
      let response = FakeCharacteristic(responseValue: self.nameConfigWriteCommandSuccessResponse)
      peripheral.delegate?.peripheral(peripheral, didUpdateValueFor: response, error: nil)

      nameConfigWriteExpectation.fulfill()
    }

    // Call the setName API.
    try connectedTag.setName(customName).sink { (error) in
      XCTAssertNotNil(error, "Error is expected.")
      setNameExpectation.fulfill()
    } receiveValue: { (_) in
      XCTFail("Rename tag success is not expected.")
    }.addTo(&observers)

    wait(for: [nameConfigWriteExpectation], timeout: 0.5)

    let disconnectTagExpectation = expectation(description: "disconnectTagExpectation")

    peripheral.writeValueHandler = { _, _, _ in

      // Create the response characteristic with disconnect request failure data.
      let response = FakeCharacteristic(responseValue: self.commandFailureResponse)
      peripheral.delegate?.peripheral(peripheral, didUpdateValueFor: response, error: nil)

      disconnectTagExpectation.fulfill()
    }

    wait(for: [disconnectTagExpectation, setNameExpectation], timeout: 0.5, enforceOrder: true)
  }

  func testSetNameFailureForEmptyString() {
    let peripheral = FakePeripheralImplementation(identifier: uuid, name: deviceName)
    let transport = TransportV2Implementation(
      peripheral: peripheral,
      characteristics: requiredCharacteristics
    )
    let connectedTag = ConnectedTagModel(
      transport: transport,
      userPublishQueue: .main,
      tagComponent: FakeConnectedTag(transport: FakeTransport()).tagComponent,
      sdkConfig: config
    )
    // Try to set an empty string.
    let customName = ""

    // Call the setName API.
    do {
      let _ = try connectedTag.setName(customName)
    } catch (let error) {
      guard let setNameError = error as? SetNameError else {
        XCTFail("Unexpected error returned from setName API.")
        return
      }
      XCTAssertEqual(setNameError, SetNameError.invalidParameter)
    }
  }

  func testSetNameFailureForSameString() {
    let peripheral = FakePeripheralImplementation(identifier: uuid, name: deviceName)
    let transport = TransportV2Implementation(
      peripheral: peripheral,
      characteristics: requiredCharacteristics
    )
    let connectedTag = ConnectedTagModel(
      transport: transport,
      userPublishQueue: .main,
      tagComponent: FakeConnectedTag(transport: FakeTransport()).tagComponent,
      sdkConfig: config
    )
    // Try to set the same name as existing one.
    let customName = deviceName

    // Call the setName API.
    do {
      let _ = try connectedTag.setName(customName)
    } catch (let error) {
      guard let setNameError = error as? SetNameError else {
        XCTFail("Unexpected error returned from setName API.")
        return
      }
      XCTAssertEqual(setNameError, SetNameError.invalidParameter)
    }
  }

  func testSetNameFailureForStringLongerThan22Characters() {
    let peripheral = FakePeripheralImplementation(identifier: uuid, name: deviceName)
    let transport = TransportV2Implementation(
      peripheral: peripheral,
      characteristics: requiredCharacteristics
    )
    let connectedTag = ConnectedTagModel(
      transport: transport,
      userPublishQueue: .main,
      tagComponent: FakeConnectedTag(transport: FakeTransport()).tagComponent,
      sdkConfig: config
    )
    // Try to set the name having more than 21 characters.
    let customName = "qwertyuiopasdfghjklzxcvbnm"

    // Call the setName API.
    do {
      let _ = try connectedTag.setName(customName)
    } catch (let error) {
      guard let setNameError = error as? SetNameError else {
        XCTFail("Unexpected error returned from setName API.")
        return
      }
      XCTAssertEqual(setNameError, SetNameError.invalidParameter)
    }
  }

  func testGestureTouchModeSetSuccess() throws {
    try assertSuccessForSetTouchMode(.gesture)
  }

  func testContinuousTouchModeSetSuccess() throws {
    try assertSuccessForSetTouchMode(.continuous)
  }

  func testGestureTouchModeSetFailureDueToDataChannelUpdateFailure() throws {
    try assertDataChannelUpdateFailureForSetTouchMode(.gesture)
  }

  func testContinuousTouchModeSetFailureDueToDataChannelUpdateFailure() throws {
    try assertDataChannelUpdateFailureForSetTouchMode(.continuous)
  }

  func testGestureTouchModeSetFailureDueToNotificationQueueDepthSetFailure() throws {
    try assertNotificationQueueDepthSetFailureForTouchMode(.gesture)
  }

  func testContinuousTouchModeSetFailureDueToNotificationQueueDepthSetFailure() throws {
    try assertNotificationQueueDepthSetFailureForTouchMode(.continuous)
  }

  private func assertSuccessForSetTouchMode(_ touchMode: TouchMode) throws {
    let peripheral = FakePeripheralImplementation(identifier: uuid, name: deviceName)
    let transport = TransportV2Implementation(
      peripheral: peripheral,
      characteristics: requiredCharacteristics
    )
    let connectedTag = ConnectedTagModel(
      transport: transport,
      userPublishQueue: .main,
      tagComponent: FakeConnectedTag(transport: FakeTransport()).tagComponent,
      sdkConfig: config
    )
    let transportState = JacquardTransportState()

    let setTouchModeExpectation = expectation(description: "setTouchModeExpectation")
    let dataChannelUpdateExpectation = expectation(description: "dataChannelUpdateExpectation")

    // Construct touch mode command request.
    let touchModeRequest = SetTouchModeCommand(component: fakeGearComponent, mode: touchMode)

    // Modify the original request by adding the id for it.
    var request = touchModeRequest.request
    request.id = transportState.nextRequestId()

    // Form the expected data to be written on the peripheral.
    var expectedData: Data
    var packet = try request.serializedData(partial: false)
    expectedData = transportState.commandFragmenter.fragments(fromPacket: packet).first!

    peripheral.writeValueHandler = { data, characteristic, type in

      // Validate the touch mode request received on the peripheral.
      XCTAssertEqual(data, expectedData, "Received wrong request for setting the touch mode.")
      XCTAssertEqual(
        characteristic.uuid,
        self.commandCharacteristic.uuid,
        "Touch mode request received on the wrong characteristic.")
      XCTAssertEqual(type, .withoutResponse, "Received wrong request type.")

      // Create the response characteristic with touch mode command success data.
      let response = FakeCharacteristic(responseValue: self.dataChannelUpdateSuccessResponse)
      peripheral.delegate?.peripheral(peripheral, didUpdateValueFor: response, error: nil)

      dataChannelUpdateExpectation.fulfill()
    }

    // Call the setTouchMode API.
    connectedTag.setTouchMode(touchMode, for: fakeGearComponent).sink { (error) in
      XCTFail("Set touch mode failed with error: \(error)")
    } receiveValue: { (_) in
      setTouchModeExpectation.fulfill()
    }.addTo(&observers)

    wait(for: [dataChannelUpdateExpectation], timeout: 0.5)

    let notificationQueueDepthSetExpectation = expectation(
      description: "notificationQueueDepthSetExpectation")

    // Construct the notification queue depth set request.
    var config = Google_Jacquard_Protocol_BleConfiguration()
    switch touchMode {
    case .gesture:
      config.notifQueueDepth = 14
    case .continuous:
      config.notifQueueDepth = 2
    }
    let configWriteRequest = UJTWriteConfigCommand(config: config)

    // Modify the original request by adding the id for it.
    request = configWriteRequest.request
    request.id = transportState.nextRequestId()

    // Form the expected data to be written on the peripheral.
    packet = try request.serializedData(partial: false)
    expectedData = transportState.commandFragmenter.fragments(fromPacket: packet).first!

    peripheral.writeValueHandler = { data, characteristic, type in

      // Validate the notification queue depth set request received on the peripheral.
      XCTAssertEqual(data, expectedData, "Received wrong request for notification queue depth set.")
      XCTAssertEqual(
        characteristic.uuid,
        self.commandCharacteristic.uuid,
        "Request received on the wrong characteristic")
      XCTAssertEqual(type, .withoutResponse, "Received wrong request type.")

      // Create the response characteristic with notification queue depth set success data.
      let response = FakeCharacteristic(
        responseValue: self.notificationQueueDepthSetSuccessResponse)
      peripheral.delegate?.peripheral(peripheral, didUpdateValueFor: response, error: nil)

      notificationQueueDepthSetExpectation.fulfill()
    }

    wait(
      for: [notificationQueueDepthSetExpectation, setTouchModeExpectation],
      timeout: 0.5,
      enforceOrder: true
    )
  }

  private func assertDataChannelUpdateFailureForSetTouchMode(_ touchMode: TouchMode) throws {
    let peripheral = FakePeripheralImplementation(identifier: uuid, name: deviceName)
    let transport = TransportV2Implementation(
      peripheral: peripheral,
      characteristics: requiredCharacteristics
    )
    let connectedTag = ConnectedTagModel(
      transport: transport,
      userPublishQueue: .main,
      tagComponent: FakeConnectedTag(transport: FakeTransport()).tagComponent,
      sdkConfig: config
    )
    let setTouchModeExpectation = expectation(description: "setTouchModeExpectation")
    let dataChannelUpdateExpectation = expectation(description: "dataChannelUpdateExpectation")

    peripheral.writeValueHandler = { _, _, _ in

      // Create the response characteristic with touch mode command failure data.
      let response = FakeCharacteristic(responseValue: self.commandFailureResponse)
      peripheral.delegate?.peripheral(peripheral, didUpdateValueFor: response, error: nil)

      dataChannelUpdateExpectation.fulfill()
    }

    // Call the setTouchMode API.
    connectedTag.setTouchMode(touchMode, for: fakeGearComponent).sink { (error) in
      XCTAssertNotNil(error, "Error is expected.")
      setTouchModeExpectation.fulfill()
    } receiveValue: { (_) in
      XCTFail("Set touch mode success is not expected.")
    }.addTo(&observers)

    wait(
      for: [dataChannelUpdateExpectation, setTouchModeExpectation],
      timeout: 0.5,
      enforceOrder: true)
  }

  private func assertNotificationQueueDepthSetFailureForTouchMode(_ touchMode: TouchMode) throws {
    let peripheral = FakePeripheralImplementation(identifier: uuid, name: deviceName)
    let transport = TransportV2Implementation(
      peripheral: peripheral,
      characteristics: requiredCharacteristics
    )
    let connectedTag = ConnectedTagModel(
      transport: transport,
      userPublishQueue: .main,
      tagComponent: FakeConnectedTag(transport: FakeTransport()).tagComponent,
      sdkConfig: config
    )
    let setTouchModeExpectation = expectation(description: "setTouchModeExpectation")
    let dataChannelUpdateExpectation = expectation(description: "dataChannelUpdateExpectation")

    peripheral.writeValueHandler = { _, _, _ in

      // Create the response characteristic with touch mode command success data.
      let response = FakeCharacteristic(responseValue: self.dataChannelUpdateSuccessResponse)
      peripheral.delegate?.peripheral(peripheral, didUpdateValueFor: response, error: nil)

      dataChannelUpdateExpectation.fulfill()
    }

    // Call the setTouchMode API.
    connectedTag.setTouchMode(touchMode, for: fakeGearComponent).sink { (error) in
      XCTAssertNotNil(error, "Error is expected.")
      setTouchModeExpectation.fulfill()
    } receiveValue: { (_) in
      XCTFail("Set touch mode success is not expected.")
    }.addTo(&observers)

    wait(for: [dataChannelUpdateExpectation], timeout: 0.5)

    let notificationQueueDepthSetExpectation = expectation(
      description: "notificationQueueDepthSetExpectation")

    peripheral.writeValueHandler = { _, _, _ in

      // Create the response characteristic with notification queue depth set failure data.
      let response = FakeCharacteristic(responseValue: self.commandFailureResponse)
      peripheral.delegate?.peripheral(peripheral, didUpdateValueFor: response, error: nil)

      notificationQueueDepthSetExpectation.fulfill()
    }

    wait(
      for: [notificationQueueDepthSetExpectation, setTouchModeExpectation],
      timeout: 0.5,
      enforceOrder: true
    )
  }

  // PreConnectedTagModel tests.
  func testPreConnectedTagModel() {
    let fakePeripheralWithNameAndID = FakePeripheralImplementation(
      identifier: uuid, name: deviceName)
    var preConnectedTag = PreConnectedTagModel(peripheral: fakePeripheralWithNameAndID)
    XCTAssertEqual(preConnectedTag.displayName, deviceName, "Pre-connected tag has wrong name.")
    XCTAssertEqual(preConnectedTag.identifier, uuid, "Pre-connected tag has wrong identifier.")

    // Pre connected tag with peripheral having no name.
    let fakePeripheralWithOnlyID = FakePeripheralImplementation(identifier: uuid)
    preConnectedTag = PreConnectedTagModel(peripheral: fakePeripheralWithOnlyID)
    XCTAssertEqual(preConnectedTag.displayName, "", "PreConnectedTag has wrong name.")
  }

  func testGearAttachSubscription() {
    let attachNotificationExpectation = expectation(description: "attachNotificationExpectation")
    let transport = FakeTransport()

    let connectedTag = ConnectedTagModel(
      transport: transport,
      userPublishQueue: .main,
      tagComponent: FakeConnectedTag(transport: FakeTransport()).tagComponent,
      sdkConfig: config
    )
    func createSubscriptions(_ tag: SubscribableTag) {
      tag.subscribe(AttachedNotificationSubscription())
        .sink { component in
          XCTAssertNotNil(component)
          XCTAssertEqual(component!.vendor.name, "Levi's")
          XCTAssert(component!.isAttached)
          attachNotificationExpectation.fulfill()
        }.addTo(&observers)
    }

    connectedTag.registerSubscriptions(createSubscriptions(_:))

    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
      transport.postGearAttach()
    }

    wait(for: [attachNotificationExpectation], timeout: 3.0)
  }
}
