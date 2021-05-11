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
//
// DO NOT EDIT.
// swift-format-ignore-file
//
// Generated by the Swift generator plugin for the protocol buffer compiler.
// Source: jacquard.proto
//
// For information on using the generated types, please see the documentation:
//   https://github.com/apple/swift-protobuf/

import Foundation
import SwiftProtobuf

// If the compiler emits an error on this type, it is because this file
// was generated by a version of the `protoc` Swift plug-in that is
// incompatible with the version of SwiftProtobuf to which you are linking.
// Please ensure that you are building against the same version of the API
// that was used to generate this file.
fileprivate struct _GeneratedWithProtocGenSwiftVersion: SwiftProtobuf.ProtobufAPIVersionCheck {
  struct _2: SwiftProtobuf.ProtobufAPIVersion_2 {}
  typealias Version = _2
}

/// Gear Capabilities ENUMERATION
/// This can be used to describe the capabilities of a piece of Gear.
public struct Google_Jacquard_Protocol_Public_Sdk_GearMetadata {
  // SwiftProtobuf.Message conformance is added in an extension below. See the
  // `Message` and `Message+*Additions` files in the SwiftProtobuf library for
  // methods supported on all messages.

  public var unknownFields = SwiftProtobuf.UnknownStorage()

  /// Gear capabilitiy options.
  public enum Capability: SwiftProtobuf.Enum {
    public typealias RawValue = Int

    /// This gear can be used for `PlayLEDPatternCommand`.
    case led // = 0

    /// This gear supports gestures. i.e`TouchMode.gesture`
    case gesture // = 1

    /// This gear supports touch data stream. i.e `TouchMode.touchDataStream`
    case touchDataStream // = 2

    /// This gear can be used for `PlayHapticCommand`.
    case haptic // = 3

    /// Unknown capability.
    case UNRECOGNIZED(Int)

    public init() {
      self = .led
    }

    public init?(rawValue: Int) {
      switch rawValue {
      case 0: self = .led
      case 1: self = .gesture
      case 2: self = .touchDataStream
      case 3: self = .haptic
      default: self = .UNRECOGNIZED(rawValue)
      }
    }

    public var rawValue: Int {
      switch self {
      case .led: return 0
      case .gesture: return 1
      case .touchDataStream: return 2
      case .haptic: return 3
      case .UNRECOGNIZED(let i): return i
      }
    }

  }

  /// This can be used to get configuration data for all vendors and it's
  /// associated products.
  public struct GearData {
    // SwiftProtobuf.Message conformance is added in an extension below. See the
    // `Message` and `Message+*Additions` files in the SwiftProtobuf library for
    // methods supported on all messages.

    /// Vendors of gear.
    public var vendors: [Google_Jacquard_Protocol_Public_Sdk_GearMetadata.GearData.Vendor] = []

    /// :nodoc:
    public var unknownFields = SwiftProtobuf.UnknownStorage()

    /// Describes the properties of a connected product.
    public struct Product {
      // SwiftProtobuf.Message conformance is added in an extension below. See the
      // `Message` and `Message+*Additions` files in the SwiftProtobuf library for
      // methods supported on all messages.

      /// Product identifier.
      public var id: String = String()

      /// Product name.
      public var name: String = String()

      /// Product image.
      public var image: String = String()

      /// Product capabilities.
      public var capabilities: [Google_Jacquard_Protocol_Public_Sdk_GearMetadata.Capability] = []

      /// :nodoc:
      public var unknownFields = SwiftProtobuf.UnknownStorage()

      /// :nodoc:
      public init() {}
    }

    /// Describes the properties of a gear vendor.
    public struct Vendor {
      // SwiftProtobuf.Message conformance is added in an extension below. See the
      // `Message` and `Message+*Additions` files in the SwiftProtobuf library for
      // methods supported on all messages.

      /// Vendor identifier.
      public var id: String = String()

      /// Vendor name.
      public var name: String = String()

      /// Vendor owned products.
      public var products: [Google_Jacquard_Protocol_Public_Sdk_GearMetadata.GearData.Product] = []

