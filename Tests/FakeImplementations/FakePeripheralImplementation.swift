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

import CoreBluetooth

@testable import JacquardSDK

struct FakeCharacteristic: Characteristic {
  var uuid: CBUUID
  var value: Data?
  var charProperties: CharacteristicProperties

  init(uuid: CBUUID, value: Data?, properties: CharacteristicProperties) {
    self.uuid = uuid
    self.charProperties = properties
    self.value = value
  }

  init(responseValue: Data?) {
    self.uuid = JacquardServices.responseUUID
    self.charProperties = [.notify]
    self.value = responseValue
  }

  init(notifyValue: Data?) {
    self.uuid = JacquardServices.notifyUUID
    self.charProperties = [.notify]
    self.value = notifyValue
  }

  init(commandValue: Data?) {
    self.uuid = JacquardServices.commandUUID
    self.charProperties = [.write, .writeWithoutResponse]
    self.value = commandValue
  }

  init(rawDataValue: Data?) {
    self.uuid = JacquardServices.rawDataUUID
    self.charProperties = [.notify]
    self.value = rawDataValue
  }
}

struct FakeService: Service {
  var uuid: CBUUID
  var characteristics: [CBCharacteristic]?
}

/// Fake wrapper implementation for `Peripheral`.
class FakePeripheralImplementation: Peripheral {

  enum ResponseType {
    case none
    case helloCommand
    case beginCommand
    case componentInfoCommand
  }

  enum CallbackType {
    case didUpdateName
    case didWriteValue(ResponseType)
    case didWriteValueWithError
    case didUpdateValue(ResponseType)
    case didUpdateValueForResponseCharacteristicWithEmptyData
    case didDiscoverServices
    case didDiscoverCharacteristics
    case didUpdateNotificationState
    case didResendResponseCharacteristic
  }

  private var deviceName: String?
  private let deviceUUID: UUID

  var callbackType: CallbackType?
  var completionHandler: ((FakePeripheralImplementation, CallbackType) -> Void)?

  /// Hello command response data.
  private let helloCommandResponse = Data(
    [
      192, 43, 8, 1, 16, 0, 24, 0, 162, 6, 34, 8, 2, 16, 2, 26, 11, 71, 111, 111,
      103, 108, 101, 32, 73, 110, 99, 46, 34, 3, 85, 74, 84, 48, 200, 225, 224,
      139, 1, 56, 160, 207, 239, 193, 2,
    ]
  )

  /// Attach notification data.
  private let attachNotification = Data(
    [
      192, 25, 8, 0, 16, 9, 24, 0, 234, 6, 16, 8, 1, 16, 146,
      194, 222, 218, 15, 24, 176, 241, 225, 230, 5, 32, 101,
    ]
  )

  /// Battery status notification data.
  private let batteryStatusNotification =
    Data([192, 13, 8, 0, 16, 23, 24, 0, 202, 7, 4, 8, 50, 16, 2])

  /// Begin command response data.
  let beginCommandResponse = Data([192, 9, 8, 2, 16, 0, 24, 0, 170, 6, 0])

  /// ComponentInfo command response data representing version 1.96.0.
  let componentInfoCommandResponsePart1 = Data(
    [
      128, 79, 8, 3, 16, 0, 24, 0, 186, 6, 70, 10, 11, 71, 111, 111, 103, 108, 101, 32, 73, 110,
      99, 46, 18, 3, 85, 74, 84, 24, 4, 34, 24, 48, 45, 48, 55, 45, 57, 52, 49, 50, 70, 76, 72,
      66, 75, 48, 48, 48, 56, 54, 45, 49, 57, 48, 52, 40, 1, 48, 96,
    ]
  )
  let componentInfoCommandResponsePart2 = Data(
    [
      65, 56, 0, 64, 1, 72, 0, 80,
      0, 80, 200, 225, 224, 139, 1, 96, 160, 207, 239, 193, 2,
    ]
  )

  // Based on above ComponentInfoCommandResponse.
  static let tagVendorName = "Google Inc."
  static let tagVersion = Version(major: 1, minor: 96, micro: 0)
  static let tagUUID = "0-07-9412FLHBK00086-1904"

  /// Notify depth queue response required response breakup for parsing.
  let depthQueueResponsePart1 = Data(
    [
      128, 60, 8, 5, 16, 0, 24, 0, 234, 68, 51, 18, 49, 10, 13, 74, 97, 99, 113, 117, 97, 114, 100,
      45, 48, 48, 51, 82, 16, 244, 255, 255, 255, 255, 255, 255, 255, 255, 1, 24, 0, 37, 0, 0, 160,
      65, 40, 60, 53, 0, 160, 160, 68, 56, 60, 64, 6, 72, 144, 3, 80,
    ]
  )
  let depthQueueResponsePart2 = Data([65, 14])

  /// Malform data.
  let badPacket = Data([0, 16, 23, 24, 0, 202, 7, 4, 8, 50])

  var name: String? { deviceName }

  var identifier: UUID { deviceUUID }

  var services: [Service]?

  var notifyStateError: Error?

  var writeValueHandler: ((Data, Characteristic, CharacteristicWriteType) -> Void)?

  var delegate: PeripheralDelegate?

  init(identifier: UUID, name: String? = nil) {
    deviceUUID = identifier
    deviceName = name
  }

  /// Update peripheral name.
  func updatePeripheralName(_ name: String) { deviceName = name }

  func readRSSI() {
    self.delegate?.peripheral(self, didReadRSSI: -72.0, error: nil)
  }

