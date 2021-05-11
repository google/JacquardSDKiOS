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

class MiscExtensionsTests: XCTestCase {

  class FakeCancellable: Cancellable {
    func cancel() {}
  }

  class FakeError: Error {}

  /// Minimal test for convenience chaining `Cancellable.addTo(_ array:)` method.
  func testCancellableAddTo() {
    var observations = [Cancellable]()
    let c1 = FakeCancellable()
    c1.addTo(&observations)
    XCTAssertEqual(observations.count, 1)
    XCTAssert(observations.contains(where: { $0 as? FakeCancellable === c1 }))
    let c2 = FakeCancellable()
    c2.addTo(&observations)
    XCTAssertEqual(observations.count, 2)
    XCTAssert(observations.contains(where: { $0 as? FakeCancellable === c1 }))
    XCTAssert(observations.contains(where: { $0 as? FakeCancellable === c2 }))
  }

  /// Minimal test for convenience Combine operator that downgrades a `<,Never>` signal to `<,Error>`.
  func testMapNeverToError() {
    let e1 = expectation(description: "Signal fired")
    let e2 = expectation(description: "Signal completed successfully")
    let e3 = expectation(description: "Error did not fire")
    e3.isInverted = true

    let observation = Just(1)
      .mapNeverToError()
      .sink { completion in
        switch completion {
        case .finished: e2.fulfill()
        case .failure: e3.fulfill()
        }
      } receiveValue: { value in
        XCTAssertEqual(value, 1)
        e1.fulfill()
      }

    XCTAssertNotNil(observation)
    wait(for: [e1, e2, e3], timeout: 1)
  }

  /// Even though mapNeverToError() is documented only for use with <,Never> publishers,
  /// test that it is a no-op for publishers which do publish an error.
  func testMapNeverToErrorWithError() {
    let e2 = expectation(description: "Signal completed successfully")
    e2.isInverted = true
    let e3 = expectation(description: "Error fired")

    let fakeError = FakeError()

    let observation = Fail<Never, Error>(error: fakeError)
      .mapNeverToError()
      .sink { completion in
        switch completion {
        case .finished:
          e2.fulfill()
        case .failure(let error):
          XCTAssert(error as? FakeError === fakeError)
          e3.fulfill()
        }
      } receiveValue: { _ in
        // Can never be reached, due to `Never` type.
      }

    XCTAssertNotNil(observation)
    wait(for: [e2, e3], timeout: 1)
  }
}
