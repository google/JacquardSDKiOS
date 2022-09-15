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
import CoreBluetooth
import SwiftProtobuf

class ConnectedTagModel: ConnectedTag, SubscribableTag {

  private enum Constants {
    static let requestTimeout = 8.0
  }

  private let userPublishQueue: DispatchQueue

  func setTouchMode(_ newTouchMode: TouchMode, for component: Component) -> AnyPublisher<
    Void, Error
  > {
    // When we toggle the touch mode we also need to update the notification queue depth
    // appropriately. It's possible in the future we may wish to allow SDK users to control the
    // queue depth separately, especially if there are conflicting needs, but for now we can keep
    // it easy to use by handling this detail automatically.
    let touchModeRequest = SetTouchModeCommand(component: component, mode: newTouchMode)
    return self.enqueue(touchModeRequest).flatMap { _ -> AnyPublisher<Void, Error> in
      var config = Google_Jacquard_Protocol_BleConfiguration()
      switch newTouchMode {
      case .gesture:
        config.notifQueueDepth = 14
      case .continuous:
        config.notifQueueDepth = 2
      }
      let configWriteRequest = UJTConfigWriteCommand(config: config)
      return self.enqueue(configWriteRequest)
    }.eraseToAnyPublisher()
  }

  func setName(_ name: String) throws -> AnyPublisher<Void, Error> {

    // Check if the name is valid.
    guard name.utf8.count > 0 && name.utf8.count < 22, name != self.name else {
      throw SetNameError.invalidParameter
    }

    var config = Google_Jacquard_Protocol_BleConfiguration()
    config.customAdvName = name
    let configWriteRequest = UJTConfigWriteCommand(config: config)
    return self.enqueue(configWriteRequest).flatMap { _ -> AnyPublisher<Void, Error> in
      // After successfully writing the custom name, the tag needs to be disconnected to reflect the
      // updated name.
      let disconnectTagRequest = DisconnectTagCommand()
      return self.enqueue(disconnectTagRequest)
    }.eraseToAnyPublisher()
  }

  let tagComponent: Component

  var gearComponent: Component?

  var connectedGear: AnyPublisher<Component?, Never> = Just<Component?>(nil).eraseToAnyPublisher()

  var name: String {
    return transport.peripheralName
  }

  var namePublisher: AnyPublisher<String, Never> {
    return transport.peripheralNamePublisher
      .buffer(size: Int.max, prefetch: .byRequest, whenFull: .dropOldest)
      .receive(on: userPublishQueue)
      .eraseToAnyPublisher()
  }

  var rssiPublisher: AnyPublisher<Float, Never> {
    return transport.peripheralRSSIPublisher
      .buffer(size: Int.max, prefetch: .byRequest, whenFull: .dropOldest)
      .receive(on: userPublishQueue)
      .eraseToAnyPublisher()
  }

  var identifier: UUID {
    return transport.peripheralIdentifier
  }

  private var transport: Transport
  private let sdkConfig: SDKConfig

  private var observations = [Cancellable]()

  lazy var firmwareUpdateManager: FirmwareUpdateManager = FirmwareUpdateManagerImplementation(
    publishQueue: userPublishQueue,
    firmwareUpdateRetriever: FirmwareUpdateRetrieverImplementation(config: sdkConfig),
    connectedTag: self
  )

