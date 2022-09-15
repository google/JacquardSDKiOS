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

import Combine
import XCTest

@testable import JacquardSDK

class ShareReplayTests: XCTestCase {
  var observers = [Cancellable]()

  /// Test completed publishers are be passed through (but the replay functionality won't have any effect).
  func testCompleted() {
    let e1 = expectation(description: "One")
    Just(1)
      .shareReplayingLatestWhileNotComplete()
      .sink {
        XCTAssertEqual($0, 1)
        e1.fulfill()
      }.addTo(&observers)
    wait(for: [e1], timeout: 1)

    let e2 = expectation(description: "1, 2, 3")
    e2.expectedFulfillmentCount = 3
    var expectedValues = [1, 2, 3]
    Publishers.Sequence(sequence: [1, 2, 3])
      .shareReplayingLatestWhileNotComplete()
      .sink {
        XCTAssertEqual($0, expectedValues.removeFirst())
        e2.fulfill()
      }.addTo(&observers)
    wait(for: [e2], timeout: 1)
  }

  func testReplay() {
    let subject = PassthroughSubject<Int, Never>()
    let publisher = subject.shareReplayingLatestWhileNotComplete()

    let e1 = expectation(description: "1, 2, 3")
    e1.expectedFulfillmentCount = 3
    var expectedValues1 = [1, 2, 3]
    publisher
      .sink {
        XCTAssertEqual($0, expectedValues1.removeFirst())
        e1.fulfill()
      }.addTo(&observers)

    subject.send(1)

    let e2 = expectation(description: "(1), 2, 3")
    e2.expectedFulfillmentCount = 3
    var expectedValues2 = [1, 2, 3]
    publisher
      .sink {
        XCTAssertEqual($0, expectedValues2.removeFirst())
        e2.fulfill()
      }.addTo(&observers)

    subject.send(2)

    let e3 = expectation(description: "(2), 3")
    e3.expectedFulfillmentCount = 2
    var expectedValues3 = [2, 3]
    publisher
      .sink {
        XCTAssertEqual($0, expectedValues3.removeFirst())
        e3.fulfill()
      }.addTo(&observers)

    subject.send(3)

    let e4 = expectation(description: "(3)")
    publisher
      .sink {
        XCTAssertEqual($0, 3)
        e4.fulfill()
      }.addTo(&observers)

    let e5 = expectation(description: "(3)")
    publisher
      .sink {
        XCTAssertEqual($0, 3)
        e5.fulfill()
      }.addTo(&observers)

    wait(for: [e1, e2, e3, e4, e5], timeout: 1)
  }
}
