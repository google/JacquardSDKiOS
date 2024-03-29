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

class TagConnectionStateMachine {

  static let initialState: State = .preparingToConnect

  private static let totalProgressSteps = 14

  private let stateSubject = CurrentValueSubject<State, Never>(
    TagConnectionStateMachine.initialState)
  lazy var statePublisher: AnyPublisher<State, Never> = stateSubject.eraseToAnyPublisher()

  private let peripheral: Peripheral
  var context: Context
  private let marshalQueue = DispatchQueue(label: "TagConnectionStateMachine marshaling queue")
  private var observations = [Cancellable]()
  private let sdkConfig: SDKConfig
  private var connectionTimer: DispatchSourceTimer?
  private let connectionTimeoutDuration: TimeInterval

  // if `true`, State machine will retry for tag connection if any error occured.
  var shouldReconnect = true

  /// Delegated access to the connect method on `CBCentralManager`.
  private var connectionMethod: (Peripheral, [String: Any]?) -> Void

  private var state: State = TagConnectionStateMachine.initialState {
    didSet {
      stateSubject.send(state)
    }
  }

  enum State {
    case preparingToConnect
    case connecting(Int, Int)
    case initializing(Int, Int)
    case configuring(Int, Int)
    case connected(ConnectedTag)
    case disconnected(Error?)
    case firmwareUpdateInitiated
    case firmwareTransferring(Float)
    case firmwareTransferCompleted
    case firmwareExecuting

    var isTerminal: Bool {
      switch self {
      case .disconnected: return true
      default: return false
      }
    }
  }

  private enum Event {
    case connectionError(Error)
    case connectionProgress
    case initializationProgress
    case tagPaired(RequiredCharacteristics)
    case tagInitialized(ConnectedTag)
    case tagConfigured(ConnectedTag)
    case didDisconnect(Error?)
    case firmwareUpdateError(Error)
    case firmwareTransferring(Float)
    case firmwareTransferCompleted
    case firmwareExecuting
  }

  struct Context {
    var currentProgress = 0
    /// `TagConnectionStateMachine` uses two internal child state machines. This var provides easy access to these.
    var childStateMachine: ChildStateMachine = .none
    var childStateMachineObservation: Cancellable?
    /// We need to keep a reference to the requested user publish queue to create the ConnectedTag instance with.
    let userPublishQueue: DispatchQueue
    /// `true` when the tag was disconnected by a user call to `disconnect()`.
    var isUserDisconnect = false
    /// Ujt Vid/Pid/Mid detail set from client app.
    let targetUjtFirmwareVidPid: VidPidMid?
  }

  /// `TagConnectionStateMachine` uses two internal child state machines. This type provides easy access to these.
  enum ChildStateMachine {
    case pairing(TagPairingStateMachine)
    case initializing(ProtocolInitializationStateMachine)
    case none

    var pairingStateMachine: TagPairingStateMachine? {
      switch self {
      case .pairing(let fsm): return fsm
      default: return nil
      }
    }
  }

  init(
    peripheral: Peripheral,
    userPublishQueue: DispatchQueue,
    sdkConfig: SDKConfig,
    connectionTimeoutDuration: TimeInterval,
    targetUjtFirmwareVidPid: VidPidMid? = nil,
    connectionMethod: @escaping (Peripheral, [String: Any]?) -> Void
  ) {
    self.peripheral = peripheral
    self.connectionMethod = connectionMethod
    self.sdkConfig = sdkConfig
    self.connectionTimeoutDuration = connectionTimeoutDuration
    self.context = Context(
      userPublishQueue: userPublishQueue, targetUjtFirmwareVidPid: targetUjtFirmwareVidPid)
  }
}

//MARK: - External event methods.

extension TagConnectionStateMachine {

