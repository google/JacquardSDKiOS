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

final class AppDataStorage {
  var defaults: UserDefaults? = {
    guard let defaults = UserDefaults(suiteName: "AppDataStorage") else {
      assertionFailure("Unable to create UserDefaults for suiteName: AppDataStorage")
      return nil
    }
    return defaults
  }()

  func store<V: Codable>(_ value: V, for key: String) {
    defaults?.set(encodable: value, forKey: key)
  }

  func retrieve<T: Codable>(for key: String) -> T? {
    return defaults?.value(T.self, forKey: key)
  }

  func remove(key: String) {
    defaults?.removeObject(forKey: key)
  }
}

extension UserDefaults {

  private var primitiveTypes: [Encodable.Type] {
    return [
      UInt.self, UInt8.self, UInt16.self, UInt32.self, UInt64.self, Int.self, Int8.self, Int16.self,
      Int32.self, Int64.self, Float.self, Double.self, String.self, Bool.self, Date.self,
    ]
  }

  /// Allows the storing of type T that conforms to the Encodable protocol.
  func set<T: Encodable>(encodable: T, forKey key: String) {
    if primitiveTypes.first(where: { return $0 is T.Type }) != nil {
      set(encodable, forKey: key)
    } else if let data = try? PropertyListEncoder().encode(encodable) {
      set(data, forKey: key)
    }
  }

  /// Allows for retrieval of type T that conforms to the Decodable protocol.
  func value<T: Decodable>(_ type: T.Type, forKey key: String) -> T? {
    if let value = object(forKey: key) as? T {
      return value
    } else if let data = object(forKey: key) as? Data,
      let value = try? PropertyListDecoder().decode(type, from: data)
    {
      return value
    }
    return nil
  }
}