      /// :nodoc:
      public var unknownFields = SwiftProtobuf.UnknownStorage()

      /// :nodoc:
      public init() {}
    }

    /// :nodoc:
    public init() {}
  }

  /// :nodoc:
  public init() {}
}

#if swift(>=4.2)

extension Google_Jacquard_Protocol_Public_Sdk_GearMetadata.Capability: CaseIterable {
  // The compiler won't synthesize support with the UNRECOGNIZED case.
  public static var allCases: [Google_Jacquard_Protocol_Public_Sdk_GearMetadata.Capability] = [
    .led,
    .gesture,
    .touchDataStream,
    .haptic,
  ]
}

#endif  // swift(>=4.2)

// MARK: - Code below here is support for the SwiftProtobuf runtime.

fileprivate let _protobuf_package = "google.jacquard.protocol.public.sdk"

extension Google_Jacquard_Protocol_Public_Sdk_GearMetadata: SwiftProtobuf.Message, SwiftProtobuf._MessageImplementationBase, SwiftProtobuf._ProtoNameProviding {
  public static let protoMessageName: String = _protobuf_package + ".GearMetadata"
  public static let _protobuf_nameMap = SwiftProtobuf._NameMap()

  public mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
    while let _ = try decoder.nextFieldNumber() {
    }
  }

  public func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
    try unknownFields.traverse(visitor: &visitor)
  }

  public static func ==(lhs: Google_Jacquard_Protocol_Public_Sdk_GearMetadata, rhs: Google_Jacquard_Protocol_Public_Sdk_GearMetadata) -> Bool {
    if lhs.unknownFields != rhs.unknownFields {return false}
    return true
  }
}

extension Google_Jacquard_Protocol_Public_Sdk_GearMetadata.Capability: SwiftProtobuf._ProtoNameProviding {
  public static let _protobuf_nameMap: SwiftProtobuf._NameMap = [
    0: .same(proto: "LED"),
    1: .same(proto: "GESTURE"),
    2: .same(proto: "TOUCH_DATA_STREAM"),
    3: .same(proto: "HAPTIC"),
  ]
}

extension Google_Jacquard_Protocol_Public_Sdk_GearMetadata.GearData: SwiftProtobuf.Message, SwiftProtobuf._MessageImplementationBase, SwiftProtobuf._ProtoNameProviding {
  public static let protoMessageName: String = Google_Jacquard_Protocol_Public_Sdk_GearMetadata.protoMessageName + ".GearData"
  public static let _protobuf_nameMap: SwiftProtobuf._NameMap = [
    1: .same(proto: "vendors"),
  ]

  public mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
    while let fieldNumber = try decoder.nextFieldNumber() {
      // The use of inline closures is to circumvent an issue where the compiler
      // allocates stack space for every case branch when no optimizations are
      // enabled. https://github.com/apple/swift-protobuf/issues/1034
      switch fieldNumber {
      case 1: try { try decoder.decodeRepeatedMessageField(value: &self.vendors) }()
      default: break
      }
    }
  }

  public func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
    if !self.vendors.isEmpty {
      try visitor.visitRepeatedMessageField(value: self.vendors, fieldNumber: 1)
    }
    try unknownFields.traverse(visitor: &visitor)
  }

  public static func ==(lhs: Google_Jacquard_Protocol_Public_Sdk_GearMetadata.GearData, rhs: Google_Jacquard_Protocol_Public_Sdk_GearMetadata.GearData) -> Bool {
    if lhs.vendors != rhs.vendors {return false}
    if lhs.unknownFields != rhs.unknownFields {return false}
    return true
  }
}

extension Google_Jacquard_Protocol_Public_Sdk_GearMetadata.GearData.Product: SwiftProtobuf.Message, SwiftProtobuf._MessageImplementationBase, SwiftProtobuf._ProtoNameProviding {
  public static let protoMessageName: String = Google_Jacquard_Protocol_Public_Sdk_GearMetadata.GearData.protoMessageName + ".Product"
  public static let _protobuf_nameMap: SwiftProtobuf._NameMap = [
    1: .same(proto: "id"),
    2: .same(proto: "name"),
    3: .same(proto: "image"),
    4: .same(proto: "capabilities"),
  ]