  init(
    transport: Transport, userPublishQueue: DispatchQueue, tagComponent: Component,
    sdkConfig: SDKConfig
  ) {
    self.transport = transport
    self.userPublishQueue = userPublishQueue
    self.tagComponent = tagComponent
    self.sdkConfig = sdkConfig

    let attachedRequest = AttachedNotificationSubscription()
    jqLogger.debug("subscribing to gear attachments")
    self.connectedGear = self.subscribe(attachedRequest).flatMap {
      [weak self] component -> AnyPublisher<Component?, Never> in
      guard let component = component, let self = self else {
        self?.gearComponent = nil
        return Just<Component?>(nil).eraseToAnyPublisher()
      }

      if !component.isAttached {
        self.gearComponent = nil
        return Just<Component?>(nil).eraseToAnyPublisher()
      }

      self.gearComponent = component

      // Our API promises that every time we connect the gear will be in gesture mode, so we need
      // to do our best to ensure that.
      return self.setTouchMode(.gesture, for: component)
        .flatMap { _ -> AnyPublisher<Component?, Error> in
          return self.fetchGearComponentInfo(component).mapNeverToError().map {
            updatedComponent -> Component? in
            self.gearComponent = updatedComponent
            return updatedComponent
          }.eraseToAnyPublisher()
        }.catch({ error -> AnyPublisher<Component?, Never> in
          // If after retries this command still fails the connection
          // is probably dead anyway, so ignoring the error is reasonable here since we will reconnect.
          jqLogger.error("Error setting default touch mode: \(error)")
          return Just<Component?>(component).eraseToAnyPublisher()
        }).eraseToAnyPublisher()

    }.shareReplayingLatestWhileNotComplete()
      .eraseToAnyPublisher()
    // shareReplay() is necessary to supply the semantics that a currently attached gear
    // can be obtained at any time.

    // We need to ensure there is always demand/back-pressure otherwise the current connected gear
    // will not be monitored if the SDK client isn't monitoring this.
    self.connectedGear.sink { (_) in
      jqLogger.debug("sinking useless attachment")
    }.addTo(&observations)
  }

  // TODO(b/193624149): Concrete ComponentImplementationType should not be necessary here.
  private func fetchGearComponentInfo(
    _ component: ComponentImplementation
  ) -> AnyPublisher<Component?, Never> {
    let componentInfoCommand = ComponentInfoCommand(componentID: component.componentID)
    return enqueue(componentInfoCommand).map {
      ComponentImplementation(
        componentID: component.componentID,
        vendor: component.vendor,
        product: component.product,
        isAttached: component.isAttached,
        version: $0.version,
        uuid: $0.uuid
      )
    }.catch { error -> AnyPublisher<Component?, Never> in
      return Just<Component?>(component).eraseToAnyPublisher()
    }.eraseToAnyPublisher()
  }

  func registerSubscriptions(_ subscriptions: (SubscribableTag) -> Void) {
    subscriptions(self)
    transport.stopCachingNotifications()
  }

  func enqueue<R>(_ commandRequest: R, retries: Int) -> AnyPublisher<R.Response, Error>
  where R: CommandRequest {
    let subject = PassthroughSubject<R.Response, Error>()
    transport.enqueue(
      request: commandRequest.request,
      type: .withoutResponse,
      retries: retries,
      requestTimeout: Constants.requestTimeout
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
      .receive(on: userPublishQueue)
      .eraseToAnyPublisher()
  }

  func enqueue<R>(_ commandRequest: R) -> AnyPublisher<R.Response, Error> where R: CommandRequest {
    enqueue(commandRequest, retries: 2)
  }

  func subscribe<S>(_ subscription: S) -> AnyPublisher<S.Notification, Never>
  where S: NotificationSubscription {
    return transport.notificationPublisher
      .compactMap { packet -> S.Notification? in
        guard let outerProto = try? subscription.parseNotification(packet) else {
          jqLogger.debug(
            "attempting to extract notification for subscription \(subscription) from payload")
          return nil
        }
        jqLogger.debug("notification: \(outerProto)")
        return subscription.extract(from: outerProto)
      }.buffer(size: Int.max, prefetch: .byRequest, whenFull: .dropOldest)
      .receive(on: userPublishQueue)
      .eraseToAnyPublisher()
  }

  func subscribeRawData() -> AnyPublisher<Data, Never> {
    return transport.rawDataPublisher
      .receive(on: userPublishQueue)
      .eraseToAnyPublisher()
  }

  func subscribeRawBytes() -> AnyPublisher<[UInt8], Never> {
    return transport.rawBytesPublisher
      .receive(on: userPublishQueue)
      .eraseToAnyPublisher()
  }

  func subscribeRawDataPacket() -> AnyPublisher<Data, Never> {
    return transport.rawDataPacketPublisher
      .receive(on: userPublishQueue)
      .eraseToAnyPublisher()
  }

  func readRSSI() {
    transport.readRSSI()
  }

  func send(data: Data) {
    transport.send(data: data)
  }
}
