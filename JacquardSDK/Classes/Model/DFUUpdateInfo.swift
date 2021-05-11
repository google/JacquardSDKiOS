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

/// Provides dfu update status.
public enum DFUUpdateInfoStatus: String, Codable {
  /// Firmware update is required.
  case mandatory

  /// Firmware update is optional and can be skipped.
  case optional

  /// There are no firmware updates available.
  case none
}

/// Provides firmware update related information.
public struct DFUUpdateInfo: Codable {

  /// Date on which firmware is updated.
  public let date: String?

  /// Version of the component for which update is requested.
  public let version: String

  /// DFU update type it can be mandatory or optional or none.
  public let dfuStatus: DFUUpdateInfoStatus

  /// VendorId of the component, tag/interposer/module.
  public let vid: String

  /// ProductId of the component, tag/interposer/module.
  public let pid: String

  /// The module ID.
  public var mid: String?

  /// Download URL for the firmware update.
  let downloadURL: String?

  /// Binary image of the component, downloaded from  the `downloadURL`.
  var image: Data?

  enum CodingKeys: String, CodingKey {
    case date
    case version
    case dfuStatus
    case vid
    case pid
    case mid
    case downloadURL = "downloadUrl"
    case image
  }
}

extension DFUUpdateInfo: Equatable {
  public static func == (lhs: DFUUpdateInfo, rhs: DFUUpdateInfo) -> Bool {
    lhs.vid == rhs.vid
      && lhs.pid == rhs.pid
      && lhs.mid == rhs.mid
      && lhs.version == rhs.version
      && lhs.image != nil
  }
}
