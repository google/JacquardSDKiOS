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

final class CloudManagerTests: XCTestCase {

  private let timeout: TimeInterval = 5
  private var cancellables = [Cancellable]()
  private var cloudManagerImpl: CloudManagerImpl!

  private let date = "2020-12-11"
  private let version = "version"
  private let vID = "87-b4-30-b6"
  private let pID = "b7-07-97-2a"
  private let dfuStatus = "mandatory"
  private let downloadURL = "www.test.com"

  static let getDeviceFirmwareParams =
    [
      "pid": "b7-07-97-2a",
      "vid": "87-b4-30-b6",
      "version": "001000000",
      "obfuscated_component_id": "9168f403d9b35ff56e8017aa2df0fac7fa2dec9b",
      "country_code": Locale.current.regionCode ?? "",
      "platform": "ios",
      "sdk_version": JacquardSDKVersion.version.asDecimalEncodedString,
      "tag_version": "0000000",
    ] as [String: Any]

  static let config = SDKConfig(apiKey: "some_dummy_api_key")

  /// Helper enum which can be used  to construct valid / invalid url request using URLBuilderClass
  private enum APIRequest: String {
    case getDeviceFirmwareValidRequest
    case getDeviceFirmwareInvalidRequest

    var request: URLRequest {
      switch self {
      case .getDeviceFirmwareValidRequest:
        return URLRequestBuilder.deviceFirmwareRequest(
          params: CloudManagerTests.getDeviceFirmwareParams, config: config)

      case .getDeviceFirmwareInvalidRequest:
        var request = URLRequestBuilder(endPoint: .getDeviceFirmware, sdkConfig: config)
        request.headers = ["test": "test"]
        return request.build()
      }
    }
  }

  private let urlSession: URLSession = {
    let configuration = URLSessionConfiguration.default
    configuration.protocolClasses = [FakeURLProtocol.self]
    let urlSession = URLSession(configuration: configuration)
    return urlSession
  }()

  override func setUp() {
    super.setUp()
    cloudManagerImpl = CloudManagerImpl(
      sessionConfig: urlSession.configuration, sdkConfig: CloudManagerTests.config)

  }

