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

/// Metadata describing the capabilities of a piece of Gear.
class GearCapabilities {

  /// Helper function to get vendor and product data for specified vendor and product id
  static func gearData(vendorID: String, productID: String) -> (
    vendor: GearMetadata.GearData.Vendor, product: GearMetadata.GearData.Product
  ) {
    let gearMetadata = fetchGearMetadata()
    guard let vendorData = gearMetadata.vendors.first(where: { $0.id == vendorID }),
      let productData = vendorData.products.first(where: { $0.id == productID })
    else {
      jqLogger.preconditionAssertFailure(
        "Unable to find gear data for given \(vendorID) and \(productID)"
      )
      return (GearMetadata.GearData.Vendor(), GearMetadata.GearData.Product())
    }
    return (vendorData, productData)
  }

  /// Retrieve vendors and associated products information from local .Json file
  private static func fetchGearMetadata() -> GearMetadata.GearData {
    guard let jsonURL = jsonURL else {
      preconditionFailure("GearMetadata json not available.")
    }
    do {
      let jsonData = try Data(contentsOf: jsonURL)
      return try GearMetadata.GearData(jsonUTF8Data: jsonData)
    } catch {
      preconditionFailure("Unable to fetch GearMetadata from Local JSON file error: \((error))")
    }
  }

  static var jsonURL: URL? {
    Bundle.sdk.url(
      forResource: "GearMetadata",
      withExtension: "json"
    )
  }
}
