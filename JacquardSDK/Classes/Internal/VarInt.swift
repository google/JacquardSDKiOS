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

/// Helps to encode/decode data represented in Varint format, this representation is generally
/// being used to encode protocol buffer messages.
enum Varint {

  /// Encode integer in Varint format.
  ///
  /// - Parameter value: Integer to encode. Must be 0 or any positive integer.
  /// - Returns: Encoded data.
  static func encode(value: Int) -> Data {
    guard value >= 0 else {
      jqLogger.preconditionAssertFailure("Value must be 0 or any positive number.")
      return Data()
    }
    var data = Data()
    var currentValue = value

    while true {
      if (currentValue & ~0x7F) == 0 {
        data.append(UInt8(currentValue) & 0xFF)
        return data
      } else {
        data.append(UInt8(currentValue & 0x7F) | 0x80)
        currentValue = currentValue >> 7
      }
    }
  }

  static func decode(data encoded: Data) -> (bytesConsumed: Int, value: Int) {
    // Inspect first bytes for packet length to remove 0x00 padding
    var currentByteValue = encoded[0]

    if currentByteValue & UInt8(0x80) == 0 {  // Non-negative is valid value
      return (1, Int(currentByteValue & 0x7f))
    }

    var value = Int32(currentByteValue & 0x7f)  // mask of MSB for real value
    var shift = 7
    var bytesConsumed = 1
    while true {
      currentByteValue = encoded[bytesConsumed]
      bytesConsumed += 1
      if currentByteValue & UInt8(0x80) == 0 {
        let shifted = Int32(currentByteValue) << shift
        value = value | shifted
        return (bytesConsumed, Int(value))
      } else {
        value = value | Int32(currentByteValue & 0x7f) << shift
        shift += 7
      }
    }
  }
}
