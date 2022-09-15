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

class CacheManagerTests: XCTestCase {

  private var cacheManager: CacheManager!
  private var cacheKey = "TestCacheKey"
  override func setUp() {
    super.setUp()
    cacheManager = CacheManagerImpl()
  }

  private func retrieveFirmwareInfo(for key: String) -> DFUUpdateInfo? {
    return cacheManager.retrieve(for: key)
  }

  private let testDFUInfo = DFUUpdateInfo(
    date: "SomeDate",
    version: "SomeVersion",
    dfuStatus: .optional,
    vid: "SomeVendor",
    pid: "SomeProduct",
    downloadURL: "http://someurl.com",
    image: Data(base64Encoded: "SomeData")
  )

  func testCachingAndRetrieveDFUInfo() {
    cacheManager.cache(testDFUInfo, for: cacheKey)
    let savedDFUInfo = retrieveFirmwareInfo(for: cacheKey)
    XCTAssertNotNil(savedDFUInfo, "Cached info cannot be nil")
    XCTAssertEqual(testDFUInfo.date, savedDFUInfo?.date)
    XCTAssertEqual(testDFUInfo.vid, savedDFUInfo?.vid)
  }

  func testRemoveCachingDFUInfo() {
    cacheManager.cache(testDFUInfo, for: cacheKey)
    cacheManager.remove(key: cacheKey)
    let savedDFUInfo = retrieveFirmwareInfo(for: cacheKey)
    XCTAssertNil(savedDFUInfo, "Cached info should be nil")
  }

  // MARK: UserDefaults extension tests

  func testCacheBoolValues() {
    // If testcase passes, it means Bool was successfully written
    // and retrieved from defaults still, maintaing the type
    let key = "BoolKey"
    var boolValue = true
    cacheManager.cache(boolValue, for: key)
    let boolRetrieve = cacheManager.defaults?.value(Bool.self, forKey: key)
    XCTAssertNotNil(boolRetrieve)
    XCTAssertEqual(boolValue, boolRetrieve)

    // As Bool can also be casted to Int
    // Bool true = Int 1
    var intRetrieve = cacheManager.defaults?.integer(forKey: key)
    XCTAssertEqual(intRetrieve, 1)

    // Bool false = Int 0
    boolValue = false
    cacheManager.cache(boolValue, for: key)
    intRetrieve = cacheManager.defaults?.integer(forKey: key)
    XCTAssertEqual(intRetrieve, 0)
  }

  func testCacheIntValues() {
    // If testcase passes, it means Int was successfully written
    // and retrieved from defaults, still maintaing the type
    let key = "IntKey"
    var intValue = 10
    cacheManager.cache(intValue, for: key)
    let intRetrieve = cacheManager.defaults?.value(Int.self, forKey: key)
    XCTAssertNotNil(intRetrieve)
    XCTAssertEqual(intValue, intRetrieve)

    // As Int can also be casted to Bool
    // Int > 0 = true
    var boolRetrieve = cacheManager.defaults?.bool(forKey: key)
    XCTAssertEqual(boolRetrieve, true)

    // Int == 0 = false
    intValue = 0
    cacheManager.cache(intValue, for: key)
    boolRetrieve = cacheManager.defaults?.bool(forKey: key)
    XCTAssertEqual(boolRetrieve, false)
  }

  func testCacheStringValues() {
    let key = "StringKey"
    let stringValue = "Jacquard SDK Tests"
    cacheManager.cache(stringValue, for: key)
    var stringRetrieve = retrieveString(key: key)
    XCTAssertNotNil(stringRetrieve)
    XCTAssertEqual(stringValue, stringRetrieve)

    // Test removing a value
    cacheManager.remove(key: key)
    stringRetrieve = cacheManager.defaults?.string(forKey: key)
    XCTAssertNil(stringRetrieve, "Value should not be available")
  }

  func retrieveString(key: String) -> String? {
    return cacheManager.retrieve(for: key)
  }

  func testImageData() {
    let image = Data((0..<1000).map { UInt8($0 % 255) })
    cacheManager.cacheImage(image, for: "ImageData")

    let retrieveImage = cacheManager.retrieveImage(for: "ImageData")
    XCTAssertNotNil(image)
    XCTAssertNotNil(retrieveImage)
    XCTAssertEqual(image, retrieveImage)
  }
}
