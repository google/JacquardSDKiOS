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
import XCTest

@testable import JacquardSDK

class JacquardTagInternalTests: XCTestCase {

  struct FakeAdvertisedTag: AdvertisedTag {
    var pairingSerialNumber = "FakePairingSerialNumber"
    var identifier = UUID()
  }

  struct FakeConnectedTag: ConnectedTag {
    var serialNumber = "123"
    var name = "FakeConnectedTagName"
    var namePublisher = Empty<String, Never>().eraseToAnyPublisher()
    var tagComponent: Component = ComponentImplementation.tagComponent
    var connectedGear = Empty<Component?, Never>().eraseToAnyPublisher()
    var identifier = UUID()

    func setTouchMode(_ newTouchMode: TouchMode, for component: Component) -> AnyPublisher<
      Void, Error
    > {
      preconditionFailure()
    }

    func setName(_ name: String) -> AnyPublisher<Void, Error> {
      preconditionFailure()
    }

    func enqueue<R>(_ commandRequest: R) -> AnyPublisher<R.Response, Error>
    where R: CommandRequest {
      preconditionFailure()
    }

    func enqueue<R>(_ commandRequest: R, retries: Int) -> AnyPublisher<R.Response, Error>
    where R: CommandRequest {
      preconditionFailure()
    }

    func registerSubscriptions(_ subscriptions: (SubscribableTag) -> Void) {
      preconditionFailure()
    }
  }

  func testDisplayName() {
    XCTAssertEqual(FakeAdvertisedTag().displayName, FakeAdvertisedTag().pairingSerialNumber)
    XCTAssertEqual(FakeConnectedTag().displayName, FakeConnectedTag().name)
  }
}
