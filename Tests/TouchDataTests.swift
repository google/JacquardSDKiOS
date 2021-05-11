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

extension TouchData: Equatable {
  public static func == (lhs: TouchData, rhs: TouchData) -> Bool {
    return lhs.sequence == rhs.sequence && lhs.proximity == rhs.proximity
      && lhs.lines.0 == rhs.lines.0 && lhs.lines.1 == rhs.lines.1 && lhs.lines.2 == rhs.lines.2
      && lhs.lines.3 == rhs.lines.3 && lhs.lines.4 == rhs.lines.4 && lhs.lines.5 == rhs.lines.5
      && lhs.lines.6 == rhs.lines.6 && lhs.lines.7 == rhs.lines.7 && lhs.lines.8 == rhs.lines.8
      && lhs.lines.9 == rhs.lines.9 && lhs.lines.10 == rhs.lines.10 && lhs.lines.11 == rhs.lines.11
  }
}

class TouchDataTests: XCTestCase {

  func testInit() {
    let td0 = TouchData(sequence: 0, proximity: 0, lines: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0))
    XCTAssertEqual(td0, TouchData.empty)

    let td1 = TouchData(sequence: 1, proximity: 2, lines: (1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12))
    let proto = Google_Jacquard_Protocol_TouchData.with {
      $0.sequence = 1
      $0.diffDataScaled = Data([2, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12])
    }
    let td2 = TouchData(proto)
    XCTAssertEqual(td1, td2)
  }

  func testLinesArray() {
    let td = TouchData(sequence: 1, proximity: 2, lines: (1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12))
    XCTAssertEqual(td.linesArray, [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12])
  }
}
