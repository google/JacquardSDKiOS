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

typealias Identifier = UInt32

extension Identifier {
  func hexString() -> String {
    let hex = String(format: "%08x", self)
    return String(
      stride(from: 0, to: Array(hex).count, by: 2).map {
        Array(Array(hex)[$0..<Swift.min($0 + 2, Array(hex).count)])
      }.joined(separator: "-"))
  }
}
