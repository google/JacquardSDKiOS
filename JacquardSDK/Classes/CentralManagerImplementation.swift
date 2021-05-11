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

/// Implementation wrapper of `CBCentralManager`.
class CentralManagerImplementation: NSObject, CentralManager {

  private var centralManager: CBCentralManager!

  var delegate: CentralManagerDelegate?

  var state: CBManagerState { centralManager.state }

  init(
    delegate: CentralManagerDelegate?,
    publishQueue: DispatchQueue = .main,
    options: [String: Any]? = nil
  ) {
    super.init()
    centralManager = CBCentralManager(delegate: self, queue: publishQueue, options: options)
    self.delegate = delegate
  }

  func scanForPeripherals(
    withServices serviceUUIDs: [PeripheralUUID]?,
    options: [String: Any]? = nil
  ) {
    centralManager.scanForPeripherals(withServices: serviceUUIDs?.map { $0.uuid }, options: options)
  }

  func stopScan() {
    centralManager.stopScan()
  }

  func retrieveConnectedPeripherals(withServices serviceUUIDs: [PeripheralUUID]) -> [Peripheral] {
    centralManager.retrieveConnectedPeripherals(
      withServices: serviceUUIDs.map { $0.uuid }
    ).map { PeripheralImplementation(peripheral: $0) }
  }

  func retrievePeripherals(withIdentifiers identifiers: [UUID]) -> [Peripheral] {
    centralManager.retrievePeripherals(
      withIdentifiers: identifiers
    ).map { PeripheralImplementation(peripheral: $0) }
  }

  func connect(_ peripheral: Peripheral, options: [String: Any]?) {
    guard let peripheral = peripheral as? PeripheralImplementation else {
      preconditionFailure("Unable to convert peripheral as CBPeripheral.")
    }
    centralManager.connect(peripheral.peripheral, options: options)
  }

  func cancelPeripheralConnection(_ peripheral: Peripheral) {
    guard let peripheral = peripheral as? PeripheralImplementation else {
      preconditionFailure("Unable to convert peripheral as CBPeripheral.")
    }
    centralManager.cancelPeripheralConnection(peripheral.peripheral)
  }
}

extension CentralManagerImplementation: CBCentralManagerDelegate {

  func centralManagerDidUpdateState(_ central: CBCentralManager) {
    delegate?.centralManagerDidUpdateState(central.state)
  }

  func centralManager(
    _ central: CBCentralManager,
    didDiscover peripheral: CBPeripheral,
    advertisementData: [String: Any],
    rssi rssiValue: NSNumber
  ) {
    delegate?.centralManager(
      self,
      didDiscover: PeripheralImplementation(peripheral: peripheral),
      advertisementData: advertisementData,
      rssi: rssiValue
    )
  }

  func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
    delegate?.centralManager(self, didConnect: PeripheralImplementation(peripheral: peripheral))
  }

  func centralManager(
    _ central: CBCentralManager,
    didFailToConnect peripheral: CBPeripheral,
    error: Error?
  ) {
    delegate?.centralManager(
      self,
      didFailToConnect: PeripheralImplementation(peripheral: peripheral),
      error: error
    )
  }

  func centralManager(
    _ central: CBCentralManager,
    didDisconnectPeripheral peripheral: CBPeripheral,
    error: Error?
  ) {
    delegate?.centralManager(
      self,
      didDisconnectPeripheral: PeripheralImplementation(peripheral: peripheral),
      error: error
    )
  }

  func centralManager(_ central: CBCentralManager, willRestoreState dict: [String: Any]) {
    jqLogger.debug("willRestoreState for \(dict)")
    guard !dict.isEmpty else {
      jqLogger.warning("No restored connections")
      return
    }
    var peripherals: [Peripheral] = []
    if let cbPeripherals = dict[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral] {
      for peripheral in cbPeripherals {
        peripherals.append(PeripheralImplementation(peripheral: peripheral))
      }
    }
    delegate?.centralManager(self, willRestoreState: peripherals)
  }
}
