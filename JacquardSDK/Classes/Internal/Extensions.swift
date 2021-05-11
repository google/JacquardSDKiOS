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
  func addTo(_ array: inout [Cancellable]) {
    array.append(self)
  }
}

extension Publisher {
  /// Map a publisher with Failure type Never to one with Failure type Error
  ///
  /// This can be necessary since in Combine the error types have to match for `flatMap`. It is tempting to put a where clause on
  /// this extension to limit the application of this function to `Failure == Never` but unfortunately this results in a
  /// `will never be executed` warning in the code below.
  func mapNeverToError() -> AnyPublisher<Output, Error> {
    return self.mapError { error -> Error in
      // mapNeverToError() is designed for use with <,Never> publishers, which can never reach mapError()
      // In the event it is used on any other publisher, it will be a no-op.
      return error
    }.eraseToAnyPublisher()
  }
}

/// So we can avoid making any proto types public (and without having to box/unbox them all the time)
/// we conform the request type to support the only two methods needed by the transport.
extension Google_Jacquard_Protocol_Request: V2ProtocolCommandRequestIDInjectable {}
