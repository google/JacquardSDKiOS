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

struct RequiredCharacteristics {
  var commandCharacteristic: Characteristic
  var responseCharacteristic: Characteristic
  var notifyCharacteristic: Characteristic
  var rawDataCharacteristic: Characteristic
}

/// Tracks transport state for a connection.
class JacquardTransportState {
  private var requestId: UInt32 = 0
  var commandFragmenter: Fragmenter
  var notificationFragmenter: Fragmenter
  var rawDataFragmenter: Fragmenter

  /// This should be used when re-trying sending a request.
  var lastRequestId: UInt32 {
    return requestId
  }

  /// This should be used when sending a request for the first time.
  func nextRequestId() -> UInt32 {
    // Protocol v2 only uses 1...255 for request id.
    requestId = (requestId + 1) % 255
    return requestId
  }

  init() {
    let mtu = ProtocolSpec.version2.mtu
    self.commandFragmenter = Fragmenter(mtu: mtu)
    self.notificationFragmenter = Fragmenter(mtu: mtu)
    self.rawDataFragmenter = Fragmenter(mtu: mtu)
  }
}

class TransportV2Implementation: Transport {

  private var peripheral: Peripheral
  private let transportState = JacquardTransportState()
  private let characteristics: RequiredCharacteristics
  private var observations = [Cancellable]()

  // To trigger failure if any `CommandRequest` does not complete in 8 seconds.
  private var commandExecutionTimer: DispatchSourceTimer?
  private var commandExecutionDuration = 8.0

  private let didWriteCommandSubject = PassthroughSubject<Error?, Never>()
  /// Publisher of any time CoreBluetooth reports didWriteValue.
  ///
  /// Currently write responses are only requested during initialization, so this is not generally useful.
  lazy var didWriteCommandPublisher = didWriteCommandSubject.eraseToAnyPublisher()

  private let notificationSubject = PassthroughSubject<
    Google_Jacquard_Protocol_Notification, Never
  >()

  private let rawDataSubject = PassthroughSubject<Data, Never>()

  var notificationPublisher: AnyPublisher<Google_Jacquard_Protocol_Notification, Never> {
    notificationCacheLock.lock()
    defer { notificationCacheLock.unlock() }
    if cacheNotifications {
      jqLogger.debug("including \(pendingNotifications.count) cached notifications")
      return Publishers.Concatenate(
        prefix: Publishers.Sequence(sequence: pendingNotifications),
        suffix: notificationSubject
      )
      .eraseToAnyPublisher()
    } else {
      jqLogger.debug("not including pending notifications")
      return notificationSubject.eraseToAnyPublisher()
    }
  }

  var rawDataPublisher: AnyPublisher<Data, Never> {
    return rawDataSubject.eraseToAnyPublisher()
  }
  // Since we want this object to have sole access to the peripheral we also
  // need to expose the name here.
  private let peripheralNameSubject: CurrentValueSubject<String, Never>
  lazy var peripheralNamePublisher = peripheralNameSubject.eraseToAnyPublisher()
  var peripheralName: String {
    return peripheralNameSubject.value
  }

  private let peripheralRSSISubject = PassthroughSubject<Float, Never>()
  lazy var peripheralRSSIPublisher = peripheralRSSISubject.eraseToAnyPublisher()

  var peripheralIdentifier: UUID {
    return peripheral.identifier
  }

  var lastRequestId: UInt32 {
    return transportState.lastRequestId
  }

  required init(peripheral: Peripheral, characteristics: RequiredCharacteristics) {
    self.peripheral = peripheral
    self.characteristics = characteristics
    self.peripheralNameSubject = CurrentValueSubject<String, Never>(peripheral.name ?? "")
    self.peripheral.delegate = self
  }

  /// The queue used for serializing access to request/response/notification data structures.
  private let requestResponseQueue = DispatchQueue(label: "TransportRequestQueue")

