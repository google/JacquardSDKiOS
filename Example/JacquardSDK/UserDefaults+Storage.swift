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

extension UserDefaults {

  private enum Constants {
    static let keyAutoUpdateSwitchValue = "autoUpdateSwitchValue"
    static let keyForceCheckUpdateSwitchValue = "forceCheckUpdateSwitchValue"
    static let keyLoadableModuleUpdateSwitchValue = "loadableModuleUpdateSwitchValue"
  }

  private var primitiveTypes: [Encodable.Type] {
    return [
      UInt.self, UInt8.self, UInt16.self, UInt32.self, UInt64.self, Int.self, Int8.self, Int16.self,
      Int32.self, Int64.self, Float.self, Double.self, String.self, Bool.self, Date.self,
    ]
  }

  /// Allows the storing of type T that conforms to the Encodable protocol.
  private func set<T: Encodable>(encodable: T, forKey key: String) {
    if primitiveTypes.first(where: { return $0 is T.Type }) != nil {
      set(encodable, forKey: key)
    } else if let data = try? PropertyListEncoder().encode(encodable) {
      set(data, forKey: key)
    }
  }

  /// Allows for retrieval of type T that conforms to the Decodable protocol.
  private func value<T: Decodable>(_ type: T.Type, forKey key: String) -> T? {
    if let value = object(forKey: key) as? T {
      return value
    } else if let data = object(forKey: key) as? Data,
      let value = try? PropertyListDecoder().decode(type, from: data)
    {
      return value
    }
    return nil
  }

  @objc var autoUpdateSwitch: Bool {
    get {
      return value(Bool.self, forKey: Constants.keyAutoUpdateSwitchValue) ?? false
    }
    set {
      set(encodable: newValue, forKey: Constants.keyAutoUpdateSwitchValue)
    }
  }

  @objc var forceCheckUpdateSwitch: Bool {
    get {
      return value(Bool.self, forKey: Constants.keyForceCheckUpdateSwitchValue) ?? false
    }
    set {
      set(encodable: newValue, forKey: Constants.keyForceCheckUpdateSwitchValue)
    }
  }

  @objc var loadableModuleUpdateSwitch: Bool {
    get {
      return value(Bool.self, forKey: Constants.keyLoadableModuleUpdateSwitchValue) ?? false
    }
    set {
      set(encodable: newValue, forKey: Constants.keyLoadableModuleUpdateSwitchValue)
    }
  }
}
