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

/// Data describing the current touch.
public struct TouchData {
  /// Describes the touch intensity at 12 points across the Jacquard fabric.
  /// The values range from 0 -> 128, Where 128 is the max intensity and 0 indicates Line is not touched
  public typealias Lines = (
    UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8
  )

  /// The sequence number of this touch in a continuous sequence of touches.
  ///
  /// Ie. if a received sequence number is less than the last observed sequence numbers, the finger was lifted between them.
  /// Note that not all touches will be delivered, so the sequence numbers will have gaps.
  public var sequence: UInt32

  /// The overall proximity of the touch.
  public var proximity: UInt32
  /// Describes the touches.
  public var lines: Lines

  /// Convenience accessor returns the 12 `UInt8` values in `lines` in a `[UInt8]`.
  public var linesArray: [UInt8] {
    let tupleMirror = Mirror(reflecting: lines)
    return tupleMirror.children.map { $0.value as! UInt8 }
  }

  /// Creates an empty instance.
  ///
  /// Useful for initializing a var to avoid an unnecessary Optional.
  public static var empty: TouchData {
    return self.init(
      sequence: 0,
      proximity: 0,
      lines: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
    )
  }
}

/// Notification to observe  `TouchData` events.
///
/// - SeeAlso: `Notifications`
public struct ContinuousTouchNotificationSubscription: NotificationSubscription {
  /// The response type published when an event is received.
  public typealias Notification = TouchData

  /// Initialize a subscription request.
  public init() {}
}