  func connect() {
    jqLogger.debug("Connection timer: \(String(describing: connectionTimer))")

    // Invalidating timer before making connect call to make sure there is no pending timer
    // in execution.
    invalidateConnectionTimer()

    marshalQueue.async {

      self.context.currentProgress = 0
      // Prepare the pairing child state machine.
      let pairingStateMachine = TagPairingStateMachine(peripheral: self.peripheral)
      self.context.childStateMachine = .pairing(pairingStateMachine)

      // Observe pairing state machine state and convert to events on self.
      let observation = pairingStateMachine.statePublisher
        .buffer(size: Int.max, prefetch: .byRequest, whenFull: .dropOldest)
        .receive(on: self.marshalQueue)
        .sink { pairingState in
          switch pairingState {

          case .disconnected:
            if case .preparingToConnect = self.state {
              break
            } else {
              // Unexpected state.
              self.handleEvent(.connectionError(TagConnectionError.internalError))
            }

          case .preparingToConnect, .bluetoothConnected, .servicesDiscovered,
            .awaitingNotificationUpdates:
            self.handleEvent(.connectionProgress)

          case .tagPaired(_, let characteristics):
            self.handleEvent(.tagPaired(characteristics))

          case .error(let error):
            self.handleEvent(.connectionError(error))
          }
        }
      self.context.childStateMachineObservation = observation

      // Start the CoreBluetooth connection.
      self.connectionMethod(self.peripheral, nil)

      self.connectionTimer = DispatchSource.makeTimerSource(queue: self.marshalQueue)
      self.connectionTimer?.setEventHandler { [weak self] in
        guard let self = self else { return }
        jqLogger.debug("Connection timeout with \(String(describing: self.peripheral.name))")
        self.handleEvent(.connectionError(TagConnectionError.connectionTimeout))
      }

      self.connectionTimer?.schedule(
        deadline: DispatchTime.now() + self.connectionTimeoutDuration
      )
      self.connectionTimer?.resume()
    }
  }

  func disconnect(_ disconnectMethod: @escaping (Peripheral, [String: Any]?) -> Void) {
    marshalQueue.async {
      self.context.isUserDisconnect = true
      disconnectMethod(self.peripheral, nil)
    }
  }
}

//MARK: - Internal event methods & helpers.

extension TagConnectionStateMachine {

  func shouldReconnect(for error: Error) -> Bool {

    if let error = error as? TagConnectionError, case .peerRemovedPairingInfo = error {
      // Pairing info is not present on the tag. Hence, reconnection attempts would always fail.
      // Update the `shouldReconnect` flag and propagate the error to the client.
      // In this case, the tag must be forgotten from device BT settings and paired again.
      shouldReconnect = false
    }
    jqLogger.debug("shouldReconnect: \(shouldReconnect) with error: \(error.localizedDescription)")
    return shouldReconnect
  }

  func shouldReconnectForDisconnection(error: Error?) -> Bool {
    return context.isUserDisconnect ? false : true
  }

  private func initializeConnection(characteristics: RequiredCharacteristics) {
    marshalQueue.async {
      // Prepare the pairing child state machine.
      let initializationStateMachine = ProtocolInitializationStateMachine(
        peripheral: self.peripheral,
        characteristics: characteristics,
        userPublishQueue: self.context.userPublishQueue,
        sdkConfig: self.sdkConfig
      )
      self.context.childStateMachine = .initializing(initializationStateMachine)

      // For the fresh tag pairing, the discovery phase timeout error is unrecoverable.
      // Once characteristics and services of tag are successfully discovered, the protocol
      // negotiation phase starts. The timeout error in this phase should be made recoverable.
      // Hence, updating the `shouldReconnect` flag to `true`.
      self.shouldReconnect = true

      // Observe initialization state machine and convert to events on self.
      let observation = initializationStateMachine.statePublisher
        .buffer(size: Int.max, prefetch: .byRequest, whenFull: .dropOldest)
        .receive(on: self.marshalQueue)
        .sink { initializationState in
          switch initializationState {
          case .paired:
            // Initial state.
            break

          case .helloSent, .beginSent, .componentInfoSent, .creatingTagInstance:
            self.handleEvent(.initializationProgress)

          case .tagInitialized(let tag):
            self.context.childStateMachine = .none
            self.handleEvent(.tagInitialized(tag))

          case .error(let error):
            self.handleEvent(.connectionError(error))
          }
        }
      self.context.childStateMachineObservation = observation

      initializationStateMachine.startNegotiation()
    }
  }

  private func configureTag(_ tag: ConnectedTag) {

    let config = Google_Jacquard_Protocol_BleConfiguration.with {
      $0.notifQueueDepth = 14
    }
    let request = UJTConfigWriteCommand(config: config)

    tag.enqueue(request)
      .buffer(size: Int.max, prefetch: .byRequest, whenFull: .dropOldest)
      .receive(on: marshalQueue)
      .sink { completion in
        switch completion {
        case .finished:
          break
        case .failure(let error):
          self.handleEvent(.connectionError(error))
        }
      } receiveValue: { _ in
        self.handleEvent(.tagConfigured(tag))
      }.addTo(&observations)
  }

  private func invalidateConnectionTimer() {
    marshalQueue.async {
      self.connectionTimer?.cancel()
      self.connectionTimer = nil
    }
  }
}

//MARK: - Events to forward to child state machine.

extension TagConnectionStateMachine {

  func didConnect(peripheral: Peripheral) {
    marshalQueue.async {
      guard let pairingStateMachine = self.context.childStateMachine.pairingStateMachine else {
        assertionFailure("Unexpected didConnect method without an active pairing state machine")
        self.handleEvent(.connectionError(TagConnectionError.internalError))
        return
      }
      pairingStateMachine.didConnect(peripheral: peripheral)
    }
  }

