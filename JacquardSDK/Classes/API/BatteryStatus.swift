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

/// Describes the current battery status.
public struct BatteryStatus {
  /// Describes the current battery charging state.
  public enum ChargingState {
    /// The battery is being charged via the tag's USB port.
    case charging
    /// The battery is not being charged.
    case notCharging
  }
  /// Battery level in % (ie. 0 to 100).
  public var batteryLevel: UInt32
  /// The current battery charging state.
  public var chargingState: ChargingState

}

/// Command to read the current `BatteryStatus`.
///
/// - SeeAlso: `Commands`
public struct BatteryStatusCommand: CommandRequest {
  /// The response type published when the command is successful.
  public typealias Response = BatteryStatus

  /// Initialize a command request.
  public init() {}
}

/// Notification to observe periodic `BatteryStatus` updates.
///
/// There will always be one notification directly after connection.
///
/// - SeeAlso: `Notifications`
public struct BatteryStatusNotificationSubscription: NotificationSubscription {
  /// The response type published when a notification is received.
  public typealias Notification = BatteryStatus

  /// Initialize a subscription request.
  public init() {}
}
