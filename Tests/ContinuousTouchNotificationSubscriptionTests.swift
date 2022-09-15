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

class ContinuousTouchNotificationSubscriptionTests: XCTestCase {

  struct CatchLogger: Logger {
    func log(
      level: LogLevel, file: StaticString, line: UInt, function: String, message: () -> String
    ) {
      // Exercise the implicit closure.
      let _ = message()
      expectation.fulfill()
    }

    var expectation: XCTestExpectation
  }

  override class func tearDown() {
    super.tearDown()

    // Other tests may run in the same process. Ensure that any fake logger fulfillment doesn't
    // cause any assertions later.
    JacquardSDK.setGlobalJacquardSDKLogger(JacquardSDK.createDefaultLogger())
  }

  //MARK: General tests

  func testCreateCommandRequest() {
    // Creating an `ContinuousTouchNotificationSubscription` instance should require no arguments.
    let _ = ContinuousTouchNotificationSubscription()
  }

  //MARK: - Notification Proto payload tests

  /// Proto payload is Any type, so we need to ensure a bad payload is safely ignored.
  func testBadNotificationProtoContents() {
    let assertionExpectation = expectation(description: "Raised exception")
    jqLogger = CatchLogger(expectation: assertionExpectation)
    let notification = ContinuousTouchNotificationSubscription()
    let badProto = Google_Jacquard_Protocol_Color()
    XCTAssertNil(notification.extract(from: badProto) as Any?)
    wait(for: [assertionExpectation], timeout: 1)
  }

  /// Even once we have a response proto, it may be missing component information.
  func testEmptyNotification() {
    let notification = ContinuousTouchNotificationSubscription()
    let badProto = Google_Jacquard_Protocol_Notification()
    XCTAssertNil(notification.extract(from: badProto) as Any?)
  }

  /// Even once we have a notification proto with status information, it may be missing required fields.
  func testNotificationProtoMissingTouchData() {
    let notification = ContinuousTouchNotificationSubscription()
    let emptyProto = Google_Jacquard_Protocol_Notification.with {
      let data = Google_Jacquard_Protocol_DataChannelNotification()
      $0.Google_Jacquard_Protocol_DataChannelNotification_data = data
    }

    let extracted = notification.extract(from: emptyProto)
    XCTAssertNil(extracted)
  }

  func testGoodNotificationProtoContents() {
    let notification = ContinuousTouchNotificationSubscription()

    let goodProto = Google_Jacquard_Protocol_Notification.with {
      let data = Google_Jacquard_Protocol_DataChannelNotification.with {
        let touchData = Google_Jacquard_Protocol_TouchData.with {
          $0.sequence = 1
          $0.diffDataScaled = Data([2, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12])
        }
        $0.touchData = touchData
      }
      $0.Google_Jacquard_Protocol_DataChannelNotification_data = data
    }

    guard let result = notification.extract(from: goodProto) else {
      XCTFail("extract(goodProto) returned nil")
      return
    }

    let expected = TouchData(
      sequence: 1, proximity: 2, lines: (1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12))

    XCTAssertEqual(result, expected)
  }
}
