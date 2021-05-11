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

import Combine

struct ComponentImplementation: Component {
  var componentID: ComponentID
  var vendor: GearMetadata.GearData.Vendor
  var product: GearMetadata.GearData.Product
  var isAttached: Bool
}

extension ComponentImplementation {

  init?(_ proto: Google_Jacquard_Protocol_AttachedNotification) {
    guard
      proto.hasAttachState && proto.attachState && proto.hasVendorID && proto.hasProductID
        && proto.hasComponentID
    else {
      return nil
    }

    let vendorID = ComponentImplementation.convertToHex(proto.vendorID)
    let productID = ComponentImplementation.convertToHex(proto.productID)

    self.componentID = proto.componentID
    let gearData = GearCapabilities.gearData(vendorID: vendorID, productID: productID)
    self.vendor = gearData.vendor
    self.product = gearData.product
    self.isAttached = proto.attachState
  }

  // Creates the `tagComponent` from known constants.
  static var tagComponent: ComponentImplementation {

    let product = GearMetadata.GearData.Product.with {
      $0.id = DeviceConstants.product
      $0.name = DeviceConstants.product
      $0.image = "JQTag"
      $0.capabilities = [.led]
    }

    let vendor = GearMetadata.GearData.Vendor.with {
      $0.id = DeviceConstants.vendor
      $0.name = DeviceConstants.vendor
      $0.products = [product]
    }

    return self.init(
      componentID: DeviceConstants.FixedComponent.tag.rawValue,
      vendor: vendor,
      product: product,
      isAttached: true)
  }

  /// Converts a 32bit Vendor/Product id into the format XX-XX-XX-XX
  ///
  /// - Parameter: unsignedInteger the value to be stringyfied
  public static func convertToHex(_ unsignedInteger: UInt32) -> String {
    let hex = String(format: "%08x", unsignedInteger)
    return String(
      stride(from: 0, to: Array(hex).count, by: 2).map {
        Array(Array(hex)[$0..<min($0 + 2, Array(hex).count)])
      }.joined(separator: "-"))
  }

  /// Converts Vendor/Product id with format XX-XX-XX-XX into unsignedInteger
  public static func convertToDecimal(_ string: String) -> UInt32 {
    guard
      string.range(
        of: "^[0-9a-fA-F]{2}-[0-9a-fA-F]{2}-[0-9a-fA-F]{2}-[0-9a-fA-F]{2}$",
        options: .regularExpression,
        range: nil,
        locale: nil
      ) != nil
    else {
      jqLogger.assert("Invalid hexadecimal string: \(string)")
      return 0
    }

    guard let value = UInt32(string.replacingOccurrences(of: "-", with: ""), radix: 16) else {
      assertionFailure("Invalid hexadecimal string: \(string)")
      return 0
    }
    return value
  }
}
