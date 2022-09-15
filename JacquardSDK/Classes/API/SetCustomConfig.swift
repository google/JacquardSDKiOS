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

/// Command to set the custom config.
///
/// - SeeAlso: `Commands`
public struct SetCustomConfigCommand: CommandRequest {

  /// Custom config element to be set on the component.
  let config: DeviceConfigElement

  /// Initialize a command request.
  ///
  /// - Parameter config: The config element to be set on the component.
  public init(config: DeviceConfigElement) {
    self.config = config
  }

}

/// Represents custom config element to be set on the component.
public struct DeviceConfigElement {
  /// Vendor ID of the component for which the config has to be set.
  /// If not specified, will be defaulted to that of tag.
  let vendorID: String

  /// Product ID of the component for which the config has to be set.
  /// If not specified, will be defaulted to that of tag.
  let productID: String

  /// Key of the custom config to be set.
  let key: String

  /// Custom config value to be set.
  let value: ConfigValue

  /// Initialize the custom config element.
  ///
  /// - Parameters:
  ///   - vendorID: The vendor ID of the component for which config to be set.
  ///   - productID: The product ID of the component for which config to be set.
  ///   - key: The key of the config to be set.
  ///   - value: The value of the config to be set.
  public init(
    vendorID: String = TagConstants.vendor,
    productID: String = TagConstants.product,
    key: String,
    value: ConfigValue
  ) {
    self.vendorID = vendorID
    self.productID = productID
    self.key = key
    self.value = value
  }
}

/// Represents custom config value type and its associated value.
public enum ConfigValue {
  /// :nodoc:
  case bool(Bool)

  /// :nodoc:
  case uint32(UInt32)

  /// :nodoc:
  case uint64(UInt64)

  /// :nodoc:
  case int32(Int32)

  /// :nodoc:
  case int64(Int64)

  /// :nodoc:
  case float(Float)

  /// :nodoc:
  case double(Double)

  /// :nodoc:
  case string(String)
}