  public mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
    while let fieldNumber = try decoder.nextFieldNumber() {
      // The use of inline closures is to circumvent an issue where the compiler
      // allocates stack space for every case branch when no optimizations are
      // enabled. https://github.com/apple/swift-protobuf/issues/1034
      switch fieldNumber {
      case 1: try { try decoder.decodeSingularStringField(value: &self.id) }()
      case 2: try { try decoder.decodeSingularStringField(value: &self.name) }()
      case 3: try { try decoder.decodeSingularStringField(value: &self.image) }()
      case 4: try { try decoder.decodeRepeatedEnumField(value: &self.capabilities) }()
      default: break
      }
    }
  }

  public func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
    if !self.id.isEmpty {
      try visitor.visitSingularStringField(value: self.id, fieldNumber: 1)
    }
    if !self.name.isEmpty {
      try visitor.visitSingularStringField(value: self.name, fieldNumber: 2)
    }
    if !self.image.isEmpty {
      try visitor.visitSingularStringField(value: self.image, fieldNumber: 3)
    }
    if !self.capabilities.isEmpty {
      try visitor.visitPackedEnumField(value: self.capabilities, fieldNumber: 4)
    }
    try unknownFields.traverse(visitor: &visitor)
  }

  public static func ==(lhs: Google_Jacquard_Protocol_Public_Sdk_GearMetadata.GearData.Product, rhs: Google_Jacquard_Protocol_Public_Sdk_GearMetadata.GearData.Product) -> Bool {
    if lhs.id != rhs.id {return false}
    if lhs.name != rhs.name {return false}
    if lhs.image != rhs.image {return false}
    if lhs.capabilities != rhs.capabilities {return false}
    if lhs.unknownFields != rhs.unknownFields {return false}
    return true
  }
}

extension Google_Jacquard_Protocol_Public_Sdk_GearMetadata.GearData.Vendor: SwiftProtobuf.Message, SwiftProtobuf._MessageImplementationBase, SwiftProtobuf._ProtoNameProviding {
  public static let protoMessageName: String = Google_Jacquard_Protocol_Public_Sdk_GearMetadata.GearData.protoMessageName + ".Vendor"
  public static let _protobuf_nameMap: SwiftProtobuf._NameMap = [
    1: .same(proto: "id"),
    2: .same(proto: "name"),
    3: .same(proto: "products"),
  ]

  public mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
    while let fieldNumber = try decoder.nextFieldNumber() {
      // The use of inline closures is to circumvent an issue where the compiler
      // allocates stack space for every case branch when no optimizations are
      // enabled. https://github.com/apple/swift-protobuf/issues/1034
      switch fieldNumber {
      case 1: try { try decoder.decodeSingularStringField(value: &self.id) }()
      case 2: try { try decoder.decodeSingularStringField(value: &self.name) }()
      case 3: try { try decoder.decodeRepeatedMessageField(value: &self.products) }()
      default: break
      }
    }
  }

  public func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
    if !self.id.isEmpty {
      try visitor.visitSingularStringField(value: self.id, fieldNumber: 1)
    }
    if !self.name.isEmpty {
      try visitor.visitSingularStringField(value: self.name, fieldNumber: 2)
    }
    if !self.products.isEmpty {
      try visitor.visitRepeatedMessageField(value: self.products, fieldNumber: 3)
    }
    try unknownFields.traverse(visitor: &visitor)
  }

  public static func ==(lhs: Google_Jacquard_Protocol_Public_Sdk_GearMetadata.GearData.Vendor, rhs: Google_Jacquard_Protocol_Public_Sdk_GearMetadata.GearData.Vendor) -> Bool {
    if lhs.id != rhs.id {return false}
    if lhs.name != rhs.name {return false}
    if lhs.products != rhs.products {return false}
    if lhs.unknownFields != rhs.unknownFields {return false}
    return true
  }
}

