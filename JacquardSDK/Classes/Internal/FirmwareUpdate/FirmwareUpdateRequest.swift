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

struct FirmwareUpdateRequest {
  /// The currently attached Tag or Gear component.
  let component: Component
  /// The tagVersion of the component.
  let tagVersion: String
  /// The object that holds information of a loadable module .
  let module: Module?
  /// An optional version of component.
  let componentVersion: String?
  var vendorID: String? = nil
  var productID: String? = nil

  var requestedVendorID: String {
    if let module = module {
      return module.vendorID.hexString()
    } else if let vendorID = vendorID {
      return vendorID
    } else {
      return component.vendor.id
    }
  }

  var requestedProductID: String {
    if let module = module {
      return module.productID.hexString()
    } else if let productID = productID {
      return productID
    } else {
      return component.product.id
    }
  }

  var parameters: [String: String] {
    var params = [String: String]()
    if let module = module {
      params["mid"] = module.moduleID.hexString()
    }

    params["vid"] = requestedVendorID
    params["pid"] = requestedProductID
    params["tag_version"] = tagVersion
    params["country_code"] = Locale.current.regionCode ?? ""
    params["platform"] = "ios"
    params["sdk_version"] = JacquardSDKVersion.version.asDecimalEncodedString

    if let id = component.uuid?.sha1() {
      params["obfuscated_component_id"] = id
    }
    if let version = componentVersion {
      params["version"] = version
    }
    return params
  }
}
