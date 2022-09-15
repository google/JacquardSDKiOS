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
import SwiftProtobuf

struct IMUStreamDataParser {

  private let sampleLength = 16

  /// Parses raw bytes to get the stream of IMU samples.
  func parseIMUSamples(bytesData: [UInt8]) throws -> [IMUSample] {
    let expected = bytesData.count / sampleLength
    if expected == 0 {
      return []
    }
    var samples = [IMUSample]()
    for index in 0..<expected {
      samples.append(try parse(bytes: bytesData, offset: UInt8(index * sampleLength)))
    }
    return samples
  }

  private func parse(bytes: [UInt8], offset: UInt8) throws -> IMUSample {
    let sampleData: [UInt8] = Array(bytes[Int(offset)..<(Int(offset) + sampleLength)])
    return try parseIMUSample(bytes: sampleData)
  }

  private func parseIMUSample(bytes: [UInt8]) throws -> IMUSample {
    let readBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bytes.count)
    readBuffer.initialize(from: bytes, count: bytes.count)
    let sample = try IMUSample(buffer: readBuffer)
    return sample
  }

}
