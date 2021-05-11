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

import Foundation

/// The HTTP request method of the receiver.
enum HTTPMethod: String {
  case post = "POST"
  case put = "PUT"
  case get = "GET"
  case delete = "DELETE"
  case patch = "PATCH"
}

/// Constructs urlRequest based on parameters passed to it. It uses builder design pattern to build an url request
struct URLRequestBuilder {

  /// Describes API endpoints which can be used as an API path while constructing url request.
  enum APIEndPoint {
    case getDeviceFirmware

    var path: String {
      switch self {
      case .getDeviceFirmware: return "v1/device/firmware"
      }
    }
  }

  var endPoint: APIEndPoint
  var sdkConfig: SDKConfig
  var method: HTTPMethod = .get
  var headers: [String: Any]?
  var parameters: [String: Any]?

  init(endPoint: APIEndPoint, sdkConfig: SDKConfig) {
    self.endPoint = endPoint
    self.sdkConfig = sdkConfig
  }

  /// Constructs and returns url request based values set to URLRequestBuilder class.
  func build() -> URLRequest {
    var urlRequest = URLRequest(
      url: sdkConfig.server.baseURL.appendingPathComponent(endPoint.path))
    urlRequest.httpMethod = method.rawValue
    headers?.forEach {
      urlRequest.addValue($0.value as! String, forHTTPHeaderField: $0.key)
    }
    // Default headers
    urlRequest.addValue(sdkConfig.apiKey, forHTTPHeaderField: "X-Goog-Api-Key")
    urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")

    if let params = parameters, let url = urlRequest.url {
      var urlComponents = URLComponents(string: url.absoluteString)
      urlComponents?.queryItems =
        params.map { URLQueryItem(name: $0.key, value: $0.value as? String) }
      urlComponents?.queryItems?.append(URLQueryItem(name: "cid", value: sdkConfig.clientID))
      urlRequest.url = urlComponents?.url
    }
    return urlRequest
  }
}

extension URLRequestBuilder {
  // URL request for getDeviceFirmware API
  static func deviceFirmwareRequest(params: [String: Any], config: SDKConfig) -> URLRequest {

    var urlRequest = URLRequestBuilder(endPoint: .getDeviceFirmware, sdkConfig: config)
    urlRequest.parameters = params
    return urlRequest.build()
  }
}