  /// The temporary cache of notifications used to hold notifications before the client gets a chance to subscribe.
  private var pendingNotifications = [Google_Jacquard_Protocol_Notification]()

  private var notificationCacheLock = NSLock()

  /// Once the client has first subscribed to notifications, they will no longer be cached.
  private(set) var cacheNotifications = true

  func stopCachingNotifications() {
    notificationCacheLock.lock()
    let canReturnEarly = !self.cacheNotifications
    notificationCacheLock.unlock()

    if canReturnEarly {
      return
    }

    // The only safe way to ensure there's no race condition with in-flight notification
    // subscriptions is to wait for the next notification delivery before stopping caching.
    notificationSubject.sink { _ in
      self.notificationCacheLock.lock()
      defer { self.notificationCacheLock.unlock() }
      jqLogger.debug("stopped caching notifications")
      self.cacheNotifications = false
      self.pendingNotifications.removeAll()
    }.addTo(&observations)
  }

  func readRSSI() {
    peripheral.readRSSI()
  }

  /// Array of tuples containing (request, BLEWriteType, retries, callback)
  private var pendingRequests = [
    (V2ProtocolCommandRequestIDInjectable, CharacteristicWriteType, Int, RequestCallback)
  ]()

  // Only during initialization do we use .withResponse.
  func enqueue(
    request: V2ProtocolCommandRequestIDInjectable,
    type: CharacteristicWriteType = .withoutResponse,
    retries: Int,
    requestTimeout: TimeInterval,
    callback: @escaping RequestCallback
  ) {
    commandExecutionDuration = requestTimeout
    requestResponseQueue.async {
      self.pendingRequests.append((request, type, retries, callback))
      if self.pendingRequests.count == 1 {
        self.sendNextRequest()
      }
      // Else there's already a pending request in flight.
    }
  }

  private func sendNextRequest() {
    dispatchPrecondition(condition: .onQueue(requestResponseQueue))

    invalidateCommandExecutionTimer()
    guard let (originalRequest, type, retries, callback) = pendingRequests.first else {
      return
    }

    var request = originalRequest
    request.id = transportState.nextRequestId()
    do {
      let packet = try request.serializedData(partial: false)
      let fragments = transportState.commandFragmenter.fragments(fromPacket: packet)
      for fragment in fragments {
        peripheral.writeValue(fragment, for: characteristics.commandCharacteristic, type: type)
      }
      commandExecutionTimer = DispatchSource.makeTimerSource(queue: requestResponseQueue)
      commandExecutionTimer?.setEventHandler {
        let (_, _, _, callback) = self.pendingRequests.removeFirst()
        // Dispatch off our queue in case the callback takes some time.
        DispatchQueue.main.async {
          callback(.failure(CommandResponseStatus.errorAppTimeout))
        }
        self.sendNextRequest()
      }
      commandExecutionTimer?.schedule(
        deadline: DispatchTime.now() + commandExecutionDuration
      )
      commandExecutionTimer?.resume()
    } catch (let error) {
      if retries > 0 {
        // Decrement retry count.
        pendingRequests[0] = (originalRequest, type, retries - 1, callback)
      } else {
        pendingRequests.removeFirst()
        // Dispatch off our queue in case the callback takes some time.
        DispatchQueue.main.async {
          callback(.failure(error))
        }
      }
      sendNextRequest()
    }
  }

  private func deliverPacket(packet: Data) {
    invalidateCommandExecutionTimer()
    requestResponseQueue.async {
      guard self.pendingRequests.count > 0 else {
        jqLogger.warning("Received command response, but pendingRequests array was empty.")
        // This can happen if the tag re-sends a response, so silently drop.
        return
      }

      // Success! Remove entry from queue, send callback and process next pending request (if any).

      let (_, _, _, callback) = self.pendingRequests.removeFirst()
      // Dispatch off our queue in case the callback takes some time.
      DispatchQueue.main.async {
        callback(.success(packet))
      }
      self.sendNextRequest()
    }
  }