  func didDisconnect(error: Error?) {
    marshalQueue.async {
      // Update user disconnect when bluetooth state updated to powerOff.
      if let error = error as? TagConnectionError, case .bluetoothPowerOff = error {
        self.context.isUserDisconnect = true
      }
      self.handleEvent(.didDisconnect(error))
    }
  }

  func didFailToConnect(peripheral: Peripheral, error: Error) {
    marshalQueue.async {
      guard let pairingStateMachine = self.context.childStateMachine.pairingStateMachine else {
        assertionFailure(
          "Unexpected didFailToConnect method without an active pairing state machine")
        self.handleEvent(.connectionError(TagConnectionError.internalError))
        return
      }
      pairingStateMachine.didFailToConnect(peripheral: peripheral, error: error)
    }
  }
}

//MARK: - Firmware update helpers.

extension TagConnectionStateMachine {
  private func checkFirmwareUpdate(_ tag: ConnectedTag) {
    tag.firmwareUpdateManager.checkUpdates(
      vendorID: context.targetUjtFirmwareVidPid?.vid,
      productID: context.targetUjtFirmwareVidPid?.pid,
      forceCheck: true
    )
    .sink { [weak self] completion in
      guard let self = self else { return }
      if case .failure(let error) = completion {
        self.marshalQueue.async {
          self.handleEvent(.firmwareUpdateError(error))
        }
      }
    } receiveValue: { [weak self] updates in
      guard let self = self else { return }
      if let tagUpdate = updates.first(
        where: { tag.tagComponent.vendor.id == $0.vid && tag.tagComponent.product.id == $0.pid }
      ) {
        self.context.userPublishQueue.async {
          self.applyFirmwareUpdate(tagUpdate, tag: tag)
        }
      }
    }.addTo(&observations)
  }

  private func applyFirmwareUpdate(_ update: DFUUpdateInfo, tag: ConnectedTag) {
    tag.firmwareUpdateManager.applyUpdates([update], shouldAutoExecute: true)
      .sink { [weak self] state in
        guard let self = self else { return }
        self.marshalQueue.async {
          switch state {
          case .transferring(let progress):
            self.handleEvent(.firmwareTransferring(progress))
          case .transferred:
            self.handleEvent(.firmwareTransferCompleted)
          case .executing:
            self.handleEvent(.firmwareExecuting)
          case .error(let error):
            self.handleEvent(.firmwareUpdateError(error))
          default: break
          }
        }
      }.addTo(&observations)
  }
}

//MARK: - Transitions.

// Legend of comments that cross reference the Dot Statechart at the end of this file.
// (labels) cross reference individual transitions
// case where clauses represent [guard] statements
// / Actions are labelled with comments in the case bodies.

extension TagConnectionStateMachine {
  /// Examines events and current state to apply transitions.
  private func handleEvent(_ event: Event) {
    dispatchPrecondition(condition: .onQueue(marshalQueue))

    if state.isTerminal {
      jqLogger.error("State machine is already terminal, ignoring event: \(event)")
    }

    jqLogger.debug("Entering \(self).handleEvent(\(state), \(event)")

    switch (state, event) {

    // (t1)
    case (_, .connectionError(let error)) where shouldReconnect(for: error):
      state = .preparingToConnect
      // Ensure we are truly disconnected before trying again.
      connect()

    // (e1)
    case (_, .connectionError(let error)):
      state = .disconnected(error)

    // (t3)
    case (.preparingToConnect, .connectionProgress):
      // The actual connection steps are implemented in the connect() method which sends this
      // event.
      state = .connecting(context.currentProgress, TagConnectionStateMachine.totalProgressSteps)

    // (t4)
    case (.connecting, .connectionProgress):
      context.currentProgress += 1
      state = .connecting(context.currentProgress, TagConnectionStateMachine.totalProgressSteps)

    // (t5)
    case (.connecting, .tagPaired(let characteristics)):
      context.currentProgress += 1
      state = .initializing(context.currentProgress, TagConnectionStateMachine.totalProgressSteps)
      initializeConnection(characteristics: characteristics)

    // (t6)
    case (.initializing, .initializationProgress):
      context.currentProgress += 1
      state = .initializing(context.currentProgress, TagConnectionStateMachine.totalProgressSteps)

    // (t7)
    case (.initializing, .tagInitialized(let tag)):
      context.currentProgress += 1
      state = .configuring(context.currentProgress, TagConnectionStateMachine.totalProgressSteps)
      configureTag(tag)

    // (t8)
    case (.configuring, .tagConfigured(let tag)):
      jqLogger.info("Tag configured: \(tag.name)")
      if let tagVersion = tag.tagComponent.version, Version.badFirmwares.contains(tagVersion) {
        state = .firmwareUpdateInitiated
        checkFirmwareUpdate(tag)
      } else {
        state = .connected(tag)
      }

    case (.firmwareUpdateInitiated, .firmwareTransferring(let progress)),
      (.firmwareTransferring, .firmwareTransferring(let progress)):

      state = .firmwareTransferring(progress)

    case (.firmwareUpdateInitiated, .firmwareTransferCompleted),
      (.firmwareTransferring, .firmwareTransferCompleted):

      state = .firmwareTransferCompleted

    case (.firmwareTransferCompleted, .firmwareExecuting):
      state = .firmwareExecuting

    case (_, .firmwareUpdateError(let error)):
      state = .disconnected(error)

    // (t9)
    case (_, .didDisconnect(let error)) where shouldReconnectForDisconnection(error: error):
      jqLogger.error("Tag reconnecting with error: \(String(describing: error))")
      state = .preparingToConnect
      connect()

    // (t10)
    // `didDisconnect` can be trigger from any phase. i.e. discovering services, characteristics.
    case (_, .didDisconnect(let error)):
      jqLogger.info("User disconnected: \(context.isUserDisconnect)")
      jqLogger.error("Tag disconnected with error: \(String(describing: error))")
      state = .disconnected(error)

    // No valid transition found.
    default:
      jqLogger.error("No transition found for (\(state), \(event))")
      state = .disconnected(TagConnectionError.internalError)
    }

    // Invalidate connection timer if tag is successfully paired or any error occurs.
    switch state {
    case .initializing, .disconnected:
      invalidateConnectionTimer()
    default:
      break
    }
    jqLogger.debug("Exiting \(self).handleEvent() new state: \(state)")
  }
}

