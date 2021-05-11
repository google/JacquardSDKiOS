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

@testable import JacquardSDK

class FakeCacheManager: CacheManager {
  var defaults: UserDefaults? = UserDefaults.standard
  var valueMap = [String: Encodable]()

  func cache<V>(_ value: V, for key: String) where V: Decodable, V: Encodable {
    valueMap[key] = value
  }

  func retrieve<T>(for key: String) -> T? where T: Decodable, T: Encodable {
    return valueMap[key] as? T
  }

  func remove(key: String) {
    valueMap.removeValue(forKey: key)
  }

  func cacheImage(_ image: Data?, for key: String) {
    defaults?.setValue(image, forKey: key)
  }

  func retrieveImage(for key: String) -> Data? {
    defaults?.value(forKey: key) as? Data
  }
}
