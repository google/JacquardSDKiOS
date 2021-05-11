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

final class ComponentInternalTests: XCTestCase {

  struct CatchLogger: Logger {
    func log(level: LogLevel, file: String, line: Int, function: String, message: () -> String) {
      let _ = message()
      if level == .assertion {
        expectation.fulfill()
      }
    }

    var expectation: XCTestExpectation
  }

  override func setUp() {
    super.setUp()

    let logger = PrintLogger(
      logLevels: [.debug, .info, .warning, .error, .assertion, .preconditionFailure],
      includeSourceDetails: true
    )
    setGlobalJacquardSDKLogger(logger)
  }

  override func tearDown() {
    // Other tests may run in the same process. Ensure that any fake logger fulfillment doesn't
    // cause any assertions later.
    JacquardSDK.setGlobalJacquardSDKLogger(JacquardSDK.createDefaultLogger())

    super.tearDown()
  }

  func testVerifyComponentFromGoodProto() {
    let notification = AttachedNotificationSubscription()
    let vendorID = "fb-57-a1-12"
    let productID = "5c-d8-78-b0"
    let gearData = FakeComponentHelper.gearData(vendorID: vendorID, productID: productID)

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

  func testVerifyComponentFromBadProto() {
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
  }

  func testVerifyDefaultComponentData() {
    let tagComponent = ComponentImplementation.tagComponent
    XCTAssertEqual(tagComponent.componentID, 0)
    XCTAssertEqual(tagComponent.vendor.id, "google")
    XCTAssertEqual(tagComponent.vendor.name, "google")
    XCTAssertEqual(tagComponent.product.id, "ujt")
    XCTAssertEqual(tagComponent.product.name, "ujt")
    XCTAssertEqual(tagComponent.product.capabilities.count, 1)
    XCTAssert(tagComponent.product.capabilities[0] == .led)
  }

  func testVerifyValidHex() {
    XCTAssertEqual(ComponentImplementation.convertToDecimal("fb-57-a1-12"), 4_216_824_082)
  }

  func testVerifyInvaidHex() {
    let invalidHexExpectation = expectation(description: "invalidHexExpectation")
    jqLogger = CatchLogger(expectation: invalidHexExpectation)

    XCTAssertEqual(ComponentImplementation.convertToDecimal("fb57a112"), 0)

    wait(for: [invalidHexExpectation], timeout: 1.0)
  }

  func testVerifyValidDecimal() {
    XCTAssertEqual(ComponentImplementation.convertToHex(4_216_824_082), "fb-57-a1-12")
  }
}
