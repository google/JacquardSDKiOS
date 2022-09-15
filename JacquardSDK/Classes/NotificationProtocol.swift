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

import Foundation

/// Types that implement this protocol describe a notification subscription request and its
/// associated notification body type.
///
/// see also: `CommandRequest`
public protocol NotificationSubscription: NotificationParser {

  /// The type that will be published every time the appropriate notification is received.
  associatedtype Notification

  /// Extract the notification payload if the response outerProto contains it.
  ///
  /// :nodoc:
  func extract(from outerProto: Any) -> Notification?
}

/// Parses notification payload to required protobuf type received from Bluetooth.
public protocol NotificationParser {

  /// Parses notification packet received from Bluetooth.
  ///
  /// - Parameter packet: Raw data which contains notification payload.
  func parseNotification(_ packet: Data) throws -> V2ProtocolNotificationInjectable
}

extension NotificationParser {

  public func parseNotification(_ packet: Data) throws -> V2ProtocolNotificationInjectable {
    try Google_Jacquard_Protocol_Notification(
      serializedData: packet, extensions: Google_Jacquard_Protocol_Jacquard_Extensions)
  }
}
