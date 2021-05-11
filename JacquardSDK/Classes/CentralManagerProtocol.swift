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

/// Provides `CentralManager` updates.
protocol CentralManagerDelegate {

  /// Provides updates for the central manager's state.
  func centralManagerDidUpdateState(_ central: CBManagerState)

  /// Invoked while scanning, upon the discovery of peripheral by central manager. A discovered
  /// peripheral must be retained in order to use it; otherwise, it is assumed to not be of interest
  /// and will be cleaned up by the central manager.
  func centralManager(
    _ central: CentralManager,
    didDiscover peripheral: Peripheral,
    advertisementData: [String: Any],
    rssi rssiValue: NSNumber
  )

  /// Invoked when a connection has succeeded.
  func centralManager(_ central: CentralManager, didConnect peripheral: Peripheral)

  /// Invoked when a connection has failed to complete. As connection attempts do not
  /// timeout, the failure of a connection is atypical and usually indicative of a transient issue.
  func centralManager(
    _ central: CentralManager, didFailToConnect peripheral: Peripheral, error: Error?
  )

  /// Invoked upon the disconnection of a peripheral.
  func centralManager(
    _ central: CentralManager, didDisconnectPeripheral peripheral: Peripheral, error: Error?
  )

  /// For apps that opt-in to state preservation and restoration, this is the first method invoked
  /// when your app is relaunched into the background to complete some Bluetooth-related task.
  /// Use this method to synchronize your app's state with the state of the Bluetooth system.
  func centralManager(_ central: CentralManager, willRestoreState peripherals: [Peripheral])
}

/// Wrapper protocol for `CBCentralManager`.
///
/// Provides methods like scan for peripheral, retrieve connected peripherals, connect/disconnect
/// with peripherals.
protocol CentralManager {

  /// Bluetooth state.
  var state: CBManagerState { get }

  /// Provides updates for central manager object like connection/disconnection, scan, retrieval of
  /// peripheral.
  var delegate: CentralManagerDelegate? { get }

  /// Starts scanning for peripherals that are advertising any of the services listed.
  func scanForPeripherals(withServices serviceUUIDs: [PeripheralUUID]?, options: [String: Any]?)

  /// Stops scanning for peripherals.
  func stopScan()

  /// Retrieves all peripherals that are connected to the system and implement any of the services
  /// listed in serviceUUIDs.
  func retrieveConnectedPeripherals(withServices serviceUUIDs: [PeripheralUUID]) -> [Peripheral]

  /// Attempts to retrieve the `CBPeripheral` with the corresponding identifiers.
  func retrievePeripherals(withIdentifiers identifiers: [UUID]) -> [Peripheral]

  /// Initiates a connection to peripheral.
  func connect(_ peripheral: Peripheral, options: [String: Any]?)

  /// Cancels an active or pending connection to peripheral.
  func cancelPeripheralConnection(_ peripheral: Peripheral)
}
