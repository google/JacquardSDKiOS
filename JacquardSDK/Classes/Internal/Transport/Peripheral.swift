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

protocol Characteristic {
  var uuid: CBUUID { get }
  var value: Data? { get }
}

extension CBCharacteristic: Characteristic {}

enum CharacteristicWriteType {
  case withResponse
  case withoutResponse
}

extension CBCharacteristicWriteType {
  init(_ characteristicWriteType: CharacteristicWriteType) {
    switch characteristicWriteType {
    case .withResponse:
      self = .withResponse
    case .withoutResponse:
      self = .withoutResponse
    }
  }
}

protocol Service {
  var uuid: CBUUID { get }
  var characteristics: [CBCharacteristic]? { get }
}

extension CBService: Service {}

struct PeripheralUUID: Hashable {
  let uuid: CBUUID
}

/// Provides peripheral characteristic updates.
protocol PeripheralDelegate: AnyObject {

  /// Provides updates when peripheral name updated successfully.
  func peripheralDidUpdateName(_ peripheral: Peripheral)

  /// Provides updates when peripheral successfully writes characteristic.
  ///
  /// If an error occurred, the cause of the failure.
  func peripheral(
    _ peripheral: Peripheral, didWriteValueFor characteristic: Characteristic, error: Error?
  )

  /// Provides updates when peripheral gets any updates on any characteristic.
  ///
  /// If an error occurred, the cause of the failure.
  func peripheral(
    _ peripheral: Peripheral, didUpdateValueFor characteristic: Characteristic, error: Error?
  )

  /// Provides updates if the service(s) were read successfully for peripheral.
  ///
  /// Otherwise returns with an error.
  func peripheral(_ peripheral: Peripheral, didDiscoverServices error: Error?)

  /// Provides updates if the characteristic(s) were read successfully for peripheral's service.
  ///
  /// Otherwise returns with an error.
  func peripheral(
    _ peripheral: Peripheral, didDiscoverCharacteristicsFor service: Service, error: Error?
  )

  /// Provides updates when peripheral setNotify is called for any characteristic.
  ///
  /// Otherwise returns with an error.
  func peripheral(
    _ peripheral: Peripheral, didUpdateNotificationStateFor characteristic: Characteristic,
    error: Error?
  )

  /// Returns the result of readRSSI: call.
  ///
  /// @see readRSSI().
  func peripheral(_ peripheral: Peripheral, didReadRSSI rssiValue: Float, error: Error?)
}

/// Provides empty default implementations of optional delegate methods.
extension PeripheralDelegate {

  func peripheralDidUpdateName(_ peripheral: Peripheral) {}

  func peripheral(
    _ peripheral: Peripheral, didWriteValueFor characteristic: Characteristic, error: Error?
  ) {}

  func peripheral(
    _ peripheral: Peripheral, didUpdateValueFor characteristic: Characteristic, error: Error?
  ) {}

  func peripheral(_ peripheral: Peripheral, didDiscoverServices error: Error?) {}

  func peripheral(
    _ peripheral: Peripheral, didDiscoverCharacteristicsFor service: Service, error: Error?
  ) {}

  func peripheral(
    _ peripheral: Peripheral, didUpdateNotificationStateFor characteristic: Characteristic,
    error: Error?
  ) {}

  func peripheral(_ peripheral: Peripheral, didReadRSSI rssiValue: Float, error: Error?) {}
}

/// Testable protocol for `CBPeripheral` access.
protocol Peripheral {

  /// Peripheral name.
  var name: String? { get }

  /// Peripheral identifier.
  var identifier: UUID { get }

  /// Provides updates when peripheral name changed, characteristic written/changed.
  var delegate: PeripheralDelegate? { get set }

  /// Returns `CBPeripheral` services.
  var services: [Service]? { get }

  /// Writes value on given characteristc for peripheral.
  func writeValue(
    _ data: Data,
    for characteristic: Characteristic,
    type: CharacteristicWriteType
  )

  /// Discover peripheral services.
  ///
  /// - Paramater serviceUUIDs: Service UUIDs for peripheral.
  func discoverServices(_ serviceUUIDs: [PeripheralUUID]?)

  /// Discover characteristics for peripheral's services.
  ///
  /// - Paramaters:
  ///  - characteristicUUIDs: Characteristic UUIDs to be discover for any service.
  ///  - service: Peripheral service for which characteristics need to be discover.
  func discoverCharacteristics(_ characteristicUUIDs: [PeripheralUUID]?, for service: Service)

  /// Enable/Disable notification for characteristic.
  func setNotifyValue(_ enabled: Bool, for characteristic: Characteristic)

  /// Rerieves the current RSSI value for the peripheral while connected to the central manager.
  func readRSSI()
}
