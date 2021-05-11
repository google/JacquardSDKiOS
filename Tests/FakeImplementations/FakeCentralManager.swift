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
import Foundation

@testable import JacquardSDK

final class FakeCentralManager: CentralManager {

  private let queue: DispatchQueue
  lazy private var peripherals = [peripheral]
  lazy private(set) var peripheral = FakePeripheralImplementation(
    identifier: uuid,
    name: deviceName
  )

  let deviceName = "Fake Device"
  let uuid = UUID(uuidString: "BD415750-8EF1-43EE-8A7F-7EF1E365C35E")!
  var delegate: CentralManagerDelegate?
  var stopScanCompletion: ((Bool) -> Void)?

  private var fakeService: CBService {
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

    let rawDataUUID = CBUUID(string: "D2F2B8D2-D165-445C-B0E1-2D6B642EC57B")
    let rawDataCharacteristic = CBMutableCharacteristic(
      type: rawDataUUID,
      properties: [.notify],
      value: nil,
      permissions: .readable
    )

    service.characteristics = [
      commandCharacteristic, responseCharacteristic, notifyCharacteristic, rawDataCharacteristic,
    ]

    return service
  }

  var state: CBManagerState = .unknown {
    didSet {
      queue.async {
        self.delegate?.centralManagerDidUpdateState(self.state)
      }
    }
  }

  init(
    delegate: CentralManagerDelegate,
    queue: DispatchQueue = .main,
    options: [String: String]? = nil
  ) {
    self.queue = queue
    self.delegate = delegate
    peripheral.services = [fakeService]
  }

  func scanForPeripherals(
    withServices serviceUUIDs: [PeripheralUUID]?,
    options: [String: Any]? = nil
  ) {
    queue.async {
      let advertisementData =
        [CBAdvertisementDataManufacturerDataKey: Data([224, 0, 0, 48, 108, 63])]
      self.delegate?.centralManager(
        self,
        didDiscover: self.peripheral,
        advertisementData: advertisementData,
        rssi: -78
      )
    }
  }

  func stopScan() {
    queue.async {
      self.stopScanCompletion?(true)
    }
  }

  func retrieveConnectedPeripherals(withServices serviceUUIDs: [PeripheralUUID]) -> [Peripheral] {
    peripherals
  }

  func retrievePeripherals(withIdentifiers identifiers: [UUID]) -> [Peripheral] {
    peripherals.filter { $0.identifier == identifiers.first }
  }

  func connect(_ peripheral: Peripheral, options: [String: Any]?) {
    queue.async {
      self.peripheral.callbackType = .didDiscoverServices
      self.delegate?.centralManager(self, didConnect: peripheral)
    }
  }

  func cancelPeripheralConnection(_ peripheral: Peripheral) {
    queue.async {
      self.delegate?.centralManager(self, didDisconnectPeripheral: peripheral, error: nil)
    }
  }

  func restoreConnection() {
    queue.async {
      self.delegate?.centralManager(self, willRestoreState: self.peripherals)
    }
  }
}