  func deliverNotification(packet: Data) {
    do {
      let notification = try Google_Jacquard_Protocol_Notification(
        serializedData: packet, extensions: Google_Jacquard_Protocol_Jacquard_Extensions)

      jqLogger.debug("notification: \(notification)")
      notificationCacheLock.lock()
      if cacheNotifications {
        jqLogger.debug("caching: \(notification)")
        pendingNotifications.append(notification)
      }
      // Important that we unlock here before publishing to avoid a possible deadlock since we don't
      // control what happens in the publisher below.
      notificationCacheLock.unlock()

      notificationSubject.send(notification)
    } catch (let error) {
      jqLogger.error("Malformed notification, couldn't deserialize: \(error)")
    }
  }

  func processRawDataPacket(packet: Data) {

    let sequence = Int(packet[0])
    jqLogger.info("Received seq: \(sequence)")

    let payload = packet[1...]
    rawDataSubject.send(payload)

    sendAck(sequence: sequence)
  }

  private func sendAck(sequence: Int) {
    jqLogger.info("Send Ack for Sequence No: \(sequence)")
    // 65 is the Acknowledgement Databyte
    let data = Data([UInt8(sequence), 65])
    let fragments = self.transportState.rawDataFragmenter.fragments(fromPacket: data)
    for fragment in fragments {
      peripheral.writeValue(
        fragment, for: characteristics.rawDataCharacteristic, type: .withoutResponse)
    }
  }

  private func invalidateCommandExecutionTimer() {
    commandExecutionTimer?.cancel()
    commandExecutionTimer = nil
  }
}

extension TransportV2Implementation: PeripheralDelegate {

  func peripheralDidUpdateName(_ peripheral: Peripheral) {
    peripheralNameSubject.send(peripheral.name ?? "")
  }

  func peripheral(_ peripheral: Peripheral, didReadRSSI rssiValue: Float, error: Error?) {
    peripheralRSSISubject.send(rssiValue)
  }

  func peripheral(
    _ peripheral: Peripheral,
    didWriteValueFor characteristic: Characteristic,
    error: Error?
  ) {

    guard characteristic.uuid == JacquardServices.commandUUID else {
      jqLogger.assert(
        "Received didWriteValueFor for an unexpected characteristic: \(characteristic.uuid)"
      )
      self.didWriteCommandSubject.send(TagConnectionError.internalError)
      return
    }
    self.didWriteCommandSubject.send(error)
  }

  func peripheral(
    _ peripheral: Peripheral,
    didUpdateValueFor characteristic: Characteristic,
    error: Error?
  ) {

    switch characteristic.uuid {
    case JacquardServices.responseUUID:
      // NB: we don't expect error to be non-nil since we never request a read, just observe
      // notifications.
      guard let fragment = characteristic.value else {
        jqLogger.assert("Received didUpdateValueFor Response characteristic with empty data")
        return
      }
      // Accumulate fragments & deliver response.
      if let packet = self.transportState.commandFragmenter.packet(fromAddedFragment: fragment) {
        self.deliverPacket(packet: packet)
      }

    case JacquardServices.notifyUUID:
      guard let fragment = characteristic.value else {
        jqLogger.assert("Received didUpdateValueFor Notification characteristic with empty data")
        return
      }
      // Accumulate fragments & deliver notification.
      if let packet = self.transportState.notificationFragmenter.packet(fromAddedFragment: fragment)
      {
        self.deliverNotification(packet: packet)
      }

    case JacquardServices.rawDataUUID:
      guard let data = characteristic.value else {
        jqLogger.assert("Received didUpdateValueFor data characteristic with empty data")
        return
      }
      if let packet = self.transportState.rawDataFragmenter.packet(fromAddedFragment: data) {
        self.processRawDataPacket(packet: packet)
      }

    default:
      jqLogger.assert("Ignore unexpected BLE notifications.")
      break
    }
  }
}
