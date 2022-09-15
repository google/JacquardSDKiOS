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

/// Command to get the custom config.
///
/// - SeeAlso: `Commands`
public struct GetCustomConfigCommand: CommandRequest {

  /// Vendor ID of the component for which the config has to be retrieved.
  /// If not specified, will be defaulted to that of tag.
  let vendorID: String

  /// Product ID of the component for which the config has to be retrieved.
  /// If not specified, will be defaulted to that of tag.
  let productID: String

  /// Key of the config which is to be retrieved.
  let key: String

  /// Initialize a command request.
  ///
  ///
  /// - Parameters:
  ///   - vendorID: The vendor ID of the component for which config to be retrieved.
  ///   - productID: The product ID of the component for which config to be retrieved.
  ///   - key: The key for which config to be retrieved.
  public init(
    vendorID: String = TagConstants.vendor,
    productID: String = TagConstants.product,
    key: String
  ) {
    self.vendorID = vendorID
    self.productID = productID
    self.key = key
  }

}
