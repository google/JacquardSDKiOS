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

extension Bundle {

  /// Created `Empty` class to find the test Bundle in non-SPM situations.
  class Empty {}

  static var test: Bundle {
    #if SWIFT_PACKAGE
      return Bundle.module
    #else
      return Bundle(for: Empty.self)
    #endif
  }
}
