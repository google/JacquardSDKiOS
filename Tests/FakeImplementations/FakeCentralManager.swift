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

final class FakeCentralManager: CentralManagerProtocol {

  private let queue: DispatchQueue

  // `fakeState` sets the `state` property.
  var fakeState = CBManagerState.unknown {
    didSet {
      queue.async {
        self.delegate?.centralManagerDidUpdateState(CBCentralManager())
      }
    }
  }

  var state: CBManagerState { fakeState }

  var delegate: CBCentralManagerDelegate?

  init(delegate: CBCentralManagerDelegate, queue: DispatchQueue = .main) {
    self.delegate = delegate
    self.queue = queue
  }

  func scanForPeripherals(withServices serviceUUIDs: [CBUUID]?, options: [String: Any]?) {

  }

  func stopScan() {

  }

  func retrieveConnectedPeripherals(withServices serviceUUIDs: [CBUUID]) -> [CBPeripheral] {
    []
  }

  func retrievePeripherals(withIdentifiers identifiers: [UUID]) -> [CBPeripheral] {
    []
  }

  func connect(_ peripheral: CBPeripheral, options: [String: Any]?) {

  }

  func cancelPeripheralConnection(_ peripheral: CBPeripheral) {

  }
}
