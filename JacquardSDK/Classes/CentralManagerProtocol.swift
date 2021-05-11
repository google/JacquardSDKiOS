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

/// Wrapper protocol for `CBCentralManager`.
///
/// Provides methods like scan for peripheral, retrieve connected peripherals, connect/disconnect
/// with peripherals.
///
/// :nodoc:
public protocol CentralManagerProtocol {

  /// Bluetooth state.
  var state: CBManagerState { get }

  /// Provides updates for central manager object like connection/disconnection, scan, retrieval of
  /// peripheral.
  var delegate: CBCentralManagerDelegate? { get }

  /// Starts scanning for peripherals that are advertising any of the services listed.
  func scanForPeripherals(withServices serviceUUIDs: [CBUUID]?, options: [String: Any]?)

  /// Stops scanning for peripherals.
  func stopScan()

  /// Retrieves all peripherals that are connected to the system and implement any of the services
  /// listed in serviceUUIDs.
  func retrieveConnectedPeripherals(withServices serviceUUIDs: [CBUUID]) -> [CBPeripheral]

  /// Attempts to retrieve the `CBPeripheral` with the corresponding identifiers.
  func retrievePeripherals(withIdentifiers identifiers: [UUID]) -> [CBPeripheral]

  /// Initiates a connection to peripheral.
  func connect(_ peripheral: CBPeripheral, options: [String: Any]?)

  /// Cancels an active or pending connection to peripheral.
  func cancelPeripheralConnection(_ peripheral: CBPeripheral)
}

/// :nodoc:
extension CBCentralManager: CentralManagerProtocol {}
