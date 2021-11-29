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

final class VarIntTests: XCTestCase {

  /// SwiftCheck generator for number >= 0
  ///
  /// Only 0 or positive integers are supported by Varint.
  struct ArbitraryPositive<A: Arbitrary & Comparable & SignedNumeric>: Arbitrary {
    public let getPositive: A

    public init(_ pos: A) {
      self.getPositive = pos
    }

    public static var arbitrary: Gen<ArbitraryPositive<A>> {
      return A.arbitrary.map { ArbitraryPositive.init(abs($0)) }
    }
  }

  struct CatchLogger: Logger {
    func log(
      level: LogLevel, file: StaticString, line: UInt, function: String, message: () -> String
    ) {
      let _ = message()
      if level == .preconditionFailure {
        expectation.fulfill()
      }
    }

    var expectation: XCTestExpectation
  }

  override func tearDown() {
    // Other tests may run in the same process. Ensure that any fake logger fulfillment doesn't
    // cause any assertions later.
    JacquardSDK.setGlobalJacquardSDKLogger(JacquardSDK.createDefaultLogger())

    super.tearDown()
  }

  func testSymmetric() {
    property("Varint decode(encode()) should return the original number")
      <- forAll { (num: ArbitraryPositive) in
        Varint.decode(data: Varint.encode(value: num.getPositive)).value == num.getPositive
      }
  }

  func testAllDataConsumed() {
    property("Varint decode should consume all bytes produced by encode")
      <- forAll { (num: ArbitraryPositive<Int>) in
        let encoded = Varint.encode(value: num.getPositive)
        let decoded = Varint.decode(data: encoded)
        return decoded.bytesConsumed == encoded.count
      }
  }

  func testVarIntEncode() {
    XCTAssertEqual(Varint.encode(value: 192), Data([192, 1]))
  }

  func testVarIntZeroEncode() {
    XCTAssertEqual(Varint.encode(value: 0), Data([0]))
  }

  func testVarIntNegativeNumberEncode() {
    let negativeNumberEncodeExpectation = expectation(description: "NegativeNumberEncode")
    jqLogger = CatchLogger(expectation: negativeNumberEncodeExpectation)
    XCTAssertEqual(Varint.encode(value: -1), Data())
    wait(for: [negativeNumberEncodeExpectation], timeout: 1.0)
  }

  func testVarIntMaxEncode() {
    // Int.max = 9223372036854775807
    XCTAssertEqual(
      Varint.encode(value: Int.max), Data([255, 255, 255, 255, 255, 255, 255, 255, 127])
    )
  }

  func testVarInt32MaxEncode() {
    // Int32.max = 2147483647
    XCTAssertEqual(
      Varint.encode(value: Int(Int32.max)), Data([255, 255, 255, 255, 7])
    )
  }

  func testVarIntDecode() {
    let decodedData = Varint.decode(data: Data([192, 1]))
    XCTAssertEqual(decodedData.bytesConsumed, 2)
    XCTAssertEqual(decodedData.value, 192)
  }

  func testVarIntSingleByteData() {
    let decodedData = Varint.decode(data: Data([1, 1]))
    XCTAssertEqual(decodedData.bytesConsumed, 1)
    XCTAssertEqual(decodedData.value, 1)
  }

  func testVarIntMultiByteData() {
    let decodedData = Varint.decode(data: Data([192, 128, 1]))
    XCTAssertEqual(decodedData.bytesConsumed, 3)
    XCTAssertEqual(decodedData.value, 16448)
  }

  func testVarInt32MaxByteData() {
    // Int32.max = 2147483647
    // decode supports Int 32 bit conversion only.
    let decodedData = Varint.decode(data: Data([255, 255, 255, 255, 7]))
    XCTAssertEqual(decodedData.bytesConsumed, 5)
    XCTAssertEqual(Int32(decodedData.value), Int32.max)
  }
}
