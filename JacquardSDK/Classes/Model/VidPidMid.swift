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

/// Represents properties for any component. i.e. tag/interposer/module.
public struct VidPidMid {
  /// VendorId of the component, tag/interposer/module.
  public let vid: String

  /// ProductId of the component, tag/interposer/module.
  public let pid: String

  /// The module ID.
  public var mid: String?

  /// :nodoc:
  public init(vid: String, pid: String, mid: String? = nil) {
    self.vid = vid
    self.pid = pid
    self.mid = mid
  }
}
