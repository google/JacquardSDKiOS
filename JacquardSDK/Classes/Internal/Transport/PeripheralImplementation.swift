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

/// `Peripheral` protocol wrapper for `CBPeripheral`.
///
/// Due to the delegate, `CBPeripheral` cannot be made to conform to `Peripheral` directly.
class PeripheralImplementation: NSObject, Peripheral {

  let peripheral: CBPeripheral

  weak var delegate: PeripheralDelegate? {
    didSet {
      self.peripheral.delegate = self
    }
  }

  var name: String? { peripheral.name }

  var identifier: UUID { peripheral.identifier }

  var services: [Service]? { peripheral.services }

  init(peripheral: CBPeripheral) {
    self.peripheral = peripheral
  }

  func writeValue(
    _ data: Data,
    for characteristic: Characteristic,
    type: CharacteristicWriteType
  ) {
    guard let characteristic = characteristic as? CBCharacteristic else {
      jqLogger.preconditionAssertFailure(
        "writeValue() in concrete type Peripheral requires a real CBCharacteristic")
      return
    }
    peripheral.writeValue(data, for: characteristic, type: CBCharacteristicWriteType(type))
  }

  func discoverServices(_ serviceUUIDs: [PeripheralUUID]?) {
    peripheral.discoverServices(serviceUUIDs?.map { $0.uuid })
  }

  func discoverCharacteristics(_ characteristicUUIDs: [PeripheralUUID]?, for service: Service) {
    guard let service = service as? CBService else {
      jqLogger.preconditionAssertFailure(
        "discoverCharacteristics() in concrete type Peripheral requires a real CBService")
      return
    }
    peripheral.discoverCharacteristics(characteristicUUIDs?.map { $0.uuid }, for: service)
  }

  func setNotifyValue(_ enabled: Bool, for characteristic: Characteristic) {
    guard let characteristic = characteristic as? CBCharacteristic else {
      jqLogger.preconditionAssertFailure(
        "setNotifyValue() in concrete type Peripheral requires a real CBCharacteristic")
      return
    }
    peripheral.setNotifyValue(enabled, for: characteristic)
  }

  func readRSSI() {
    peripheral.readRSSI()
  }
}

// MARK: CBPeripheralDelegate

extension PeripheralImplementation: CBPeripheralDelegate {

  func peripheralDidUpdateName(_ peripheral: CBPeripheral) {
    delegate?.peripheralDidUpdateName(PeripheralImplementation(peripheral: peripheral))
  }

  func peripheral(
    _ peripheral: CBPeripheral,
    didWriteValueFor characteristic: CBCharacteristic,
    error: Error?
  ) {
    delegate?.peripheral(
      PeripheralImplementation(peripheral: peripheral),
      didWriteValueFor: characteristic,
      error: error
    )
  }

  func peripheral(
    _ peripheral: CBPeripheral,
    didUpdateValueFor characteristic: CBCharacteristic,
    error: Error?
  ) {
    delegate?.peripheral(
      PeripheralImplementation(peripheral: peripheral),
      didUpdateValueFor: characteristic,
      error: error
    )
  }

  func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
    delegate?.peripheral(
      PeripheralImplementation(peripheral: peripheral),
      didDiscoverServices: error
    )
  }

  func peripheral(
    _ peripheral: CBPeripheral,
    didDiscoverCharacteristicsFor service: CBService,
    error: Error?
  ) {
    delegate?.peripheral(
      PeripheralImplementation(peripheral: peripheral),
      didDiscoverCharacteristicsFor: service,
      error: error
    )
  }

  func peripheral(
    _ peripheral: CBPeripheral,
    didUpdateNotificationStateFor characteristic: CBCharacteristic,
    error: Error?
  ) {
    delegate?.peripheral(
      PeripheralImplementation(peripheral: peripheral),
      didUpdateNotificationStateFor: characteristic,
      error: error
    )
  }

  func peripheral(_ peripheral: CBPeripheral, didReadRSSI rssi: NSNumber, error: Error?) {
    delegate?.peripheral(
      PeripheralImplementation(peripheral: peripheral),
      didReadRSSI: rssi.floatValue,
      error: error
    )
  }
}