//MARK: - Dot Statechart

// Note that the order is important - the transition events/guards will be evaluated in order and
// only the first matching transition will have effect.

// Note that there is no timeout mechanism in this state machine since initial pairing can take
// an infinite amount of time while the tag is out of range or asleep. The pairing and
// initializing state machines will implement appropriate timeouts themselves.

// digraph {
//   node [shape=point] start, complete;
//   node [shape=Mrecord]
//   edge [decorate=1, minlen=2]
//
//   start -> preparingToConnect;
//
//   "*" -> preparingToConnect
//     [label="(t1)
//             connectionError(error)
//             [shouldReconnect(for: error)]
//             / connect()"];
//
//   "*" -> disconnected
//     [ label="(e2) connectionError(error)"]
//
//   preparingToConnect -> connecting
//     [label="(t3)
//             connectionProgress
//             / connect(peripheral)"];
//
//   connecting -> connecting
//     [label="(t4)
//             connectionProgress
//             / incrementProgress()"]
//
//   connecting -> initializing
//     [label="(t5)
//             tagPaired(characteristics)
//             / initializeConnection(peripheral, characteristics)"]
//
//   initializing -> initializing
//     [label="(t6)
//             initializationProgress
//             / incrementProgress()"]
//
//   initializing -> configuring
//     [label="(t7)
//             tagInitialized(connectedTag)
//             / configureTag()"]
//
//   configuring -> firmwareUpdateInitiated
//     [label="(t8)
//             Bad firmware detected
//             checkFirmwareUpdate(tag)
//             & applyFirmwareUpdate(updates, tag)"]
//
//   firmwareUpdateInitiated -> firmwareTransferring
//     [label="(t8.1)
//             firmware transferring"]
//
//   firmwareUpdateInitiated -> disconnected
//     [label="(e8.2)
//             check firmware api error"]
//
//   firmwareTransferring -> firmwareTransferCompleted
//     [label="(t8.3)
//             firmware transfer completed"]
//
//   firmwareTransferring -> disconnected
//     [label="(e8.4)
//             firmware transfer error"]
//
//   firmwareTransferCompleted -> firmwareExecuting
//     [label="(t8.5)
//             firmware Execution in progress"]
//
//   firmwareExecuting -> disconnected
//     [label="(e8.6)
//             firmware execution error"]
//
//   firmwareExecuting -> preparingToConnect
//     [label="(t8.7)
//             didDisconnect(error?)
//             [shouldReconnectForDisconnection(error: error?)]"]
//
//   configuring -> connected
//     [label="(t9)
//             tagConfigured(connectedTag)"]
//
//   connected -> preparingToConnect
//     [label="(t10)
//             didDisconnect(error?)
//             [shouldReconnectForDisconnection(error: error?)]"]
//
//   connected -> disconnected
//     [label="(t11) didDisconnect(_)"]
//
//   disconnected -> complete
// }
