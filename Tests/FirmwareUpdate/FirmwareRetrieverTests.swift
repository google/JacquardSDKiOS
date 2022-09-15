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

class FirmwareRetrieverTests: XCTestCase {

  private let dfuKey = "dfuInfo_11-78-30-c8_28-3b-e7-a0".md5Hash()
  private let imageKey = "imageData_11-78-30-c8_28-3b-e7-a0".md5Hash()
  private let dfuInfoLastFetchedTimeKey = "dfuInfoLastFetchedTime_11-78-30-c8_28-3b-e7-a0".md5Hash()
  private let testImageData = "SomeCachedData".data(using: .utf8)
  private let version = Version(major: 1, minor: 72, micro: 0)
  private let timeout: TimeInterval = 5
  private var firmwareUpdateRetriever: FirmwareUpdateRetrieverImplementation!
  private let cloudManager = FakeCloudManager()
  private let cacheManager = FakeCacheManager()
  private var observers = [Cancellable]()

  private let testRemoteDFUInfo = DFUUpdateInfo(
    date: "SomeRemoteDate",
    version: "SomeRemoteVersion",
    dfuStatus: .optional,
    vid: "SomeRemoteVendor",
    pid: "SomeRemoteProduct",
    downloadURL: "http://someRemoteurl.com",
    image: "SomeRemoteData".data(using: .utf8)
  )

  private let testCachedDFUInfo = DFUUpdateInfo(
    date: "SomeCachedDate",
    version: "SomeCachedVersion",
    dfuStatus: .optional,
    vid: "SomeCachedVendor",
    pid: "SomeCachedProduct",
    downloadURL: "http://someCachedurl.com",
    image: "SomeCachedData".data(using: .utf8)
  )

  override func setUp() {
    super.setUp()
    firmwareUpdateRetriever =
      FirmwareUpdateRetrieverImplementation(cloudManager: cloudManager, cacheManager: cacheManager)
    cloudManager.dfuInfo = testRemoteDFUInfo
    cacheManager.valueMap[dfuKey] = testCachedDFUInfo
    cacheManager.valueMap[dfuInfoLastFetchedTimeKey] = Date()
    cacheManager.cacheImage(testImageData, for: imageKey)
  }

  func testCheckFirmwareUpdateFromRemote() {

    let valueExpectation = XCTestExpectation(description: "checkFirmwareUpdate value.")
    let completionExpectation = XCTestExpectation(description: "checkFirmwareUpdate completion.")
    let transport = FakeTransport()
    let tagComponent = FakeConnectedTag(transport: transport).tagComponent
    cloudManager.fileData = Data()

    let request = FirmwareUpdateRequest(
      component: tagComponent,
      tagVersion: version.asDecimalEncodedString,
      module: nil,
      componentVersion: tagComponent.version?.asDecimalEncodedString
    )

    firmwareUpdateRetriever.checkUpdate(
      request: request,
      forceCheck: true
    ).sink(
      receiveCompletion: { completion in
        switch completion {
        case .failure(_):
          XCTFail("Failure should not be recieved")
        case .finished:
          completionExpectation.fulfill()
        }
      },
      receiveValue: { dfuInfo in
        // As force check is true, dfuinfo should be equal to remote
        XCTAssertNotNil(dfuInfo, "DfuInfo should be available")
        XCTAssertEqual(dfuInfo.vid, self.testRemoteDFUInfo.vid)
        XCTAssertEqual(dfuInfo.pid, self.testRemoteDFUInfo.pid)
        XCTAssertEqual(dfuInfo.downloadURL, self.testRemoteDFUInfo.downloadURL)
        valueExpectation.fulfill()
      }
    ).addTo(&observers)

    wait(for: [valueExpectation, completionExpectation], timeout: timeout)

  }

  func testCheckFirmwareUpdateWhenCacheAvailable() {

    let valueExpectation = XCTestExpectation(description: "checkFirmwareUpdate value.")
    let completionExpectation = XCTestExpectation(description: "checkFirmwareUpdate completion.")
    cloudManager.fileData = Data()
    let transport = FakeTransport()
    let tagComponent = FakeConnectedTag(transport: transport).tagComponent
    let request = FirmwareUpdateRequest(
      component: tagComponent,
      tagVersion: version.asDecimalEncodedString,
      module: nil,
      componentVersion: tagComponent.version?.asDecimalEncodedString
    )

    firmwareUpdateRetriever.checkUpdate(
      request: request,
      forceCheck: false
    ).sink(
      receiveCompletion: { completion in
        switch completion {
        case .failure(_):
          XCTFail("Failure should not be recieved")
        case .finished:
          completionExpectation.fulfill()
        }
      },
      receiveValue: { dfuInfo in
        XCTAssertNotNil(dfuInfo, "DfuInfo should be available")
        XCTAssertEqual(dfuInfo.vid, self.testCachedDFUInfo.vid)
        XCTAssertEqual(dfuInfo.pid, self.testCachedDFUInfo.pid)
        XCTAssertEqual(dfuInfo.image, self.testImageData)
        valueExpectation.fulfill()
      }
    ).addTo(&observers)

    wait(for: [valueExpectation, completionExpectation], timeout: timeout)
  }

