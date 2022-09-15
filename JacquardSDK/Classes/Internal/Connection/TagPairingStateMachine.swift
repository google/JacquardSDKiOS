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
import Foundation

class TagPairingStateMachine: NSObject {

  static let initialState: State = .disconnected
  static let requiredNotifyingCharacteristics = [
    UUID(JacquardServices.responseUUID),
    UUID(JacquardServices.notifyUUID),
    UUID(JacquardServices.rawDataUUID),
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
    var rawDataCharacteristic: Characteristic?
    var successfulNotifyChars = Set<UUID>()
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

//MARK: - PeripheralDelegate events.

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
      peripheral.discoverServices([UUID(JacquardServices.v2Service)])

    // (e3)
    case (.disconnected, .didConnect):
      jqLogger.assert("Failed peripheral identifier guard.")
      state = .error(TagConnectionError.internalError)

    // (e4)
    case (.disconnected, .failedToConnect(_, let error)):
      // Not too worried about disambiguating error state if the peripheral doesn't match since that
      // would be a programmer error.

      if let error = error as NSError?,
        error.domain == CBErrorDomain
          && error.code == CoreBluetoothError.peerRemovedPairingInfo.rawValue
      {
        state = .error(TagConnectionError.peerRemovedPairingInfo)
      } else {
        state = .error(TagConnectionError.bluetoothConnectionError(error))
      }

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
        JacquardServices.v2Characteristics.map { UUID($0) },
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

      var expectedWriteProperties: CharacteristicProperties?
      var expectedProperties: CharacteristicProperties = []

      for characteristic in chars {
        switch characteristic.uuid {
        case JacquardServices.commandUUID:
          expectedWriteProperties = [.write, .writeWithoutResponse]
          context.commandCharacteristic = characteristic
        case JacquardServices.responseUUID:
          expectedProperties = [.notify]
          context.responseCharacteristic = characteristic
        case JacquardServices.notifyUUID:
          expectedProperties = [.notify]
          context.notifyCharacteristic = characteristic
        case JacquardServices.rawDataUUID:
          expectedProperties = [.notify]
          context.rawDataCharacteristic = characteristic
        default:
          // Ignore unexpected characteristics.
          break
        }

        if let writeProperties = expectedWriteProperties {
          // Write property discovered. Validate if any of the characteristic properties
          // writeWithResponse or writeWithoutResponse is present.
          if characteristic.charProperties.intersection(writeProperties).isEmpty {
            jqLogger.error("Unexpected write property for characteristic: \(characteristic)")
            state = .error(TagConnectionError.characteristicDiscoveryError)
            break
          } else {
            // Write property validated.
            expectedWriteProperties = nil
            continue
          }
        } else {
          guard expectedProperties.isSubset(of: characteristic.charProperties) else {
            jqLogger.error("Unexpected properties for characteristic: \(characteristic)")
            state = .error(TagConnectionError.characteristicDiscoveryError)
            break
          }
        }
      }

      state = .awaitingNotificationUpdates
      // / Start Notifications
      for characteristic in chars {
        let uuid = UUID(characteristic.uuid)
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
      context.successfulNotifyChars.union([UUID(characteristic.uuid)]).isSuperset(
        of: TagPairingStateMachine.requiredNotifyingCharacteristics):
      guard let commandCharacteristic = context.commandCharacteristic,
        let responseCharacteristic = context.responseCharacteristic,
        let notifyCharacteristic = context.notifyCharacteristic,
        let rawDataCharacteristic = context.rawDataCharacteristic
      else {
        jqLogger.assert(
          "It shouldn't be possible to be missing any characteristics at transition (t5)")
        state = .error(TagConnectionError.characteristicDiscoveryError)
        return
      }
      jqLogger.info(
        "Discovery completed for \(peripheral.name ?? peripheral.identifier.uuidString)")
      let characteristics = RequiredCharacteristics(
        commandCharacteristic: commandCharacteristic,
        responseCharacteristic: responseCharacteristic,
        notifyCharacteristic: notifyCharacteristic,
        rawDataCharacteristic: rawDataCharacteristic)
      state = .tagPaired(peripheral, characteristics)

    // (t11)
    case (.awaitingNotificationUpdates, .didUpdateNotificationState(let characteristic, _)):
      state = .awaitingNotificationUpdates
      // / Record notifying characteristic.
      context.successfulNotifyChars.insert(UUID(characteristic.uuid))

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
