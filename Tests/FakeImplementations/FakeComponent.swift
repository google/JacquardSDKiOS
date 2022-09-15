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

struct FakeGearComponent: Component {
  var componentID: ComponentID
  var vendor: GearMetadata.GearData.Vendor
  var product: GearMetadata.GearData.Product
  var isAttached: Bool
  var version: Version?
  var uuid: String?
}

struct FakeTagComponent: Component {
  var componentID: ComponentID
  var vendor: GearMetadata.GearData.Vendor
  var product: GearMetadata.GearData.Product
  var isAttached: Bool
  var version: Version?
  var uuid: String?
}

class FakeComponentHelper {

  private static func fetchGearMetadata() -> GearMetadata.GearData {
    let url = GearCapabilities.jsonURL!
    let data = try! Data(contentsOf: url)
    let gearData = try! GearMetadata.GearData(jsonUTF8Data: data)
    return gearData
  }

  static func gearData(vendorID: String, productID: String) -> (
    vendor: GearMetadata.GearData.Vendor, product: GearMetadata.GearData.Product
  ) {
    let gearMetadata = fetchGearMetadata()
    let vendorData = gearMetadata.vendors.filter({ $0.id == vendorID }).first!
    let productData = vendorData.products.filter({ $0.id == productID }).first!
    return (vendorData, productData)
  }

  static func capabilities(vendorID: String, productID: String) -> [GearMetadata.Capability] {
    let gearMetadata = fetchGearMetadata()
    let capabilityIDs = gearMetadata.vendors.filter({ $0.id == vendorID }).first!
      .products.filter({ $0.id == productID }).first!
      .capabilities
    return capabilityIDs
  }
}
