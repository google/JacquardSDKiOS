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

import XCTest

@testable import JacquardSDK

class VersionTests: XCTestCase {
  func testInit() {
    let fromInt = Version(major: 1, minor: 2, micro: 3)
    let fromUInt32 = Version(major: UInt32(1), minor: UInt32(2), micro: UInt32(3))
    XCTAssertEqual(fromInt, fromUInt32)
    XCTAssertEqual(fromInt.major, 1)
    XCTAssertEqual(fromInt.minor, 2)
    XCTAssertEqual(fromInt.micro, 3)
  }

  func testLessThan() {
    XCTAssert(Version(major: 0, minor: 0, micro: 1) < Version(major: 0, minor: 0, micro: 2))
    XCTAssert(Version(major: 0, minor: 0, micro: 2) < Version(major: 0, minor: 1, micro: 0))
    XCTAssert(Version(major: 0, minor: 1, micro: 2) < Version(major: 0, minor: 2, micro: 0))
    XCTAssert(Version(major: 1, minor: 2, micro: 3) < Version(major: 2, minor: 0, micro: 0))
  }

  func testEquatable() {
    XCTAssertEqual(Version(major: 0, minor: 0, micro: 1), Version(major: 0, minor: 0, micro: 1))
    XCTAssertEqual(Version(major: 0, minor: 0, micro: 2), Version(major: 0, minor: 0, micro: 2))
    XCTAssertEqual(Version(major: 0, minor: 1, micro: 2), Version(major: 0, minor: 1, micro: 2))
    XCTAssertEqual(Version(major: 1, minor: 2, micro: 3), Version(major: 1, minor: 2, micro: 3))
  }

  func testDescription() {
    XCTAssertEqual(Version(major: 0, minor: 0, micro: 1).description, "v0.0.1")
    XCTAssertEqual(Version(major: 0, minor: 0, micro: 2).description, "v0.0.2")
    XCTAssertEqual(Version(major: 0, minor: 1, micro: 2).description, "v0.1.2")
    XCTAssertEqual(Version(major: 1, minor: 2, micro: 3).description, "v1.2.3")
    XCTAssertEqual(Version(major: 100, minor: 0, micro: 0).description, "v100.0.0")
  }
}
