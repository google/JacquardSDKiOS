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
import CommonCrypto
import CryptoKit
import Foundation

extension Cancellable {
  /// Provides a convenient way to retain Combine observation/Cancellables.
  ///
  /// example usage:
  /// ```
  /// class Foo {
  ///   private var observations = [Cancellable]()
  ///   func foo() {
  ///     somePublisher.sink({}).addTo(&observations)
  ///   }
  /// }
  /// ```
  public func addTo(_ array: inout [Cancellable]) {
    array.append(self)
  }
}

extension Publisher {
  /// Map a publisher with Failure type Never to one with Failure type Error
  ///
  /// This can be necessary since in Combine the error types have to match for `flatMap`. It is tempting to put a where clause on
  /// this extension to limit the application of this function to `Failure == Never` but unfortunately this results in a
  /// `will never be executed` warning in the code below.
  public func mapNeverToError() -> AnyPublisher<Output, Error> {
    return self.mapError { error -> Error in
      // mapNeverToError() is designed for use with <,Never> publishers, which can never reach mapError()
      // In the event it is used on any other publisher, it will be a no-op.
      return error
    }.eraseToAnyPublisher()
  }
}

/// Conforming the request type to support the only two methods needed by the transport (which is
/// here id and serializedData).
/// So we can avoid making any proto types public (Without having to box/unbox them all the time).
extension Google_Jacquard_Protocol_Request: V2ProtocolCommandRequestIDInjectable {}

extension Google_Jacquard_Protocol_Response: V2ProtocolCommandResponseInjectable {}

extension Google_Jacquard_Protocol_Notification: V2ProtocolNotificationInjectable {}

extension String {
  internal func md5Hash() -> String {
    let digest = Insecure.MD5.hash(data: Data(self.utf8))
    return digest.map {
      return String(format: "%x", $0)
    }.joined()
  }

  func sha1() -> String {
    return Data(self.utf8).withUnsafeBytes {
      var digest = [UInt8](repeating: 0, count: Int(CC_SHA1_DIGEST_LENGTH))
      _ = CC_SHA1($0.baseAddress, CC_LONG($0.count), &digest)
      return digest.map { String(format: "%02hhx", $0) }.joined()
    }
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

extension Data {
  func hexEncodedArray() -> String {
    let result = "[\(map { String(format: "0x%02hhx", $0) }.joined(separator: ", "))]"
    return result
  }
}
