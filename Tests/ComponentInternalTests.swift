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

import SwiftCheck
import XCTest

@testable import JacquardSDK

final class ComponentInternalTests: XCTestCase {

  /// SwiftCheck generator for arbitrary valid component hex strings.
  struct ArbitraryHexString: Arbitrary {
    let getHexString: String
    init(hexString: String) { self.getHexString = hexString }
    static var arbitrary: Gen<ArbitraryHexString> {

      let numericGen = Gen<Character>.fromElements(in: "0"..."9")
      let hexLowerCharGen = Gen<Character>.fromElements(in: "a"..."f")
      let hexUpperCharGen = Gen<Character>.fromElements(in: "A"..."F")

      // Should perhaps alter the frequency of selection.
      let hexByteGen = Gen<Character>
        .one(of: [
          hexLowerCharGen,
          hexUpperCharGen,
          numericGen,
        ]).proliferateNonEmpty
        .suchThat { $0.count == 2 }
        .map { String($0) }

      let hexStringGen = sequence(Array(repeating: hexByteGen, count: 4))
        .map {
          $0.joined(separator: "-")
        }
      return hexStringGen.map(ArbitraryHexString.init)
    }
  }

  struct CatchLogger: Logger {
    func log(
      level: LogLevel, file: StaticString, line: UInt, function: String, message: () -> String
    ) {
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
    let tagComponent = FakeConnectedTag(transport: FakeTransport()).tagComponent
    XCTAssertEqual(tagComponent.componentID, 0)
    XCTAssertEqual(tagComponent.vendor.id, TagConstants.vendor)
    XCTAssertEqual(tagComponent.vendor.name, TagConstants.vendor)
    XCTAssertEqual(tagComponent.product.id, TagConstants.product)
    XCTAssertEqual(tagComponent.product.name, TagConstants.product)
    XCTAssertEqual(tagComponent.product.capabilities.count, 1)
    XCTAssert(tagComponent.product.capabilities[0] == .led)
  }

  func testVerifyValidHex() {
    XCTAssertEqual(ComponentImplementation.convertToDecimal("fb-57-a1-12"), 4_216_824_082)
    XCTAssertEqual(ComponentImplementation.convertToDecimal("09-2f-41-ab"), 154_091_947)
  }

  func testVerifyInvalidHex() {
    let invalidHexExpectation = expectation(description: "invalidHexExpectation")
    jqLogger = CatchLogger(expectation: invalidHexExpectation)

    XCTAssertEqual(ComponentImplementation.convertToDecimal("fb57a112"), 0)

    wait(for: [invalidHexExpectation], timeout: 1.0)
  }

  func testVerifyValidDecimal() {
    XCTAssertEqual(ComponentImplementation.convertToHex(4_216_824_082), "fb-57-a1-12")
    // Ensure leading zero maintained.
    XCTAssertEqual(ComponentImplementation.convertToHex(154_091_947), "09-2f-41-ab")
  }

  func testSymmetric() {
    property("convertToDecimal(convertToHex) should return the original number")
      <- forAll { (num: UInt32) in
        ComponentImplementation.convertToDecimal(ComponentImplementation.convertToHex(num)) == num
      }

    property(
      "convertToHex(convertToDecimal) should return the original string")
      <- forAll { (str: ArbitraryHexString) in
        ComponentImplementation.convertToHex(
          ComponentImplementation.convertToDecimal(str.getHexString))
          == str.getHexString.lowercased()
      }
  }

  func testConvertToHexOutputPattern() {
    property("convertToHex outputs four hyphen-separated hex bytes")
      <- forAll { (num: UInt32) in
        let hex = ComponentImplementation.convertToHex(num)
        return hex.range(
          of: "^[0-9a-f]{2}-[0-9a-f]{2}-[0-9a-f]{2}-[0-9a-f]{2}$", options: .regularExpression)
          != nil
      }
  }

  func testConvertToDecimalForAllValidInputs() {
    property("convertToDecimal succeeds for all valid inputs")
      <- forAll { (str: ArbitraryHexString) in
        let _ = ComponentImplementation.convertToDecimal(str.getHexString)
        // convertToDecimal will assert on failure, so just return true.
        return true
      }
  }
}
