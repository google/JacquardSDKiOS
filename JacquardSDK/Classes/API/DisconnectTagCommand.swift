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

/// Command to request that the tag disconnects the Bluetooth connection.
///
/// - SeeAlso: `Commands`
public struct DisconnectTagCommand: CommandRequest {
  /// `DisconnectTagCommand` response value is Void to indicate success.
  public typealias Response = Void

  /// Timeout in seconds to wait before disconnecting the tag.
  let timeoutSecond: UInt32
  /// Whether to reconnect only on wake on motion.
  let reconnectOnlyOnWom: Bool

  /// Initializes command.
  ///
  /// - Parameters:
  ///   - timeoutSecond: Time to wait before disconnection.
  ///   - reconnectOnlyOnWom: Reconnect only when the tag moves/wakes (default is to immediately reconnect).
  public init(timeoutSecond: UInt32 = 0, reconnectOnlyOnWom: Bool = false) {
    self.timeoutSecond = timeoutSecond
    self.reconnectOnlyOnWom = reconnectOnlyOnWom
  }
}
