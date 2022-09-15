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

import CoreBluetooth

/// Contains the known protocol versions.
enum ProtocolSpec: UInt32 {
  case unknown = 0

  /// Deprecated version.
  case version1 = 1

  /// Protocol version reported by UJT.
  case version2 = 2

  var mtu: Int {
    switch self {
    case .version2: return 64
    case .unknown, .version1: return 23
    }
  }
}

/// Provides tag constant details.
public enum TagConstants {

  /// Product identifier of Tag.
  public static let product = "28-3b-e7-a0"

  /// Vendor identifier of Tag.
  public static let vendor = "11-78-30-c8"

  /// Describes fixed component identifiers.
  enum FixedComponent: ComponentID {
    case tag = 0
  }
}

enum JacquardServices {
  // The Jacquard V2 protocol service
  static let v2Service = CBUUID(string: "D2F2BF0D-D165-445C-B0E1-2D6B642EC57B")

  // v2 characteristics
  // Used to send commands to the device.
  static let commandUUID = CBUUID(string: "D2F2EABB-D165-445C-B0E1-2D6B642EC57B")

  // Used to receive and process responses to commands given to the device.
  static let responseUUID = CBUUID(string: "D2F2B8D0-D165-445C-B0E1-2D6B642EC57B")

  // Used to get and react to notifications produced by the device.
  static let notifyUUID = CBUUID(string: "D2F2B8D1-D165-445C-B0E1-2D6B642EC57B")

  // Used to get raw data stream produced by the device.
  static let rawDataUUID = CBUUID(string: "D2F2B8D2-D165-445C-B0E1-2D6B642EC57B")

  static let v2Characteristics = [commandUUID, responseUUID, notifyUUID, rawDataUUID]
}
