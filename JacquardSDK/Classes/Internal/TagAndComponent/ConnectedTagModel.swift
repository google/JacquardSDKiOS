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
      let configWriteRequest = UJTWriteConfigCommand(config: config)
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
    let configWriteRequest = UJTWriteConfigCommand(config: config)
    return self.enqueue(configWriteRequest).flatMap { _ -> AnyPublisher<Void, Error> in
      // After successfully writing the custom name, the tag needs to be disconnected to reflect the
      // updated name.
      let disconnectTagRequest = DisconnectTagCommand()
      return self.enqueue(disconnectTagRequest)
    }.eraseToAnyPublisher()
  }

  var tagComponent: Component {
    return ComponentImplementation.tagComponent
  }

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
  var identifier: UUID {
    return transport.peripheralIdentifier
  }

  private var transport: Transport

  private var observations = [Cancellable]()

  init(transport: Transport, userPublishQueue: DispatchQueue) {
    self.transport = transport
    self.userPublishQueue = userPublishQueue

    let attachedRequest = AttachedNotificationSubscription()
    jqLogger.debug("subscribing to gear attachments")
    self.connectedGear = self.subscribe(attachedRequest).flatMap {
      [weak self] component -> AnyPublisher<Component?, Never> in
      guard let component = component, let self = self else {
        return Just<Component?>(nil).eraseToAnyPublisher()
      }

      if !component.isAttached {
        return Just<Component?>(nil).eraseToAnyPublisher()
      }

      // Our API promises that every time we connect the gear will be in gesture mode, so we need
      // to do our best to ensure that.
      return self.setTouchMode(.gesture, for: component).map { _ -> Component? in
        return component
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

  func registerSubscriptions(_ subscriptions: (SubscribableTag) -> Void) {
    subscriptions(self)
    transport.stopCachingNotifications()
  }

  private func parseOuterResponse(data: Data) -> Result<Google_Jacquard_Protocol_Response, Error> {
    do {
      let outerProto = try Google_Jacquard_Protocol_Response(
        serializedData: data, extensions: Google_Jacquard_Protocol_Jacquard_Extensions)

      guard outerProto.status == .ok else {
        let error =
          CommandResponseStatus(rawValue: outerProto.status.rawValue)
          ?? CommandResponseStatus.errorAppUnknown
        return .failure(error)
      }
      return .success(outerProto)
    } catch (let error) {
      return .failure(error)
    }
  }

  func enqueue<R>(_ commandRequest: R, retries: Int) -> AnyPublisher<R.Response, Error>
  where R: CommandRequest {

    let subject = PassthroughSubject<R.Response, Error>()
    transport.enqueue(
      request: commandRequest.request,
      type: .withoutResponse,
      retries: retries
    ) { commandResult in
      switch commandResult {
      case .failure(let error):
        subject.send(completion: .failure(error))
      case .success(let outerProto):
        let innerResult = self.parseOuterResponse(data: outerProto).flatMap {
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
      .compactMap { outerProto -> S.Notification? in
        jqLogger.debug(
          "attempting to extract notification for subscription \(subscription) from payload \(outerProto)"
        )
        return subscription.extract(from: outerProto)
      }.buffer(size: Int.max, prefetch: .byRequest, whenFull: .dropOldest)
      .receive(on: userPublishQueue)
      .eraseToAnyPublisher()
  }

}
