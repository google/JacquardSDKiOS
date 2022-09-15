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

import SwiftTestReporter
import XCTest

/// This test class must be executed first.
///
/// This is necessary to allow `SwiftTestReporterInit` to create `tests.xml`.
/// See https://github.com/allegro/swift-junit/issues/12
class AAA_SwiftTestReporterInit: XCTestCase {
  override class func setUp() {
    _ = TestObserver()
    super.setUp()
  }

  /// No-op test method to be interpreted as a test case.
  func testInit() {}
}
