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

/// Discovers and connects to Jacquard tags.
///
/// In normal use, you will obtain a singleton instance via `sharedJacquardManager`.
public protocol JacquardManager {
  /// Convenience initializer.
  ///
  /// You should only create one instance of `JacquardManagerImplementation`.
  ///
  /// - Parameters:
  ///  - publishQueue: A dispatch queue that all publishers and callbacks will be delivered on.
  ///  - options: An optional dictionary specifying options for the manager. Keys are
  ///             defined in [CBCentralManager initialization
  ///             options](https://developer.apple.com/documentation/corebluetooth/cbcentralmanager/central_manager_initialization_options).
  init(publishQueue: DispatchQueue, options: [String: String]?)

  /// Publishes the current state of the `CBPeripheralManager`.
  ///
  /// This will immediately publish the current state as well as any future changes.
  var centralState: AnyPublisher<CBManagerState, Never> { get }

  /// Start scanning for connectable Jacquard tags.
  ///
  /// Discovered tags will be published to `advertisingTags`.  Ensure`centralState` is `CBManagerState.poweredOn`
  /// before calling this method.
  ///
  /// You should call `stopScanning()` when you no longer need to observe advertising tags.
  ///
  /// - Throws `JacquardManagerScanningError`.
  func startScanning() throws

  /// Stops scanning for connectable Jacquard tags.
  func stopScanning()

  /// Publishes any found Jacquard tags.
  ///
  /// Tags well be discovered once `startScanning()` is called. You can pass an instance of
  /// `AdvertisedTag` to `.connect(_:)`.
  var advertisingTags: AnyPublisher<AdvertisedTag, Never> { get }

  /// Returns any Jacquard tags already connected to the phone.
  ///
  /// You can pass UUID `PreConnectedTag.identifier` to `.connect(_:)`
  func preConnectedTags() -> [PreConnectedTag]

  /// Connects to a connectable tag.
  ///
  /// The publisher returned by this method will always publish the current state (which includes the
  /// current `ConnectedTag` instance in the case of `.connected`) when any new subscription is made.
  ///
  /// - Parameter identifier: an instance that conforms to `ConnectableTag` (which you can
  ///                         obtain either via `.advertisedTags` or `.preConnectedTags()`.
  func connect(_ tag: ConnectableTag) -> AnyPublisher<TagConnectionState, Error>

  /// Connect to a known tag by identifier.
  ///
  /// `connect(_ tag:)` should be used in preference when you have obtained an `AdvertisedTag` instance from
  /// scanning, or have a `PreConnectedTag` instance from `preConnectedTags()`. This method is useful when you
  /// have persisted a UUID and wish to attempt a connection.
  ///
  /// If a bluetooth with this UUID is not known to Core Bluetooth, the publisher will complete with error
  /// `TagConnectionError.bluetoothDeviceNotFound`.
  ///
  /// The publisher returned by this method will always publish the current state (which includes the
  /// current `ConnectedTag` instance in the case of `.connected`) when any new subscription is made.
  ///
  /// - Parameter identifier: UUID  from `JacquardTag.identifier`.
  func connect(_ identifier: UUID) -> AnyPublisher<TagConnectionState, Error>

  /// Disconnect to a known tag by identifier.
  ///
  /// `disconnect(_ tag:)` This method is useful when you have to cancel an active connection.
  ///
  /// If this peripheral is not known to Core Bluetooth, the publisher will complete with error
  /// `TagConnectionError.bluetoothDeviceNotFound`.
  ///
  /// - Parameter tag: a connected tag
  func disconnect(_ tag: ConnectedTag) -> AnyPublisher<TagConnectionState, Error>
}

/// Errors thrown by `JacquardManager.startScanning()`.
public enum ManagerScanningError: Error {
  /// Scanning could not be started because bluetooth is unavailable.
  case bluetoothUnavailable(CBManagerState)
}

/// The errors which can be raised when connecting to a tag.
public enum TagConnectionError: Error {
  /// An error occurred within the SDK code itself.
  ///
  /// Please raise a bug if you encounter this error.
  case internalError
  /// A bad response was read over Bluetooth.
  ///
  /// This error will normally cause an automatic retry. Please raise a bug if you encounter this error.
  case malformedResponseError
  /// An unexpected CoreBluetooth response was received, but no error was present.
  case unknownCoreBluetoothError
  /// A CoreBluetooth error was encountered during connection or service/characteristic discovery.
  case bluetoothConnectionError(Error)
  /// CoreBluetooth reported a notification error.
  ///
  /// This error will normally cause an automatic retry. Please raise a bug if you encounter this error.
  case bluetoothNotificationUpdateError(Error)
  /// An error was encountered attempting to discover the Bluetooth services.
  case serviceDiscoveryError
  /// An error was encountered attempting to discover the Bluetooth characteristics.
  case characteristicDiscoveryError
  /// An error was encountered when initializing the Jacquard tag and protocol.
  case jacquardInitializationError(Error)
  /// The bluetooth peripheral could not be found by Core Bluetooth.
  case bluetoothDeviceNotFound
  /// An unexpected type of tag was passed into `connect(_tag:)`.
  case unconnectableTag
}
