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

/// This can be used to describe the capabilities of a piece of Gear.
public typealias GearMetadata = Google_Jacquard_Protocol_Public_Sdk_GearMetadata

/// Type describing an attached piece of Gear.
///
/// This type can be used to introspect the capabilities of this piece of Gear. Note that the tag also exposes a `Component`
/// instance via `ConnectedTag.tagComponent` which can be used to introspect the capabilities built into the tag.
///
/// - SeeAlso: `Components and Gear`
public protocol Component {
  /// The identifier of the current Gear attachment.
  ///
  /// Note that this identifier is not unique, and will change every time a piece of Gear is re-attached.
  var componentID: ComponentID { get }
  /// The vendor who manufactured this piece of Gear.
  var vendor: GearMetadata.GearData.Vendor { get }
  /// The type of the Gear.
  var product: GearMetadata.GearData.Product { get }
  /// The capabilities of this piece of Gear.
  var capabilities: [GearMetadata.Capability] { get }
}

extension Component {
  /// The  Identify type of component either Tag or UJT
  var isTag: Bool {
    return self.componentID == DeviceConstants.FixedComponent.tag.rawValue
  }
}

extension Component {
  /// The capabilities of this piece of Gear.
  public var capabilities: [GearMetadata.Capability] {
    product.capabilities
  }
}

/// Identifier for a  connected`Component` instance.
public typealias ComponentID = UInt32
