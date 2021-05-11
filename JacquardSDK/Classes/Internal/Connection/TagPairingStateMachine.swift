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

class TagPairingStateMachine: NSObject {

  static let initialState: State = .disconnected
  static let requiredNotifyingCharacteristics = [
    PeripheralUUID(uuid: JacquardServices.responseUUID),
    PeripheralUUID(uuid: JacquardServices.notifyUUID),
  ]

  private let stateSubject = CurrentValueSubject<State, Never>(TagPairingStateMachine.initialState)
  lazy var statePublisher: AnyPublisher<State, Never> = stateSubject.eraseToAnyPublisher()

  private var peripheral: Peripheral
  private var context = Context()
  private var marshalQueue = DispatchQueue(label: "TagPairingStateMachine marshaling queue")

  private var state: State = TagPairingStateMachine.initialState {
    didSet {
      stateSubject.send(state)
    }
  }

  enum State {
    case preparingToConnect
    case disconnected
    case bluetoothConnected
    case servicesDiscovered
    case batteryCharacteristicDiscovered
    case awaitingNotificationUpdates
    case tagPaired(Peripheral, RequiredCharacteristics)
    case error(Error)

    var isTerminal: Bool {
      switch self {
      case .tagPaired, .error: return true
      default: return false
      }
    }
  }

  private enum Event {
    case didConnect(Peripheral)
    case failedToConnect(Peripheral, Error)
    case miscCoreBluetoothError(Error)
    case didDiscoverServices([Service])
    case didDiscoverCharacteristics(Service, [Characteristic])
    case didUpdateNotificationState(Characteristic, Error?)
  }

  private struct Context {
    var batteryService: Service?
    var v2Service: Service?
    var commandCharacteristic: Characteristic?
    var responseCharacteristic: Characteristic?
    var notifyCharacteristic: Characteristic?
    var successfulNotifyChars = Set<PeripheralUUID>()
  }

  init(peripheral: Peripheral) {
    self.peripheral = peripheral
    super.init()

    // Once pairing is finished, the delegate can be assumed by another object.
    self.peripheral.delegate = self
  }
}

//MARK: - External event methods.

extension TagPairingStateMachine {

  func didConnect(peripheral: Peripheral) {
    marshalQueue.async {
      self.handleEvent(.didConnect(peripheral))
    }
  }

  func didFailToConnect(peripheral: Peripheral, error: Error) {
    marshalQueue.async {
      self.handleEvent(.failedToConnect(peripheral, error))
    }
  }
}

//MARK: - CBPeripheralDelegate events.

extension TagPairingStateMachine: PeripheralDelegate {

  func peripheral(_ peripheral: Peripheral, didDiscoverServices error: Error?) {
    marshalQueue.async {
      if let services = peripheral.services {
        self.handleEvent(.didDiscoverServices(services))
      } else {
        let error = error ?? TagConnectionError.unknownCoreBluetoothError
        self.handleEvent(.miscCoreBluetoothError(error))
      }
    }
  }

  func peripheral(
    _ peripheral: Peripheral, didDiscoverCharacteristicsFor service: Service, error: Error?
  ) {
    marshalQueue.async {
      if let chars = service.characteristics {
        self.handleEvent(.didDiscoverCharacteristics(service, chars))
      } else {
        let error = error ?? TagConnectionError.unknownCoreBluetoothError
        self.handleEvent(.miscCoreBluetoothError(error))
      }
    }
  }

  func peripheral(
    _ peripheral: Peripheral, didUpdateNotificationStateFor characteristic: Characteristic,
    error: Error?
  ) {
    marshalQueue.async {
      self.handleEvent(.didUpdateNotificationState(characteristic, error))
    }
  }
}

//MARK: - Transitions.

// Legend of comments that cross reference the Dot Statechart at the end of this file.
// (labels) cross reference individual transitions
// case where clauses represent [guard] statements
// / Actions are labelled with comments in the case bodies.