  func postUpdateForHelloCommandResponse() {
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
      // Create response characteristic with success data.
      let responseCharacteristic = FakeCharacteristic(responseValue: self.helloCommandResponse)

      // When receives success response for given command.
      self.delegate?.peripheral(self, didUpdateValueFor: responseCharacteristic, error: nil)
      self.completionHandler?(self, .didUpdateValue(.helloCommand))
    }
  }

  func postUpdateForComponentInfoResponse() {
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {

      // Create response characteristic with success data.
      let responseCharacteristicPart1 = FakeCharacteristic(
        responseValue: self.componentInfoCommandResponsePart1)
      self.delegate?.peripheral(self, didUpdateValueFor: responseCharacteristicPart1, error: nil)

      let responseCharacteristicPart2 = FakeCharacteristic(
        responseValue: self.componentInfoCommandResponsePart2)
      self.delegate?.peripheral(self, didUpdateValueFor: responseCharacteristicPart2, error: nil)
      self.completionHandler?(self, .didUpdateValue(.componentInfoCommand))
    }
  }

  /// Post config tag command response.
  func postConfigTagCommandResponse() {
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {

      let responseCharacteristicPart1 = FakeCharacteristic(
        responseValue: self.depthQueueResponsePart1)
      self.delegate?.peripheral(self, didUpdateValueFor: responseCharacteristicPart1, error: nil)

      let responseCharacteristicPart2 = FakeCharacteristic(
        responseValue: self.depthQueueResponsePart2)
      self.delegate?.peripheral(self, didUpdateValueFor: responseCharacteristicPart2, error: nil)
    }
  }

  /// Post attach notification to handle notifyUUID through peripheral delegate.
  func postGearAttachNotification() {
    let notifyCharacteristic = FakeCharacteristic(notifyValue: attachNotification)
    delegate?.peripheral(self, didUpdateValueFor: notifyCharacteristic, error: nil)
  }

  /// Post battery status notification to handle notifyUUID through peripheral delegate.
  func postBatteryStatusNotification() {
    let notifyCharacteristic = FakeCharacteristic(notifyValue: batteryStatusNotification)
    delegate?.peripheral(self, didUpdateValueFor: notifyCharacteristic, error: nil)
  }

  /// Post notification with empty characteristic data.
  func postNotificationWithEmptyData() {
    let notifyCharacteristic = FakeCharacteristic(notifyValue: nil)
    delegate?.peripheral(self, didUpdateValueFor: notifyCharacteristic, error: nil)
  }

  /// Post unknown characteristic notification.
  func postUnknownBluetoothNotification() {
    let unknownUUID = CBUUID(string: "D2F2B8D1-D165-445C-B0E1-2D6B642EC58B")
    let unknownCharacteristic = FakeCharacteristic(
      uuid: unknownUUID,
      value: nil,
      properties: [.read]
    )
    delegate?.peripheral(self, didUpdateValueFor: unknownCharacteristic, error: nil)
  }

  func writeValue(_ data: Data, for characteristic: Characteristic, type: CharacteristicWriteType) {
    switch callbackType {
    case .didUpdateName:
      // Callback when peripheral name changed.
      delegate?.peripheralDidUpdateName(self)
      completionHandler?(self, .didUpdateName)
    case .didWriteValue(let responseType) where responseType != .none:
      // Callback when peripheral writes something with success result.
      completionHandler?(self, .didWriteValue(responseType))
    case .didWriteValueWithError:
      // Create response characteristic.
      let responseCharacteristic = FakeCharacteristic(responseValue: helloCommandResponse)
      // When didWriteValueFor callback called for wrong characteristic.
      delegate?.peripheral(self, didWriteValueFor: responseCharacteristic, error: nil)
      completionHandler?(self, .didWriteValueWithError)
    case .didUpdateValue(let responseType):
      if responseType == .helloCommand {
        postUpdateForHelloCommandResponse()
      } else if responseType == .beginCommand {
        postUpdateForBeginCommandResponse()
      } else if responseType == .componentInfoCommand {
        postUpdateForComponentInfoResponse()
      }
    case .didUpdateValueForResponseCharacteristicWithEmptyData:
      // Create response characteristic with empty data.
      let responseCharacteristic = FakeCharacteristic(responseValue: nil)

      // When receives empty response for given command.
      delegate?.peripheral(self, didUpdateValueFor: responseCharacteristic, error: nil)
      completionHandler?(self, .didUpdateValueForResponseCharacteristicWithEmptyData)
    case .didResendResponseCharacteristic:
      // Create response characteristic with success data.
      let responseCharacteristic = FakeCharacteristic(responseValue: helloCommandResponse)

      // Send updates for given command.
      delegate?.peripheral(self, didUpdateValueFor: responseCharacteristic, error: nil)

      // Resend updates for given command to verify it ignores by receiver.
      delegate?.peripheral(self, didUpdateValueFor: responseCharacteristic, error: nil)
      completionHandler?(self, .didResendResponseCharacteristic)
    default:
      break
    }
    writeValueHandler?(data, characteristic, type)
  }

  func discoverServices(_ serviceUUIDs: [UUID]?) {
    delegate?.peripheral(self, didDiscoverServices: nil)
    completionHandler?(self, .didDiscoverServices)
  }

  func discoverCharacteristics(_ characteristicUUIDs: [UUID]?, for service: Service) {
    delegate?.peripheral(self, didDiscoverCharacteristicsFor: service, error: nil)
    completionHandler?(self, .didDiscoverCharacteristics)
  }

  func setNotifyValue(_ enabled: Bool, for characteristic: Characteristic) {
    delegate?.peripheral(
      self,
      didUpdateNotificationStateFor: characteristic,
      error: notifyStateError
    )
    completionHandler?(self, .didUpdateNotificationState)
  }
}
