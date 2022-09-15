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
    self.centralManager = CBCentralManager(delegate: self, queue: publishQueue, options: options)
    self.delegate = delegate
  }

  var isScanning: AnyPublisher<Bool, Never> {
    centralManager.publisher(for: \.isScanning, options: [.initial]).eraseToAnyPublisher()
  }

  func scanForPeripherals(
    withServices serviceUUIDs: [UUID]?,
    options: [String: Any]? = nil
  ) {
    centralManager.scanForPeripherals(
      withServices: serviceUUIDs?.map { CBUUID($0) }, options: options)
  }

  func stopScan() {
    centralManager.stopScan()
  }

  func retrieveConnectedPeripherals(withServices serviceUUIDs: [UUID]) -> [Peripheral] {
    centralManager.retrieveConnectedPeripherals(
      withServices: serviceUUIDs.map { CBUUID($0) }
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
    jqLogger.info("Connect to \(peripheral.name ?? peripheral.identifier.uuidString)")
    centralManager.connect(peripheral.peripheral, options: options)
  }

  func cancelPeripheralConnection(_ peripheral: Peripheral) {
    guard let peripheral = peripheral as? PeripheralImplementation else {
      preconditionFailure("Unable to convert peripheral as CBPeripheral.")
    }
    jqLogger.info("Cancel connection: \(peripheral.name ?? peripheral.identifier.uuidString)")
    centralManager.cancelPeripheralConnection(peripheral.peripheral)
  }
}

extension CBManagerState: CustomStringConvertible {

  /// :nodoc:
  public var description: String {
    switch self {
    case .unknown:
      return "Unknown"
    case .poweredOn:
      return "Power On"
    case .poweredOff:
      return "Power Off"
    case .resetting:
      return "Resetting"
    case .unauthorized:
      return "Unauthorized"
    case .unsupported:
      return "Unsupported"
    @unknown default:
      assertionFailure("Unknown default switch case")
      return "Unknown default switch case"
    }
  }
}

extension CentralManagerImplementation: CBCentralManagerDelegate {

  func centralManagerDidUpdateState(_ central: CBCentralManager) {
    jqLogger.info("\(central.state.description)")
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
    jqLogger.info("Did connect: \(peripheral.name ?? peripheral.identifier.uuidString)")
    delegate?.centralManager(self, didConnect: PeripheralImplementation(peripheral: peripheral))
  }

  func centralManager(
    _ central: CBCentralManager,
    didFailToConnect peripheral: CBPeripheral,
    error: Error?
  ) {
    jqLogger.info("Did fail to connect: \(peripheral.name ?? peripheral.identifier.uuidString)")
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
    jqLogger.info("Did disconnect: \(peripheral.name ?? peripheral.identifier.uuidString)")
    delegate?.centralManager(
      self,
      didDisconnectPeripheral: PeripheralImplementation(peripheral: peripheral),
      error: error
    )
  }

  func centralManager(_ central: CBCentralManager, willRestoreState dict: [String: Any]) {
    jqLogger.info("willRestoreState for \(dict)")
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
