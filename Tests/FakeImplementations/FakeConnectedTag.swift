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
import Foundation

@testable import JacquardSDK

final class FakeConnectedTag: ConnectedTag {

  var gearComponent: Component?

  lazy var firmwareUpdateManager: FirmwareUpdateManager = FirmwareUpdateManagerImplementation(
    publishQueue: DispatchQueue.main,
    firmwareUpdateRetriever: FakeFirmwareRetrieverImplementation(),
    connectedTag: self
  )

  var name = "FakeConnectedTagName"
  var namePublisher = Empty<String, Never>().eraseToAnyPublisher()
  var rssiPublisher = Empty<Float, Never>().eraseToAnyPublisher()
  var connectedGear = Empty<Component?, Never>().eraseToAnyPublisher()
  var identifier = UUID()
  var setTouchModeHandler: ((TouchMode, Component) -> AnyPublisher<Void, Error>)!
  var setNameHandler: ((String) -> AnyPublisher<Void, Error>)!
  var registerSubscriptionsHandler: (((SubscribableTag) -> Void) -> Void)!
  var readRSSIHandler: (() -> Void)!
  var transport: Transport
  let fakeVersion = Version(major: 1, minor: 73, micro: 0)

  var tagComponent: Component {
    guard let component = component else {
      let product = GearMetadata.GearData.Product.with {
        $0.id = TagConstants.product
        $0.name = TagConstants.product
        $0.image = "JQTag"
        $0.capabilities = [.led]
      }
      let vendor = GearMetadata.GearData.Vendor.with {
        $0.id = TagConstants.vendor
        $0.name = TagConstants.vendor
        $0.products = [product]
      }
      return ComponentImplementation(
        componentID: TagConstants.FixedComponent.tag.rawValue,
        vendor: vendor,
        product: product,
        isAttached: true,
        version: fakeVersion
      )
    }
    return component
  }

  var component: Component?

  init(transport: Transport) {
    self.transport = transport
  }

  func setTouchMode(
    _ newTouchMode: TouchMode,
    for component: Component
  ) -> AnyPublisher<Void, Error> {
    return setTouchModeHandler(newTouchMode, component)
  }

  func setName(_ name: String) throws -> AnyPublisher<Void, Error> {
    return setNameHandler(name)
  }

  func enqueue<R>(_ commandRequest: R) -> AnyPublisher<R.Response, Error> where R: CommandRequest {

    let subject = PassthroughSubject<R.Response, Error>()
    transport.enqueue(
      request: commandRequest.request,
      type: .withoutResponse,
      retries: 0,
      requestTimeout: 8.0
    ) { commandResult in
      switch commandResult {
      case .failure(let error):
        subject.send(completion: .failure(error))
      case .success(let outerProto):
        let innerResult = commandRequest.parseOuterResponse(data: outerProto).flatMap {
          commandRequest.parseResponse(outerProto: $0)
        }
        switch innerResult {
        case .failure(let error):
          subject.send(completion: .failure(error))
        case .success(let innerProto):
          subject.send(innerProto)
        }
      }
    }

    return
      subject
      .buffer(size: Int.max, prefetch: .byRequest, whenFull: .dropOldest)
      .receive(on: DispatchQueue.main)
      .eraseToAnyPublisher()
  }

  func enqueue<R>(
    _ commandRequest: R,
    retries: Int
  ) -> AnyPublisher<R.Response, Error> where R: CommandRequest {
    preconditionFailure()
  }

  func registerSubscriptions(_ subscriptions: (SubscribableTag) -> Void) {
    return registerSubscriptionsHandler(subscriptions)
  }

  func readRSSI() {
    return readRSSIHandler()
  }

  func send(data: Data) {
    transport.send(data: data)
  }
}
