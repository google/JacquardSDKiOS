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

/// This is a swift version of CRC-16-CCITT (polynomial 0x1021) with 0xFFFF initial value.
class CRC16 {
  static func compute(in data: Data, seed: UInt16 = 0xFFFF) -> UInt16 {
    let bytes = [UInt8](data)
    var crc = seed
    for byte in bytes {
      crc = UInt16(crc >> 8 | crc << 8)
      crc ^= UInt16(byte)
      crc ^= UInt16(UInt8(crc & 0xFF) >> 4)
      crc ^= (crc << 8) << 4
      crc ^= ((crc & 0xFF) << 4) << 1
    }
    return crc
  }
}
