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

/// Represents a firmware version made up of a sequence of digits labeled major, minor and micro.
public struct Version: Codable {

  /// The first component of the version sequence. This is the most significant component.
  var major: Int

  /// The second component of the version sequence.
  var minor: Int

  /// The third component of the version sequence. This is the least significant component.
  var micro: Int

  init(major: Int, minor: Int, micro: Int) {
    self.major = major
    self.minor = minor
    self.micro = micro
  }

  init(major: UInt32, minor: UInt32, micro: UInt32) {
    self.major = Int(major)
    self.minor = Int(minor)
    self.micro = Int(micro)
  }
}

extension Version: Comparable {

  /// Compares two `Version` objects to determine if the first is _less than_ the second.
  ///
  /// The criteria for this comparison is to check each component, from major to micro.
  ///
  /// - Parameter version: the `Version` object to compare to.
  /// - Returns: `true` if the caller is found to be a lower version than the parameter; `false`
  ///            otherwise.
  func isLessThan(version: Version) -> Bool {
    if major < version.major {
      return true
    } else if major == version.major {
      if minor < version.minor {
        return true
      } else if minor == version.minor {
        if micro < version.micro {
          return true
        }
      }
    }
    return false
  }

  /// Compares two `Version` objects to determine if the first is _less than_ the second.
  ///
  /// - Parameters:
  ///   - lhs: a `Version` object.
  ///   - rhs: an additional `Version` object.
  /// - Returns: `true` if the first object's deemed less than the second; `false` otherwise.
  public static func < (lhs: Version, rhs: Version) -> Bool {
    return lhs.isLessThan(version: rhs)
  }
}

extension Version: CustomStringConvertible {
  public var description: String {
    return "v\(major).\(minor).\(micro)"
  }
}

extension Version {

  /// Describes the expected format in which firmware images are stored in Firebase.
  /// Format is MMMmmmuuu where MMM is major, mmm is minor and uuu is micro.
  /// For instance, Version 12.2.48 would be found as 012002048.
  enum VersionFormat {
    static let majorVersionEndIndex = 3
    static let minorVersionEndIndex = 6
  }

  /// Provides list of bad firmware versions.
  static var badFirmwares: [Version] {

    guard let fileURL = Bundle.sdk.url(forResource: "BadFirmwareVersion", withExtension: "json")
    else {
      return []
    }

    guard let data = try? Data(contentsOf: fileURL) else { return [] }

    return (try? JSONDecoder().decode([Version].self, from: data)) ?? []
  }

  /// Representation in 9 digit string format, for instance, Version 12.2.48 would be represented
  /// as 012002048.
  var asDecimalEncodedString: String {
    return String(format: "%03d%03d%03d", major, minor, micro)
  }

  /// Returns a version object created from a 9 digit string.
  ///
  /// - Parameter string: the string formatted as 9 digits.
  /// - Returns: the `Version` object created or `nil` if the format is invalid.
  public static func version(fromDecimalEncodedString string: String) -> Version {
    guard !(string.count != 9 || Int(string) == nil) else {
      return Version(major: 0, minor: 0, micro: 0)
    }
    var rangeStart = string.startIndex
    var rangeEnd = string.index(
      string.startIndex,
      offsetBy: VersionFormat.majorVersionEndIndex
    )
    var range = rangeStart..<rangeEnd

    let majorString = string[range]

    rangeStart = string.index(
      string.startIndex,
      offsetBy: VersionFormat.majorVersionEndIndex
    )
    rangeEnd = string.index(
      string.startIndex,
      offsetBy: VersionFormat.minorVersionEndIndex
    )
    range = rangeStart..<rangeEnd

    let minorString = string[range]
    rangeStart = string.index(
      string.startIndex,
      offsetBy: VersionFormat.minorVersionEndIndex
    )
    rangeEnd = string.endIndex
    range = rangeStart..<rangeEnd

    let microString = string[range]

    guard let major = UInt32(majorString),
      let minor = UInt32(minorString),
      let micro = UInt32(microString)
    else {
      return Version(major: 0, minor: 0, micro: 0)
    }
    return Version(major: major, minor: minor, micro: micro)
  }
}
