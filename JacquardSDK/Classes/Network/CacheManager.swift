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

/// Manages the caching of Firmware info and image data.
protocol CacheManager {

  var defaults: UserDefaults? { get }

  func cache<V: Codable>(_ value: V, for key: String)

  func cacheImage(_ image: Data?, for key: String)

  func retrieve<T: Codable>(for key: String) -> T?

  func retrieveImage(for key: String) -> Data?

  func remove(key: String)
}

final class CacheManagerImpl: CacheManager {

  enum Constants {
    static let preferenceName = "JacquardSDK"
    // Cache time interval is 12 hours.
    static let cacheTimeInterval: TimeInterval = 12 * 60 * 60
  }

  var defaults: UserDefaults? = {
    guard let defaults = UserDefaults(suiteName: Constants.preferenceName) else {
      jqLogger.assert("Unable to create UserDefaults for suiteName: \(Constants.preferenceName)")
      return nil
    }
    return defaults
  }()

  func cache<V: Codable>(_ value: V, for key: String) {
    defaults?.set(encodable: value, forKey: key)
  }

  func retrieve<T: Codable>(for key: String) -> T? {
    return defaults?.value(T.self, forKey: key)
  }

  func remove(key: String) {
    defaults?.removeObject(forKey: key)
  }

  func cacheImage(_ image: Data?, for key: String) {
    defaults?.setValue(image, forKey: key)
  }

  func retrieveImage(for key: String) -> Data? {
    defaults?.value(forKey: key) as? Data
  }
}
