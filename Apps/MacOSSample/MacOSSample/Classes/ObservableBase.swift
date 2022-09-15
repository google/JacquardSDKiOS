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

/// Base class for ObservableObjects.
///
/// Contains helper methods for binding Combine publishers to observable properties.
class ObservableBase: ObservableObject {
  var observations = [AnyCancellable]()

  func bind<T>(_ publisher: AnyPublisher<T, Never>, writer: @escaping (T) -> Void) {
    publisher
      .sink { [weak self] value in
        guard let self = self else { return }
        self.objectWillChange.send()
        writer(value)
      }.addTo(&observations)
  }

  func bind<T>(_ publisher: AnyPublisher<T, Error>, writer: @escaping (T) -> Void) {
    publisher
      .sink(
        receiveCompletion: { _ in
          // Ignoring error completions.
        },
        receiveValue: { [weak self] value in
          guard let self = self else { return }
          self.objectWillChange.send()
          writer(value)
        }
      ).addTo(&observations)
  }
}
