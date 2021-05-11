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

final class TransportV2Tests: XCTestCase {

  struct CatchLogger: Logger {
    func log(level: LogLevel, file: String, line: Int, function: String, message: () -> String) {
      let _ = message()
      if level == .assertion || level == .error || level == .warning {
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

  private lazy var requiredCharacteristics = RequiredCharacteristics(
    commandCharacteristic: commandCharacteristic,
    responseCharacteristic: responseCharacteristic,
    notifyCharacteristic: notifyCharacteristic
  )

  var observations = [Cancellable]()
  let uuid = UUID(uuidString: "BD415750-8EF1-43EE-8A7F-7EF1E365C35E")!
  let deviceName = "Fake Device"

  func testVerifyPeripheralDetails() {
    let peripheral = FakePeripheralImplementation(identifier: uuid, name: deviceName)
    let transport = TransportV2Implementation(
      peripheral: peripheral,
      characteristics: requiredCharacteristics
    )

    XCTAssertEqual(transport.peripheralName, deviceName)
    XCTAssertEqual(transport.peripheralIdentifier.uuidString, uuid.uuidString)
  }

  func testVerifyPeripheralNamePublisher() {
    let namePublisherExpectation = expectation(description: "NamePublisher")
    namePublisherExpectation.expectedFulfillmentCount = 2

    let expectedNewDeviceName = "Updated mock device"
    let peripheral = FakePeripheralImplementation(identifier: uuid, name: deviceName)
    let transport = TransportV2Implementation(
      peripheral: peripheral,
      characteristics: requiredCharacteristics
    )

    transport.peripheralNamePublisher
      .buffer(size: Int.max, prefetch: .byRequest, whenFull: .dropOldest)
      .sink { name in

        XCTAssertEqual(name, peripheral.name)
        namePublisherExpectation.fulfill()
      }.addTo(&observations)

    peripheral.didUpdateName = true
    peripheral.updatePeripheralName(expectedNewDeviceName)

    var config = Google_Jacquard_Protocol_BleConfiguration()
    config.customAdvName = expectedNewDeviceName
    let configWriteRequest = UJTWriteConfigCommand(config: config)

    transport.enqueue(request: configWriteRequest.request, retries: 0) { _ in }
    wait(for: [namePublisherExpectation], timeout: 1.0)
  }

  func testVerifyDidWriteCommandPublisher() {
    let didWriteCommandExpectation = expectation(description: "DidWriteCommand")
    let peripheral = FakePeripheralImplementation(identifier: uuid, name: deviceName)

    let transport = TransportV2Implementation(
      peripheral: peripheral,
      characteristics: requiredCharacteristics
    )

    transport.didWriteCommandPublisher
      .buffer(size: Int.max, prefetch: .byRequest, whenFull: .dropOldest)
      .sink { error in
        XCTAssertNil(error)
        didWriteCommandExpectation.fulfill()
      }.addTo(&observations)

    let helloRequest = Google_Jacquard_Protocol_Request.with {
      $0.domain = .base
      $0.opcode = .hello
    }

    peripheral.didWriteValue = true
    transport.enqueue(request: helloRequest, retries: 0) { _ in }
    wait(for: [didWriteCommandExpectation], timeout: 1.0)
  }

  func testBadProtoRequest() {
    let badProtoRequestExpectation = expectation(description: "BadProtoRequest")
    let peripheral = FakePeripheralImplementation(identifier: uuid, name: deviceName)
    peripheral.didWriteValue = true

    let retry = 2
    let transport = TransportV2Implementation(
      peripheral: peripheral,
      characteristics: requiredCharacteristics
    )

    transport.didWriteCommandPublisher
      .buffer(size: Int.max, prefetch: .byRequest, whenFull: .dropOldest)
      .sink { _ in
        XCTFail("Bad proto request should not succeed")
      }.addTo(&observations)

    let helloRequest = Google_Jacquard_Protocol_Request()

    transport.enqueue(request: helloRequest, retries: retry) { responseResult in
      switch responseResult {
      case .success:
        XCTFail("Bad proto request should not succeed")
      case .failure(let error):
        XCTAssertNotNil(error)
        XCTAssertEqual(Int(transport.lastRequestId), retry + 1)
        badProtoRequestExpectation.fulfill()
      }
    }
    wait(for: [badProtoRequestExpectation], timeout: 1.0)
  }

  func testVerifyDidWriteCommandPublisherWithError() {
    let didWriteCommandWithErrorExpectation = expectation(description: "DidWriteCommandWithError")
    jqLogger = CatchLogger(expectation: didWriteCommandWithErrorExpectation)

    let peripheral = FakePeripheralImplementation(identifier: uuid, name: deviceName)

    let transport = TransportV2Implementation(
      peripheral: peripheral,
      characteristics: requiredCharacteristics
    )

    transport.didWriteCommandPublisher
      .buffer(size: Int.max, prefetch: .byRequest, whenFull: .dropOldest)
      .sink { error in
        XCTAssertNotNil(error)
      }.addTo(&observations)

    let helloRequest = Google_Jacquard_Protocol_Request.with {
      $0.domain = .base
      $0.opcode = .hello
    }

    peripheral.didWriteValueWithError = true
    transport.enqueue(request: helloRequest, retries: 0) { _ in }
    wait(for: [didWriteCommandWithErrorExpectation], timeout: 1.0)
  }

  func testVerifyResponseCharacteristic() {
    let didUpdateForCharacteristicExpectation = expectation(
      description: "DidUpdateForResponseCharacteristic"
    )

    let peripheral = FakePeripheralImplementation(identifier: uuid, name: deviceName)

    let transport = TransportV2Implementation(
      peripheral: peripheral,
      characteristics: requiredCharacteristics
    )

    let helloRequest = Google_Jacquard_Protocol_Request.with {
      $0.domain = .base
      $0.opcode = .hello
    }

    peripheral.didUpdateValueForResponseCharacteristic = true
    transport.enqueue(request: helloRequest, retries: 0) { responseResult in
      switch responseResult {
      case .success(let packet):
        do {
          let response = try Google_Jacquard_Protocol_Response(
            serializedData: packet, extensions: Google_Jacquard_Protocol_Jacquard_Extensions)
          XCTAssert(response.status == .ok)
        } catch (let error) {
          XCTFail("Error: \(error)")
        }
      case .failure(let error):
        XCTFail("Error: \(error)")
      }

      didUpdateForCharacteristicExpectation.fulfill()
    }
    wait(for: [didUpdateForCharacteristicExpectation], timeout: 1.0)
  }

  func testVerifyResponseCharacteristicWithEmptyData() {
    let didUpdateForCharacteristicWithEmptyDataExpectation = expectation(
      description: "DidUpdateForResponseCharacteristicWithEmptyData"
    )

    jqLogger = CatchLogger(expectation: didUpdateForCharacteristicWithEmptyDataExpectation)

    let peripheral = FakePeripheralImplementation(identifier: uuid, name: deviceName)

    let transport = TransportV2Implementation(
      peripheral: peripheral,
      characteristics: requiredCharacteristics
    )

    let helloRequest = Google_Jacquard_Protocol_Request.with {
      $0.domain = .base
      $0.opcode = .hello
    }

    peripheral.didUpdateValueForResponseCharacteristicWithEmptyData = true
    transport.enqueue(request: helloRequest, retries: 0) { responseResult in
      XCTFail("Should not be here when received response with empty value.")
    }
    wait(for: [didUpdateForCharacteristicWithEmptyDataExpectation], timeout: 1.0)
  }

  func testVerifyResendResponseCharacteristic() {
    let resendResponseCharacteristicExpectation = expectation(
      description: "ResendResponseCharacteristic"
    )
    resendResponseCharacteristicExpectation.expectedFulfillmentCount = 2

    jqLogger = CatchLogger(expectation: resendResponseCharacteristicExpectation)

    let peripheral = FakePeripheralImplementation(identifier: uuid, name: deviceName)

    let transport = TransportV2Implementation(
      peripheral: peripheral,
      characteristics: requiredCharacteristics
    )

    let helloRequest = Google_Jacquard_Protocol_Request.with {
      $0.domain = .base
      $0.opcode = .hello
    }

    peripheral.resendResponseCharacteristic = true
    transport.enqueue(request: helloRequest, retries: 0) { responseResult in
      switch responseResult {
      case .success(let packet):
        do {
          let response = try Google_Jacquard_Protocol_Response(
            serializedData: packet, extensions: Google_Jacquard_Protocol_Jacquard_Extensions)
          XCTAssert(response.status == .ok)
        } catch (let error) {
          XCTFail("Error: \(error)")
        }
      case .failure(let error):
        XCTFail("Error: \(error)")
      }

      resendResponseCharacteristicExpectation.fulfill()
    }
    wait(for: [resendResponseCharacteristicExpectation], timeout: 1.0)
  }

  func testVerifyNotifyCharacteristic() {
    let didUpdateForNotifyCharacteristicExpectation = expectation(
      description: "DidUpdateForNotifyCharacteristic"
    )

    let peripheral = FakePeripheralImplementation(identifier: uuid, name: deviceName)

    let transport = TransportV2Implementation(
      peripheral: peripheral,
      characteristics: requiredCharacteristics
    )

    transport.notificationPublisher
      .buffer(size: Int.max, prefetch: .byRequest, whenFull: .dropOldest)
      .sink { notification in

        XCTAssert(notification.opcode == .attached)
        didUpdateForNotifyCharacteristicExpectation.fulfill()
      }.addTo(&observations)

    transport.stopCachingNotifications()
    peripheral.postGearAttachNotification()

    wait(for: [didUpdateForNotifyCharacteristicExpectation], timeout: 1.0)
  }

  func testVerifyNotifyCharacteristicWithEmptyData() {
    let didUpdateForNotifyCharacteristicWithEmptyDataExpectation = expectation(
      description: "DidUpdateForNotifyCharacteristicWithEmptyData"
    )

    jqLogger = CatchLogger(expectation: didUpdateForNotifyCharacteristicWithEmptyDataExpectation)

    let peripheral = FakePeripheralImplementation(identifier: uuid, name: deviceName)

    let transport = TransportV2Implementation(
      peripheral: peripheral,
      characteristics: requiredCharacteristics
    )

    transport.notificationPublisher
      .buffer(size: Int.max, prefetch: .byRequest, whenFull: .dropOldest)
      .sink { notification in
        XCTFail("Notification should not publish for empty value.")
      }.addTo(&observations)

    peripheral.postNotificationWithEmptyData()

    wait(for: [didUpdateForNotifyCharacteristicWithEmptyDataExpectation], timeout: 1.0)
  }

  func testVerifyUnknownNotificationCharacteristic() {
    let didUpdateForNotifyCharacteristicWithEmptyDataExpectation = expectation(
      description: "DidUpdateForNotifyCharacteristicWithEmptyData"
    )

    jqLogger = CatchLogger(expectation: didUpdateForNotifyCharacteristicWithEmptyDataExpectation)

    let peripheral = FakePeripheralImplementation(identifier: uuid, name: deviceName)

    let transport = TransportV2Implementation(
      peripheral: peripheral,
      characteristics: requiredCharacteristics
    )

    transport.notificationPublisher
      .buffer(size: Int.max, prefetch: .byRequest, whenFull: .dropOldest)
      .sink { notification in
        XCTFail("Notification should not publish for empty value.")
      }.addTo(&observations)

    peripheral.postUnknownBluetoothNotification()

    wait(for: [didUpdateForNotifyCharacteristicWithEmptyDataExpectation], timeout: 1.0)
  }

  func testVerifyNotificationPublisherWithCachingOff() {
    let cachingOffExpectation = expectation(description: "CachingOff")

    let peripheral = FakePeripheralImplementation(identifier: uuid, name: deviceName)

    let transport = TransportV2Implementation(
      peripheral: peripheral,
      characteristics: requiredCharacteristics
    )

    // Stop notification caching.
    transport.stopCachingNotifications()

    // Verify caching stopped.
    XCTAssert(transport.cacheNotifications)

    // Wait for the next notification delivery before stopping caching. Not subscribing publisher
    // here as it has been tested in another test case.
    peripheral.postGearAttachNotification()

    transport.notificationPublisher
      .buffer(size: Int.max, prefetch: .byRequest, whenFull: .dropOldest)
      .sink { notification in

        XCTAssertFalse(transport.cacheNotifications)
        XCTAssert(notification.opcode == .batteryStatus)
        cachingOffExpectation.fulfill()
      }.addTo(&observations)

    // Posting another notification to check caching stops.
    peripheral.postBatteryStatusNotification()

    // Checking if stop caching doesn't toggle caching.
    transport.stopCachingNotifications()

    XCTAssertFalse(transport.cacheNotifications)

    wait(for: [cachingOffExpectation], timeout: 1.0)
  }

  func testVerifyMalformedDataDeliveryNotification() {
    let malformedDataExpectation = expectation(description: "MalformedData")

    jqLogger = CatchLogger(expectation: malformedDataExpectation)

    let peripheral = FakePeripheralImplementation(identifier: uuid, name: deviceName)

    let transport = TransportV2Implementation(
      peripheral: peripheral,
      characteristics: requiredCharacteristics
    )

    transport.notificationPublisher
      .buffer(size: Int.max, prefetch: .byRequest, whenFull: .dropOldest)
      .sink { notification in
        XCTFail("Notification should not publish for bad packets.")
      }.addTo(&observations)

    transport.deliverNotification(packet: peripheral.badPacket)

    wait(for: [malformedDataExpectation], timeout: 1.0)
  }
}
