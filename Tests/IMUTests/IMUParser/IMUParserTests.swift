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

class IMUParserTests: XCTestCase {

  func testParser() throws {

    let testBundle = Bundle(for: type(of: self))
    guard
      let path1 = testBundle.path(forResource: "imu1", ofType: "bin"),
      let stream = InputStream(fileAtPath: path1)
    else {
      throw IMUParsingError.fileCouldNotBeOpened
    }
    let parser = try IMUParser(stream)

    let parsedAction = try parser.readAction()

    guard
      let samples1 = parsedAction?.samples,
      let completed = parsedAction?.completedSuccessfully
    else {
      XCTFail("Parsing ended without samples")
      return
    }

    XCTAssertEqual(completed, true)
    XCTAssertEqual(samples1.count, 1698)
    XCTAssertEqual(
      samples1[0],
      IMUSample(
        acceleration: .init(x: 973, y: -1418, z: -1236),
        gyro: .init(x: 3541, y: 3336, z: -1373),
        timestamp: 991540
      )
    )

    guard
      let path2 = testBundle.path(forResource: "imu2", ofType: "bin"),
      let stream2 = InputStream(fileAtPath: path2)
    else {
      throw IMUParsingError.fileCouldNotBeOpened
    }
    let parser2 = try IMUParser(stream2)

    let parsedAction2 = try parser2.readAction()

    guard let samples2 = parsedAction2?.samples else {
      XCTFail("Parsing ended without samples")
      return
    }

    XCTAssertEqual(samples2.count, 2619)

  }

}