extension TagPairingStateMachine {
  /// Examines events and current state to apply transitions.
  private func handleEvent(_ event: Event) {
    dispatchPrecondition(condition: .onQueue(marshalQueue))

    if state.isTerminal {
      jqLogger.info("State machine is already terminal, ignoring event: \(event)")
    }

    jqLogger.debug("Entering \(self).handleEvent(\(state), \(event)")

    switch (state, event) {

    // (e1)
    case (_, .miscCoreBluetoothError(let error)):
      // These errors can be specialized if we want to handle/retry any of them.
      state = .error(TagConnectionError.bluetoothConnectionError(error))

    // (t2)
    case (.disconnected, .didConnect(let peripheral))
    where peripheral.identifier == self.peripheral.identifier:
      state = .bluetoothConnected
      // Discover services.
      peripheral.discoverServices([PeripheralUUID(uuid: JacquardServices.v2Service)])

    // (e3)
    case (.disconnected, .didConnect):
      jqLogger.assert("Failed peripheral identifier guard.")
      state = .error(TagConnectionError.internalError)

    // (e4)
    case (.disconnected, .failedToConnect(_, let error)):
      // Not too worried about disambiguating error state if the peripheral doesn't match since that
      // would be a programmer error.
      state = .error(TagConnectionError.bluetoothConnectionError(error))

    // (t5)
    case (.bluetoothConnected, .didDiscoverServices(let services))
    where services.map({ $0.uuid }).contains(JacquardServices.v2Service):
      // / Store services.
      for service in services {
        switch service.uuid {
        case JacquardServices.v2Service:
          context.v2Service = service
        default:
          // Ignore unexpected services.
          break
        }
      }
      guard let v2Service = context.v2Service else {
        preconditionFailure("batteryServices is nil even though where clause passed!")
      }
      state = .servicesDiscovered
      // Discover the v2Characteristics
      peripheral.discoverCharacteristics(
        JacquardServices.v2Characteristics.map { PeripheralUUID(uuid: $0) },
        for: v2Service
      )

    // (e6)
    case (.bluetoothConnected, .didDiscoverServices(_)):
      state = .error(TagConnectionError.serviceDiscoveryError)

    // (t7)
    case (.servicesDiscovered, .didDiscoverCharacteristics(let service, let chars))
    where
      service.uuid == JacquardServices.v2Service
      && Set(chars.map({ $0.uuid })).isSuperset(of: JacquardServices.v2Characteristics):

      for characteristic in chars {
        switch characteristic.uuid {
        case JacquardServices.commandUUID:
          context.commandCharacteristic = characteristic
        case JacquardServices.responseUUID:
          context.responseCharacteristic = characteristic
        case JacquardServices.notifyUUID:
          context.notifyCharacteristic = characteristic
        default:
          // Ignore unexpected characteristics.
          break
        }
      }
      state = .awaitingNotificationUpdates
      // / Start Notifications
      for characteristic in chars {
        let uuid = PeripheralUUID(uuid: characteristic.uuid)
        if TagPairingStateMachine.requiredNotifyingCharacteristics.contains(uuid) {
          peripheral.setNotifyValue(true, for: characteristic)
        }
      }

    // (e8)
    case (_, .didDiscoverCharacteristics):
      state = .error(TagConnectionError.characteristicDiscoveryError)

    // (e9)
    case (.awaitingNotificationUpdates, .didUpdateNotificationState(_, let error))
    where error != nil:
      state = .error(TagConnectionError.bluetoothNotificationUpdateError(error!))

    // (t10)
    case (.awaitingNotificationUpdates, .didUpdateNotificationState(let characteristic, _))
    where
      context.successfulNotifyChars.union([PeripheralUUID(uuid: characteristic.uuid)]).isSuperset(
        of: TagPairingStateMachine.requiredNotifyingCharacteristics):
      guard let commandCharacteristic = context.commandCharacteristic,
        let responseCharacteristic = context.responseCharacteristic,
        let notifyCharacteristic = context.notifyCharacteristic
      else {
        assertionFailure(
          "It shouldn't be possible to be missing any characteristics at transition (t5)")
        state = .error(TagConnectionError.characteristicDiscoveryError)
        return
      }
      let characteristics = RequiredCharacteristics(
        commandCharacteristic: commandCharacteristic,
        responseCharacteristic: responseCharacteristic, notifyCharacteristic: notifyCharacteristic)
      state = .tagPaired(peripheral, characteristics)

    // (t11)
    case (.awaitingNotificationUpdates, .didUpdateNotificationState(let characteristic, _)):
      state = .awaitingNotificationUpdates
      // / Record notifying characteristic.
      context.successfulNotifyChars.insert(PeripheralUUID(uuid: characteristic.uuid))

    // No valid transition found.
    default:
      jqLogger.error("No transition found for (\(state), \(event))")
      state = .error(TagConnectionError.internalError)
    }

    jqLogger.debug("Exiting \(self).handleEvent() new state: \(state)")
  }
}

//MARK: - Dot Statechart

// Note that the order is important - the transition events/guards will be evaluated in order and
// only the first matching transition will have effect.

// //TODO: add timeout for discovery phases. No timeout should apply to connection, since connection
// // can take an infinite amount of time while the tag is out of range or asleep.
//
//
// digraph {
//   node [shape=point] start, complete;
//   node [shape=Mrecord]
//   edge [decorate=1, minlen=2]
//
//   pairingComplete
//     [label="{pairingComplete|NB: not protocol initiazlied}"]
//
//   start -> disconnected;
//
//   //TODO: validate characteristic properties (eg. writable)
//
//   "*" -> error
//     [label="(e1) miscCoreBluetoothError(error)"]
//
//   disconnected -> bluetoothConnected
//     [label="(t2)
//             didConnect(peripheral)
//             [peripheral.uuid == self.peripheral.uuid]
//             / discoverServices"];
//     disconnected -> error
//     [label="(e3) didConnect(peripheral)"];
//   disconnected -> error
//     [label="(e4) failedToConnect(error)"];
//
//   bluetoothConnected -> servicesDiscovered
//     [label="(t5)
//             didDiscoverServices(services)
//             [services.map(uuid).contains(v2Service)]
//             / storeServices,discoverV2Characteristics"];
//   bluetoothConnected -> error
//     [label="(e6) didDiscoverServices(_)"];
//
//   servicesDiscovered -> awaitingNotificationUpdates
//     [label="(t7)
//             didDiscoverCharacteristics(service chars)
//             [service.uuid == v2ServiceUUID && chars.map(uuid) == v2CharacteristicUUIDs]
//             / storeV2Chars,startNotifications"];
//   servicesDiscovered -> error
//     [label="(e8) didDiscoverCharacteristics(_)"];
//
//   awaitingNotificationUpdates -> error
//     [label="(e9)
//             didUpdateNotificationState(char, error?)
//             [error != nil]"];
//
//   awaitingNotificationUpdates -> pairingComplete
//     [label="(t10)
//             didUpdateNotificationState(char, error?)
//             [(alreadyNotifyingChars + [char.uuid]) ⊇ requiredNotifyingChars]
//             / createJacquardConnectedTagInstance"]
//
//   awaitingNotificationUpdates -> awaitingNotificationUpdates
//     [label="(t11)
//         didUpdateNotificationState(char, error?)
//         / alreadyNotifyingChars.append(char.uuid)"]
//
//   pairingComplete -> complete;
// }
