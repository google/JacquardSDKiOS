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

/// Helps to perform unit testing for URLSession requests.
public class FakeURLProtocol: URLProtocol {

  static var requestHandler: ((URLRequest) throws -> (Int, Data?, Error?))?

  override public class func canInit(with request: URLRequest) -> Bool {
    return true
  }

  override public class func canonicalRequest(for request: URLRequest) -> URLRequest {
    return request
  }

  override public func startLoading() {
    guard let handler = FakeURLProtocol.requestHandler else {
      fatalError("Handler is unavailable.")
    }

    do {
      let (statusCode, data, error) = try handler(request)
      guard let url = request.url else {
        fatalError("Request URL was unavailable.")
      }
      let response = HTTPURLResponse(
        url: url,
        statusCode: statusCode,
        httpVersion: nil,
        headerFields: nil
      )!

      client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)

      if let data = data {
        client?.urlProtocol(self, didLoad: data)
      }

      if let error = error {
        client?.urlProtocol(self, didFailWithError: error)
      } else {
        client?.urlProtocolDidFinishLoading(self)
      }
    } catch {
      client?.urlProtocol(self, didFailWithError: error)
    }
  }

  override public func stopLoading() {
    // Not required to handle at the moment.
    //   fatalError("Not required to handle at the moment.")
  }
}