  func testCheckFirmwareUpdateFromRemoteFailure() {

    let failureExpectation = XCTestExpectation(description: "checkFirmwareUpdate completion.")

    let firmwareUpdateRetriever =
      FirmwareUpdateRetrieverImplementation(cloudManager: cloudManager, cacheManager: cacheManager)
    let transport = FakeTransport()
    let tagComponent = FakeConnectedTag(transport: transport).tagComponent

    cloudManager.error = APIError.downloadFailed
    let request = FirmwareUpdateRequest(
      component: tagComponent,
      tagVersion: version.asDecimalEncodedString,
      module: nil,
      componentVersion: tagComponent.version?.asDecimalEncodedString
    )

    firmwareUpdateRetriever.checkUpdate(
      request: request,
      forceCheck: true
    ).sink(
      receiveCompletion: { completion in
        switch completion {
        case .failure(let error):
          XCTAssertNotNil(error)
          XCTAssertEqual(error, APIError.downloadFailed)
          failureExpectation.fulfill()
        case .finished: break
        }
      },
      receiveValue: { dfuInfo in
        XCTFail("Value should not be recieved")
      }
    ).addTo(&observers)

    wait(for: [failureExpectation], timeout: timeout)
  }

  func testCheckFirmwareUpdateWhenCacheUnavailable() {

    let valueExpectation = XCTestExpectation(description: "checkFirmwareUpdate value.")
    let completionExpectation = XCTestExpectation(description: "checkFirmwareUpdate completion.")
    cacheManager.remove(key: dfuKey)
    cloudManager.fileData = Data()
    let firmwareUpdateRetriever =
      FirmwareUpdateRetrieverImplementation(cloudManager: cloudManager, cacheManager: cacheManager)
    let transport = FakeTransport()
    let tagComponent = FakeConnectedTag(transport: transport).tagComponent
    let request = FirmwareUpdateRequest(
      component: tagComponent,
      tagVersion: version.asDecimalEncodedString,
      module: nil,
      componentVersion: tagComponent.version?.asDecimalEncodedString
    )

    firmwareUpdateRetriever.checkUpdate(
      request: request,
      forceCheck: false
    ).sink(
      receiveCompletion: { completion in
        switch completion {
        case .failure(_):
          XCTFail("Failure should not be recieved")
        case .finished:
          completionExpectation.fulfill()
        }
      },
      receiveValue: { dfuInfo in
        // As cache is not available, dfuinfo should be equal to remote
        XCTAssertNotNil(dfuInfo, "DfuInfo should be available")
        XCTAssertEqual(dfuInfo.vid, self.testRemoteDFUInfo.vid)
        XCTAssertEqual(dfuInfo.pid, self.testRemoteDFUInfo.pid)
        XCTAssertEqual(dfuInfo.downloadURL, self.testRemoteDFUInfo.downloadURL)
        valueExpectation.fulfill()
      }
    ).addTo(&observers)

    wait(for: [valueExpectation, completionExpectation], timeout: timeout)
  }

  func testCheckFirmwareUpdateWhenInvalidURL() {

    let failureExpectation = XCTestExpectation(description: "checkFirmwareUpdate completion.")
    let tagComponent = FakeConnectedTag(transport: FakeTransport()).tagComponent
    cloudManager.dfuInfo = DFUUpdateInfo(
      date: "SomeRemoteDate",
      version: "SomeRemoteVersion",
      dfuStatus: .optional,
      vid: "SomeRemoteVendor",
      pid: "SomeRemoteProduct",
      downloadURL: "",
      image: Data(base64Encoded: "SomeRemoteData")
    )
    let request = FirmwareUpdateRequest(
      component: tagComponent,
      tagVersion: version.asDecimalEncodedString,
      module: nil,
      componentVersion: tagComponent.version?.asDecimalEncodedString
    )
    firmwareUpdateRetriever.checkUpdate(
      request: request,
      forceCheck: true
    ).sink(
      receiveCompletion: { completion in
        switch completion {
        case .failure(let error):
          XCTAssertNotNil(error)
          // Error type should be `invalidURL`.
          XCTAssertEqual(error, APIError.invalidURL)
          failureExpectation.fulfill()
        case .finished: break
        }
      },
      receiveValue: { dfuInfo in
        XCTFail("Value should not be recieved")
      }
    ).addTo(&observers)

    wait(for: [failureExpectation], timeout: timeout)
  }

}
