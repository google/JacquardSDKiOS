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

class GestureNotificationSubscriptionTests: XCTestCase {

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

  // MARK: General tests

  func testCreateSubscriptionRequest() {
    // Creating a `GestureNotificationSubscription` instance should require no arguments.
    XCTAssertNotNil(GestureNotificationSubscription())
  }

  // MARK: - Notification Proto payload tests

  /// Proto payload is Any type, so we need to ensure a bad payload is safely ignored.
  func testBadNotificationProtoContents() {
    let assertionExpectation = expectation(description: "Raised exception")
    jqLogger = CatchLogger(expectation: assertionExpectation)
    let notification = GestureNotificationSubscription()
    let badProto = Google_Jacquard_Protocol_Color()
    XCTAssertNil(notification.extract(from: badProto))
    wait(for: [assertionExpectation], timeout: 1.0)
  }

  /// Even once we have a notification proto, it may be missing gesture information.
  func testEmptyNotification() {
    let notification = GestureNotificationSubscription()
    let emptyProto = Google_Jacquard_Protocol_Notification()
    XCTAssertNil(notification.extract(from: emptyProto))
  }

  /// Even once we have a notification proto with gesture information, it may be missing required
  /// fields.
  func testNotificationProtoMissingGestureData() {
    let notification = GestureNotificationSubscription()
    let emptyProto = Google_Jacquard_Protocol_Notification.with {
      let data = Google_Jacquard_Protocol_DataChannelNotification()
      $0.Google_Jacquard_Protocol_DataChannelNotification_data = data
    }

    let extracted = notification.extract(from: emptyProto)
    XCTAssertNil(extracted)
  }

  func testGoodNotificationProtoContents(expectedGestureID: Int) {

    let notification = GestureNotificationSubscription()

    let goodProto = Google_Jacquard_Protocol_Notification.with {
      let data = Google_Jacquard_Protocol_DataChannelNotification.with {
        let inferenceData = Google_Jacquard_Protocol_InferenceData.with {
          $0.event = UInt32(expectedGestureID)
        }
        $0.inferenceData = inferenceData
      }
      $0.Google_Jacquard_Protocol_DataChannelNotification_data = data
    }

    guard let result = notification.extract(from: goodProto) else {
      XCTFail("extract(goodProto) returned nil")
      return
    }

    let inferenceData = Google_Jacquard_Protocol_InferenceData.with {
      $0.event = UInt32(expectedGestureID)
    }

    let gesture = Gesture(inferenceData)
    XCTAssertEqual(result, gesture)
    XCTAssertEqual(result.name, gesture?.name)
  }

  func testAllGestureNotifications() {
    for gesture in Gesture.allCases {
      testGoodNotificationProtoContents(expectedGestureID: gesture.rawValue)
    }
  }
}