  //MARK: - API success tests
  func testGetDeviceFirmwareAPISuccess() {

    let responseData = """
      {
          "date": "\(self.date)",
          "version": "\(self.version))",
          "vid": "\(self.vID)",
          "pid": "\(self.pID)",
          "dfuStatus": "\(self.dfuStatus)",
          "downloadUrl": "\(self.downloadURL)"
      }
      """.data(using: .utf8)

    FakeURLProtocol.requestHandler = { request in
      let response = HTTPURLResponse(
        url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
      return (response.statusCode, responseData, nil)
    }

    let exepectation = XCTestExpectation(description: "GetDeviceFirmware API call expectation.")
    cloudManagerImpl.getDeviceFirmware(params: CloudManagerTests.getDeviceFirmwareParams)
      .sink(
        receiveCompletion: { completion in
          switch completion {
          case .failure(let error):
            XCTFail("API Failure Error: \(error.localizedDescription)")
          case .finished:
            exepectation.fulfill()
          }
        },
        receiveValue: { response in
          XCTAssertNotNil(response)
          XCTAssertEqual(response.pid, self.pID)
          XCTAssertEqual(response.vid, self.vID)
          if response.dfuStatus == .none {
            XCTAssertNil(response.downloadURL)
          } else {
            XCTAssertNotNil(response.downloadURL)
            XCTAssertEqual(response.downloadURL, self.downloadURL)
          }
        }
      ).addTo(&cancellables)

    wait(for: [exepectation], timeout: timeout)
  }

  func testGetDeviceFirmwareAPIFailure() {

    FakeURLProtocol.requestHandler = { request in
      let response = HTTPURLResponse(
        url: request.url!, statusCode: 400, httpVersion: nil, headerFields: nil)!
      return (response.statusCode, nil, nil)
    }

    let exepectation = XCTestExpectation(description: "GetDeviceFirmware API call expectation.")
    cloudManagerImpl.getDeviceFirmware(params: CloudManagerTests.getDeviceFirmwareParams)
      .sink(
        receiveCompletion: { completion in
          switch completion {
          case .failure(let error):
            XCTAssertEqual(error, APIError.clientError)
            exepectation.fulfill()
          case .finished:
            exepectation.fulfill()
          }
        },
        receiveValue: { _ in
          XCTFail("Should not receive value api failure case")
        }
      ).addTo(&cancellables)

    wait(for: [exepectation], timeout: timeout)
  }

  //MARK: - API success tests

  func testAPIServerEnvOverride() {
    let origEnvVar = ProcessInfo.processInfo.environment["JACQUARD_BASE_URL_OVERRIDE"]

    let prodServer = APIServer.production

    if origEnvVar == nil {
      // Test that the default production property works with no environment variable set.
      XCTAssertEqual(prodServer.baseURL, URL(string: "https://jacquard.googleapis.com")!)
    }

    // Test the override works.
    let _ = "JACQUARD_BASE_URL_OVERRIDE".withCString { envKey in
      "https://atap.google.com".withCString { envValue in
        setenv(envKey, envValue, 1)
      }
    }
    XCTAssertEqual(prodServer.baseURL, URL(string: "https://atap.google.com")!)

    // Leave the env var as it was prior to this test.

    let _ = "JACQUARD_BASE_URL_OVERRIDE".withCString { envKey in
      unsetenv(envKey)
    }
  }

  /// Test connection with actual server.
  ///
  /// This test requires the following environment variables, otherwise it will be skipped:
  /// - `JACQUARD_BASE_URL_OVERRIDE` : Sets the server base URL.
  /// - `JACQUARD_API_KEY` : Sets the API Key.
  func testDownloadDeviceFirmwareSuccess() throws {

    guard let envURLString = ProcessInfo.processInfo.environment["JACQUARD_BASE_URL_OVERRIDE"],
      let envAPIKeyString = ProcessInfo.processInfo.environment["JACQUARD_API_KEY"]
    else {
      throw XCTSkip("Missing integration test environment variables")
    }

    guard let serverURL = URL(string: envURLString) else {
      XCTFail("ENV[JACQUARD_BASE_URL_OVERRIDE] is not a valid URL: \(envURLString)")
      return
    }

    // create separate cloud manager instance to get actual response from server.
    let server = APIServer(baseURL: serverURL)
    let config = SDKConfig(apiKey: envAPIKeyString, server: server)
    let cloudManagerImplLocal = CloudManagerImpl(sdkConfig: config)

    let exepectation = XCTestExpectation(description: "GetDeviceFirmware API call expectation.")
    cloudManagerImplLocal.getDeviceFirmware(params: CloudManagerTests.getDeviceFirmwareParams)
      .sink(
        receiveCompletion: { completion in
          switch completion {
          case .failure(let error):
            XCTFail("API Failure Error: \(error.localizedDescription)")
          case .finished:
            exepectation.fulfill()
          }
        },
        receiveValue: { response in
          XCTAssertNotNil(response.downloadURL)
          if let url = response.downloadURL {
            self.downloadFile(url: url)
          } else {
            print("NO UPDATE AVAILABLE")
          }
        }
      ).addTo(&cancellables)

    wait(for: [exepectation], timeout: timeout)
  }

  func downloadFile(url: String) {

    FakeURLProtocol.requestHandler = { request in
      let response = HTTPURLResponse(
        url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
      let fakeData = Data()
      return (response.statusCode, fakeData, nil)
    }

    let exepectation = XCTestExpectation(description: "Firmware file download expectation.")
    cloudManagerImpl.downloadFirmwareImage(url: URL(string: url)!)
      .sink(
        receiveCompletion: { completion in
          switch completion {
          case .failure(let error):
            XCTFail("API Failure Error: \(error.localizedDescription)")
          case .finished:
            exepectation.fulfill()
          }
        },
        receiveValue: { data in
          XCTAssertNotNil(data)
          exepectation.fulfill()
        }
      ).addTo(&cancellables)

    wait(for: [exepectation], timeout: timeout)
  }

  func testDownloadDeviceFirmwareFailure() {

    FakeURLProtocol.requestHandler = { request in
      let response = HTTPURLResponse(
        url: request.url!, statusCode: 400, httpVersion: nil, headerFields: nil)!
      return (response.statusCode, nil, APIError.downloadFailed)
    }

    let exepectation = XCTestExpectation(description: "Firmware file download expectation.")
    cloudManagerImpl.downloadFirmwareImage(url: URL(string: "SomeFakeUrl")!)
      .sink(
        receiveCompletion: { completion in
          switch completion {
          case .failure(let error):
            XCTAssertNotNil(error)
            XCTAssertEqual(error.localizedDescription, APIError.downloadFailed.localizedDescription)
            exepectation.fulfill()
          case .finished:
            XCTFail("Finished should not be called on failure.")
          }
        },
        receiveValue: { data in
          XCTFail("receiveValue should not be called on failure.")
        }
      ).addTo(&cancellables)

    wait(for: [exepectation], timeout: timeout)
  }

  //MARK: - API failure tests
  /// Common method to test all API error cases.
  func errorCaseScenarios<T: Decodable>(
    request: URLRequest, type: T.Type, errorType: APIError = .undefined
  ) {

    FakeURLProtocol.requestHandler = { request in
      switch errorType {
      case .clientError:
        let response = HTTPURLResponse(
          url: request.url!, statusCode: 400, httpVersion: nil, headerFields: nil)!
        return (response.statusCode, nil, nil)
      case .parsingFailed:
        let response = HTTPURLResponse(
          url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        return (response.statusCode, nil, nil)
      default: break
      }
      return (200, nil, nil)
    }

    let exepectation = XCTestExpectation(description: "GetDeviceFirmware error case expectation.")
    cloudManagerImpl.execute(request: request, type: T.self)
      .sink { (completion) in
        switch completion {
        case .failure(let error):
          XCTAssertNotNil(error)
          XCTAssertEqual(error.localizedDescription, errorType.localizedDescription)
          exepectation.fulfill()
        case .finished:
          exepectation.fulfill()
        }
      } receiveValue: { response in
        XCTFail("Should not receive value api failure case")
      }.addTo(&cancellables)
    wait(for: [exepectation], timeout: timeout)

  }

  /// Test to validate network error using invalid url.
  func testInvalidURLErrorCase() {
    struct DummyResponse: Codable {}
    errorCaseScenarios(
      request: APIRequest.getDeviceFirmwareInvalidRequest.request, type: DummyResponse.self,
      errorType: .clientError)
  }

  /// Test to validate parsing errors from valid url.
  func testParsingFailedErrorCase() {
    struct DummyResponse: Codable {
      let temp: String
    }
    errorCaseScenarios(
      request: APIRequest.getDeviceFirmwareValidRequest.request, type: DummyResponse.self,
      errorType: .parsingFailed)
  }
}
