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

/// Holds the data for a recorded IMU session.
///
/// - SeeAlso: `IMUSessionInfo` & `IMUSample`.
public struct IMUSessionData {
  /// Metadata for a recorded IMU session.
  public let metadata: IMUSessionInfo
  /// IMU Samples recorded during the IMU session.
  public let samples: [IMUSample]

  init(metadata: Google_Jacquard_Protocol_DataCollectionMetadata, samples: [IMUSample]) {
    let info = IMUSessionInfo(metadata: metadata)
    self.metadata = info
    self.samples = samples
  }
}

/// UJT contains an Inertial Measurement Unit (IMU) sensor that consists of an accelerometer and gyroscope.
///
/// This will hold the data for the sensors in vector, and the timestamp for the sample.
/// Binary format description: go/jacquard-dc-framework#heading=h.lgt57q4p2c8c
public struct IMUSample: Equatable {

  /// Accelerometer data for the sample.
  public var acceleration: Vector
  /// Gyroscope data for the sample.
  public var gyro: Vector
  /// Timestamp of the sample, Relative to the start of the recording.
  public var timestamp: UInt32

  /// :nodoc:
  public static func == (lhs: IMUSample, rhs: IMUSample) -> Bool {
    return lhs.timestamp == rhs.timestamp
  }

  /// :nodoc:
  public struct Vector {
    /// X axis data for accelerometer, also corresponds to Roll for gyroscope data.
    public var x: Int16
    /// Y axis data for accelerometer, also corresponds to Pitch for gyroscope data.
    public var y: Int16
    /// Z axis data for accelerometer, also corresponds to Yaw for gyroscope data.
    public var z: Int16
  }
}

extension IMUSample.Vector {
  // Assumes adequately sized buffer.
  fileprivate init(buffer: UnsafeMutablePointer<UInt8>) throws {
    // Need to initialize before capturing in closure.
    self.x = 0
    self.y = 0
    self.z = 0
    // Parse consecutive integer bytes into vectors x,y & z.
    buffer.withMemoryRebound(to: Int16.self, capacity: 3) { ptr in
      x = ptr.pointee
      y = ptr.successor().pointee
      z = ptr.successor().successor().pointee
    }
  }
}

extension IMUSample {
  init(buffer: UnsafeMutablePointer<UInt8>) throws {
    acceleration = try Vector(buffer: buffer)
    gyro = try Vector(buffer: buffer.advanced(by: 6))

    // Need to initialize before capturing in closure.
    self.timestamp = 0
    // 12 bytes because x,y,z data for acclerometer and gyro each take up 2 bytes.
    buffer.advanced(by: 12).withMemoryRebound(to: UInt32.self, capacity: 1) { ptr in
      timestamp = ptr.pointee
    }
  }
}
