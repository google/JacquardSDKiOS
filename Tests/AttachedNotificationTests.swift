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

class AttachedNotificationTests: XCTestCase {

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
    // Creating an `AttachedNotificationSubscription` instance should require no arguments.
    let _ = AttachedNotificationSubscription()
  }

  //MARK: - Notification Proto payload tests

  /// Proto payload is Any type, so we need to ensure a bad payload is safely ignored.
  func testBadNotificationProtoContents() {
    let assertionExpectation = expectation(description: "Raised exception")
    jqLogger = CatchLogger(expectation: assertionExpectation)
    let notification = AttachedNotificationSubscription()
    let badProto = Google_Jacquard_Protocol_Color()
    XCTAssertNil(notification.extract(from: badProto) as Any?)
    wait(for: [assertionExpectation], timeout: 1)
  }

  /// Even once we have a response proto, it may be missing component information.
  func testEmptyNotification() {
    let notification = AttachedNotificationSubscription()
    let badProto = Google_Jacquard_Protocol_Notification()
    XCTAssertNil(notification.extract(from: badProto) as Any?)
  }

  /// Even once we have a notification proto with status information, it may be missing required fields.
  func testNotificationProtoMissingBatteryStatus() {
    let notification = AttachedNotificationSubscription()
    let emptyProto = Google_Jacquard_Protocol_Notification.with {
      let attached = Google_Jacquard_Protocol_AttachedNotification()
      $0.Google_Jacquard_Protocol_AttachedNotification_attached = attached
    }

    // Return type is Component?? which distinguishes between being an unmatched notification,
    // or a matched notification which failed to contain required fields.
    let extracted = notification.extract(from: emptyProto)
    XCTAssertNotNil(extracted as Any?)
    XCTAssertNil(extracted!)

    let componentIDOnlyProto = Google_Jacquard_Protocol_Notification.with {
      let attached = Google_Jacquard_Protocol_AttachedNotification.with {
        $0.componentID = 1
      }
      $0.Google_Jacquard_Protocol_AttachedNotification_attached = attached
    }
    XCTAssertNil(notification.extract(from: componentIDOnlyProto)!)

    let productOnlyProto = Google_Jacquard_Protocol_Notification.with {
      let attached = Google_Jacquard_Protocol_AttachedNotification.with {
        $0.productID = 1
      }
      $0.Google_Jacquard_Protocol_AttachedNotification_attached = attached
    }
    XCTAssertNil(notification.extract(from: productOnlyProto)!)
  }

  func testGoodNotificationProtoContents() {
    let notification = AttachedNotificationSubscription()
    let vendorID = "fb-57-a1-12"
    let productID = "5c-d8-78-b0"
    let gearData = FakeComponentHelper.gearData(
      vendorID: vendorID, productID: productID)

    let goodProto = Google_Jacquard_Protocol_Notification.with {
      let attached = Google_Jacquard_Protocol_AttachedNotification.with {
        $0.attachState = true
        $0.vendorID = ComponentImplementation.convertToDecimal(vendorID)
        $0.productID = ComponentImplementation.convertToDecimal(productID)
        $0.componentID = 4
      }
      $0.Google_Jacquard_Protocol_AttachedNotification_attached = attached
    }

    // Return type is Component?? which distinguishes between being an unmatched notification,
    // or a matched notification which failed to contain required fields.
    guard let result = notification.extract(from: goodProto), let finalResult = result else {
      XCTFail("extract(goodProto) returned nil")
      return
    }

    XCTAssertTrue(finalResult.isAttached)
    XCTAssertEqual(finalResult.vendor, gearData.vendor)
    XCTAssertEqual(finalResult.product, gearData.product)
    XCTAssertEqual(finalResult.componentID, 4)
  }
}
