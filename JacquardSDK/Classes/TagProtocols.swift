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
import Foundation

/// Base protocol for all types of Tag types.
public protocol JacquardTag {
  /// Unique identify of the peripheral instance in the current running app on the current iOS
  /// device. (peripheral uuid)
  var identifier: UUID { get }
  /// A human readable string describing the tag.
  ///
  /// Note that this value may change over time, eg. when CoreBluetooth updates the name for a connected tag.
  var displayName: String { get }
}

/// The available Gear touch modes
///
/// - SeeAlso: `ConnectedTag.setTouchMode(_:,for:)`
public enum TouchMode {
  /// The tag will interpret touch patterns into discrete `Gesture`s.
  ///
  /// - SeeAlso: `GestureNotificationSubscription`
  case gesture
  /// The tag will publish raw `TouchData` events.
  ///
  /// - SeeAlso: `ContinuousTouchNotificationSubscription`
  case continuous
}

/// The tag type that indicates a tag which is not yet connected or initialized by `JacquardManager`.
public protocol ConnectableTag: JacquardTag {}

/// The tag type for advertising (but not connected) tags.
public protocol AdvertisedTag: ConnectableTag {
  /// SerialNumber number used during pairing. Last 4 digit of the UJT serial number.
  var pairingSerialNumber: String { get }
}

/// The tag type for tags already paired earlier.
public protocol PreConnectedTag: ConnectableTag {
  /// Peripheral Identifier of the Tag.
  var identifier: UUID { get }
}

/// The tag type available for subscribing to notifications.
///
/// - SeeAlso: `ConnectedTag.registerSubscriptions(_:)`
public protocol SubscribableTag {
  /// Subscribe to a notification.
  ///
  /// The published event will be received on the queue passed into `JacquardManager.init(publishQueue:)`
  func subscribe<S: NotificationSubscription>(_ subscription: S) -> AnyPublisher<
    S.Notification, Never
  >
}

/// The tag type for connected tags.
public protocol ConnectedTag: JacquardTag {
  /// Name of the tag.
  var name: String { get }

  /// Once the BLE device name is known, this stream will publish immediately on connection, in addition to future updates.
  var namePublisher: AnyPublisher<String, Never> { get }

  /// Tags have component capabilities (like attached Gear), eg. LED.
  var tagComponent: Component { get }

  /// Publishes a value every time Gear is attached or detached.
  ///
  /// - SeeAlso: `Components and Gear`
  var connectedGear: AnyPublisher<Component?, Never> { get }

  /// Switches attached gear between the different touch modes.
  ///
  /// - Parameters:
  ///   - newTouchMode: the desired mode
  ///   - component: a currently attached Gear component.
  /// - Returns a stream which will publish exactly one value of type `Void` (indicating a
  ///   successful mode change) or complete with an error.
  func setTouchMode(_ newTouchMode: TouchMode, for component: Component) -> AnyPublisher<
    Void, Error
  >

  /// Writes the specified tag name into the connected tag hardware.
  ///
  /// This causes the tag to disconnect, the tag firmware will then automatically reconnect.
  /// - Parameters:
  ///   - name: the new name to be set.
  /// - Returns a stream which will publish exactly one value of type `Void` (indicating a
  ///   successful name change) or complete with an error.
  /// - throws `SetNameError` if the new name to be set is same as existing one, or is an empty
  ///   string or is longer than 21 characters.
  func setName(_ name: String) throws -> AnyPublisher<Void, Error>

  /// Send a command, retrying in case of failure.
  ///
  /// This will attempt to send up to three times.
  ///
  /// The published event will be received on the queue passed into `JacquardManager.init(publishQueue:)`
  ///
  /// - Parameter commandRequest: the request.
  /// - Returns a stream which will publish exactly one value of type `R.Response` or complete with an error.
  func enqueue<R: CommandRequest>(_ commandRequest: R) -> AnyPublisher<R.Response, Error>

  /// Send a command, retrying in case of failure.
  ///
  /// The published event will be received on the queue passed into `JacquardManager.init(publishQueue:)`
  ///
  /// - Parameters:
  ///   - commandRequest: the request.
  ///   - retries: number of retries for serializing the request data to be sent over BLE
  ///   (eg. a value of 2 means attempt a totally of three times).
  /// - Returns a stream which will publish exactly one value of type `R.Response` or complete with an error.
  func enqueue<R: CommandRequest>(_ commandRequest: R, retries: Int) -> AnyPublisher<
    R.Response, Error
  >

  /// Provides access to a `SubscribableTag` instance, allowing registering tag notification subscriptions.
  ///
  /// The `SubscribableTag` instance should only be used within the closure. It is important that you
  /// register all notifications that should work in the background the first time you use this method on each connected
  /// tag instance.
  ///
  /// - SeeAlso: `Notifications`
  /// - Parameter subscriptions: A closure where the subscriptions may be registered.
  func registerSubscriptions(_ subscriptions: (SubscribableTag) -> Void)
}

/// The states published by the tag connection publisher.
public enum TagConnectionState {
  /// This is initial state, and also the state while waiting for reconnection.
  ///
  /// To conserve battery if the Jacqaurd tag is kept idle for 10 Minutes it will drop BLE connection.
  /// This state is also transitioned when the tag is moves out of the Bluetooth range of the mobile device.
  case preparingToConnect
  /// Connecting with approximate progress.
  ///
  /// First Int is the current step, second Int is total number of steps (including initializing)
  case connecting(Int, Int)
  /// Initializing with approximate progress.
  ///
  /// First Int is the current step, second Int is total number of steps. This continues on from the progress reported by the
  /// `connecting` state.
  case initializing(Int, Int)
  /// Configuring with approximate progress.
  ///
  /// First Int is the current step, second Int is total number of steps. This continues on from the progress reported by the
  /// `initializing` state.
  case configuring(Int, Int)
  /// Note this is not a terminal state - the stream may bo back to disconnected, and then subsequently reconnect again.
  case connected(ConnectedTag)
  /// This terminal state will only be reached if reconnecting or retrying is not possible.
  case disconnected(Error?)
}

/// Errors that can occur while setting a name for the tag.
public enum SetNameError: Swift.Error {
  /// Throw this error if the name to be set is not valid or not within the supported range.
  case invalidParameter
}
