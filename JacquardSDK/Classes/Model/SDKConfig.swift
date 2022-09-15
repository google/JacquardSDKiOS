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

/// Defines the base URL of an API Server, and provides a default production value.
///
/// The actual base URL used can be overridden by an environment variable called `JACQUARD_BASE_URL_OVERRIDE`,
/// useful eg. for CI servers running hermetic integration tests or custom Xcode testing Schemes.
public struct APIServer {
  private var defaultBaseURL: URL
  var baseURL: URL {
    if let envURLString = ProcessInfo.processInfo.environment["JACQUARD_BASE_URL_OVERRIDE"] {
      print("Overriding baseURL with JACQUARD_BASE_URL_OVERRIDE=\(envURLString)")
      guard let url = URL(string: envURLString) else {
        fatalError("JACQUARD_BASE_URL_OVERRIDE is not a valid URL.")
      }
      return url
    } else {
      return defaultBaseURL
    }
  }

  /// Creates an `APIServer` instance for a custom URL.
  public init(baseURL: URL) {
    self.defaultBaseURL = baseURL
  }

  /// Creates an `APIServer` instance for the production instance.
  public static var production: APIServer {
    return APIServer(baseURL: URL(string: "https://jacquard.googleapis.com")!)
  }
}

/// Configuration required for using Cloud APIs (eg. firmware updating).
public final class SDKConfig {
  let clientID: String
  let apiKey: String
  let server: APIServer

  /// Creates an `SDKConfig` instance to specify cloud API connection details.
  ///
  /// See https://google.github.io/JacquardSDKiOS/cloud-api-terms.html for information about
  /// obtaining an API Key.
  ///
  /// - Parameters:
  ///   - apiKey: API Key string used to authenticate cloud access.
  ///   - server: `APIServer` instance specifying server instance. Defaults to `.production`.
  public init(apiKey: String, server: APIServer = .production) {
    let bundleID = Bundle.main.bundleIdentifier
    self.clientID = bundleID ?? ""
    self.apiKey = apiKey
    self.server = server
  }
}
