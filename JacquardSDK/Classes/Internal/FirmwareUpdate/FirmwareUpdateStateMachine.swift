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

final class FirmwareUpdateStateMachine {

  private enum Constants {
    static let minimumBatteryDFU = 10
    static let invalidBatteryLevel = -1
  }

  private enum TagConnectionStatus {
    case notConnected
    case partiallyConnectedForFirmwareUpdate
    case connected
  }

  private static let initialState: FirmwareUpdateState = .idle
  private var marshalQueue: DispatchQueue
  private var context: Context
  private var observations = [Cancellable]()
  private var executeNotificationObserver: Cancellable?
  private let userPublishQueue: DispatchQueue
  private var tagConnectionStatus: TagConnectionStatus = .notConnected
  private var batteryLevel = Constants.invalidBatteryLevel

  // To trigger failure if tag doesn't reconnect back or dfuExecute notification is not received
  // after successful execute command.
  private var executionTimer: Timer?
  private let dfuExecutionDuration = 60.0

  private let stateSubject = CurrentValueSubject<FirmwareUpdateState, Never>(
    FirmwareUpdateStateMachine.initialState
  )
  lazy var statePublisher: AnyPublisher<FirmwareUpdateState, Never> =
    stateSubject
    .receive(on: userPublishQueue)
    .eraseToAnyPublisher()

  var state: FirmwareUpdateState = FirmwareUpdateStateMachine.initialState {
    didSet {
      stateSubject.send(state)
      if state.isTerminal {
        stateSubject.send(completion: .finished)
      }
    }
  }

  private enum Event {
    case internalError(String)
    case tagDisconnected
    case lowBattery
    case invalidState(String)
    case dataUnavailable
    case preparingForTransfer
    case transferring(Int)
    case transferred(Int)
    case didReceiveTransferError(Error)
    case startExecution
    case completed
    case didReceiveExecutionError(Error)
    case stopped
  }

  private struct Context {
    let connectedTag: ConnectedTag

    /// Available firmwares update information.
    var updates: [DFUUpdateInfo]

    /// Image writers info.
    var writerStateMachines: [FirmwareImageWriterStateMachine] = []

    /// If `true`, execute command will triggered immediately after transferring all images.
    var shouldAutoExecute: Bool

    /// Total bytes transferred to the tag.
    var totalBytesTransferred = 0

    /// Total bytes count (including all images data).
    var totalBytesToBeTransferred = 0

    var isTagUpdateInProgress = false
  }

  required init(
    userPublishQueue: DispatchQueue = .main,
    updates: [DFUUpdateInfo],
    connectedTag: ConnectedTag,
    shouldAutoExecute: Bool
  ) {
    self.marshalQueue = DispatchQueue(label: "FirmwareUpdateApplyStateMachine marshaling queue")
    self.userPublishQueue = userPublishQueue
    self.context = Context(
      connectedTag: connectedTag,
      updates: updates,
      shouldAutoExecute: shouldAutoExecute
    )
    subscribeForTagConnection()
    connectedTag.registerSubscriptions(self.createSubscriptions)
  }
}

// MARK: - Internal methods.

extension FirmwareUpdateStateMachine {

  private func subscribeForTagConnection() {
    JacquardManagerImplementation.connectionStateMachine(
      identifier: context.connectedTag.identifier
    )?
    .statePublisher
    .map { state -> (tag: ConnectedTag?, badFirmwareUpdateTriggered: Bool) in
      if case .connected(let tag) = state {
        return (tag, false)
      }
      if case .firmwareUpdateInitiated = state {
        return (nil, true)
      }
      return (nil, false)
    }
    .removeDuplicates {
      (
        previous: (tag: ConnectedTag?, badFirmwareUpdateTriggered: Bool),
        current: (tag: ConnectedTag?, badFirmwareUpdateTriggered: Bool)
      ) in

      // Coalesce duplicate sequence of nil values.
      if previous.tag == nil && current.tag == nil {
        if previous.badFirmwareUpdateTriggered == false
          && current.badFirmwareUpdateTriggered == true
        {
          return false
        }
        return true
      }
      return false
    }
    .sink { [weak self] (optionalTag, badFirmwareUpdateTriggered) in
      guard let self = self else { return }
      if optionalTag == nil {
        // Since bad firmware update triggered internally before we return connected tag instance.
        // Hence we need to set connection status to partially connected to bypass tagDisconnected
        // error for the first time to proceed further.
        if badFirmwareUpdateTriggered {
          self.tagConnectionStatus = .partiallyConnectedForFirmwareUpdate
          return
        }
        self.tagConnectionStatus = .notConnected
        // If tag update is in progress, then we need to ignore tag disconnection and wait for tag
        // to reconnect back.
        if !self.context.isTagUpdateInProgress {
          self.marshalQueue.async {
            self.handleEvent(.tagDisconnected)
          }
        }
      } else {
        self.tagConnectionStatus = .connected
        // If tag update is in progress, then on reconnection, we can signal update success.
        if self.context.isTagUpdateInProgress {
          self.marshalQueue.async {
            self.invalidateExecutionTimer()
            self.handleEvent(.completed)
            self.context.isTagUpdateInProgress = false
          }
        }
      }
    }.addTo(&observations)
  }

  // Subscribe to tag notifications.
  private func createSubscriptions(_ tag: SubscribableTag) {
    // Battery notification subscription is needed to get charging state and battery percentages.
    let subscription = BatteryStatusNotificationSubscription()
    tag.subscribe(subscription)
      .sink { [weak self] response in
        guard let self = self else { return }

        self.batteryLevel = Int(response.batteryLevel)
      }.addTo(&self.observations)
  }

  private func fetchBatteryStatus() -> AnyPublisher<UInt32, Error> {
    dispatchPrecondition(condition: .onQueue(marshalQueue))

    // If battery level is available, we dont need to resend request.
    if batteryLevel != Constants.invalidBatteryLevel {
      return Just<UInt32>(UInt32(batteryLevel))
        .setFailureType(to: Error.self)
        .eraseToAnyPublisher()
    }

    // Fetch battery status.
    let batteryRequest = BatteryStatusCommand()
    return context.connectedTag.enqueue(batteryRequest)
      .flatMap { response -> AnyPublisher<UInt32, Error> in
        return Just<UInt32>(response.batteryLevel)
          .setFailureType(to: Error.self)
          .eraseToAnyPublisher()
      }.eraseToAnyPublisher()
  }

  private func validatePreconditionsForTransferImages() -> Bool {

    // Minimum battery should be greater than 10 before start DFU.
    guard self.batteryLevel > Constants.minimumBatteryDFU else {
      self.handleEvent(.lowBattery)
      return false
    }

    // Validate if state machine is in proper state.
    guard case .idle = self.state else {
      self.handleEvent(.invalidState("Incorrect state \(self.state) found. State should be idle."))
      return false
    }

    handleEvent(.preparingForTransfer)

    // Publish failure if image is missing for any component.
    guard !context.updates.isEmpty && !context.updates.contains(where: { $0.image == nil }) else {
      handleEvent(.dataUnavailable)
      return false
    }

    // Reorder the images for update process.
    context.updates = reorderImagesForUpdate(updatableImages: context.updates)

    let updatableImages = context.updates.compactMap {
      updateInfo -> (image: Data, component: Component)? in

      let tagComponent = context.connectedTag.tagComponent
      if tagComponent.vendor.id == updateInfo.vid && tagComponent.product.id == updateInfo.pid {
        // Force unwraping is safe here since we already checked for nil image data above.
        return (updateInfo.image!, tagComponent)
      }

      if let gearComponent = context.connectedTag.gearComponent,
        gearComponent.vendor.id == updateInfo.vid && gearComponent.product.id == updateInfo.pid
      {
        // Force unwraping is safe here since we already checked for nil image data above.
        return (updateInfo.image!, gearComponent)
      }

      return nil
    }

    context.totalBytesToBeTransferred = updatableImages.reduce(0) { $0 + $1.image.count }

    context.writerStateMachines = updatableImages.map {
      FirmwareImageWriterStateMachine(
        image: $0.image,
        tag: context.connectedTag,
        vendorID: $0.component.vendor.id,
        productID: $0.component.product.id,
        componentID: $0.component.componentID
      )
    }

    context.updates.forEach { updateInfo in
      if updateInfo.mid != nil {
        // Force unwraping is safe here since we already checked for nil image data above.
        context.writerStateMachines.append(
          FirmwareImageWriterStateMachine(
            image: updateInfo.image!,
            tag: context.connectedTag,
            vendorID: updateInfo.vid,
            productID: updateInfo.pid,
            componentID: TagConstants.FixedComponent.tag.rawValue
          )
        )
        context.totalBytesToBeTransferred += updateInfo.image!.count
      }
    }

    return true
  }

  private func validatePreconditionsForExecuteImages() -> Bool {
    // Verify tag is connected before execute updates.
    guard tagConnectionStatus != .notConnected else {
      self.handleEvent(.tagDisconnected)
      return false
    }

    // Minimum battery should be greater than 10 before start DFU.
    guard batteryLevel > Constants.minimumBatteryDFU else {
      handleEvent(.lowBattery)
      return false
    }

    guard case .transferred = self.state else {
      handleEvent(
        .invalidState("Incorrect state \(self.state) found. State should be transferred.")
      )
      return false
    }
    return true
  }

  private func calculateProgress(bytesWritten: Int) -> Float {
    return
      Float((context.totalBytesTransferred + bytesWritten) * 100)
      / Float(context.totalBytesToBeTransferred)
  }

  private func transferImage(_ writer: FirmwareImageWriterStateMachine) {
    writer.statePublisher.sink { [weak self, writer] state in
      guard let self = self else { return }

      self.marshalQueue.async {
        switch state {

        case .writing(let bytesWritten):
          self.handleEvent(.transferring(bytesWritten))

        case .complete:
          self.handleEvent(.transferred(writer.totalBytesWritten))

        case .stopped:
          self.handleEvent(.stopped)

        case .error(let error):
          self.handleEvent(.didReceiveTransferError(error))

        default: break
        }
      }
    }.addTo(&self.observations)

    writer.startWriting()
  }

  private func startWriting() {
    if let writer = context.writerStateMachines.first {
      transferImage(writer)
    } else {
      // Transferred all images. If shouldAutoExecute is true, start executing images.
      if context.shouldAutoExecute {
        executeUpdates()
      }
    }
  }

  private func startExecution() {
    if let updateInfo = context.updates.first {
      execute(updateInfo: updateInfo)
    }
  }

  private func execute(updateInfo: DFUUpdateInfo) {
    guard updateInfo.mid == nil else {
      // Update is for module. It does not require execution.
      // Signal update completion.
      handleEvent(.completed)
      return
    }

    // Post error if execution is for gear and component is missing.
    if !isUpdateInfoForTag(updateInfo: updateInfo) && context.connectedTag.gearComponent == nil {
      self.handleEvent(.internalError("Gear component is missing."))
      return
    }

    let executeCommand = DFUExecuteCommand(
      vendorID: ComponentImplementation.convertToDecimal(updateInfo.vid),
      productID: ComponentImplementation.convertToDecimal(updateInfo.pid)
    )
    if !self.isUpdateInfoForTag(updateInfo: updateInfo) && updateInfo.mid == nil {
      // For interposer, need to wait for dfu execute notification to confirm that the image is
      // successfully flashed.
      // Subscribe for dfu execute notification.
      self.context.connectedTag.registerSubscriptions(
        self.createDFUExecuteNotificationSubsctiption
      )
    } else {
      self.context.isTagUpdateInProgress = true
    }
    context.connectedTag.enqueue(executeCommand).sink { [weak self] completion in
      guard let self = self else { return }
      self.marshalQueue.async {
        switch completion {
        case .finished:
          break
        case .failure(let error):
          self.handleEvent(.didReceiveExecutionError(error))
        }
      }
    } receiveValue: {
      jqLogger.info("DFU execute command successfully executed.")
      self.executionTimer = Timer.scheduledTimer(
        timeInterval: self.dfuExecutionDuration,
        target: self,
        selector: #selector(self.signalDFUFailure),
        userInfo: nil,
        repeats: false
      )
    }.addTo(&observations)
  }

  // Order of update is: gear -> tag -> module.
  private func reorderImagesForUpdate(updatableImages: [DFUUpdateInfo]) -> [DFUUpdateInfo] {
    return updatableImages.sorted {

      if $0.mid != nil || $1.mid != nil {
        return $0.mid == nil
      } else {
        let lhs = self.isUpdateInfoForTag(updateInfo: $0)
        let rhs = self.isUpdateInfoForTag(updateInfo: $1)

        return lhs == false && rhs == true
      }
    }
  }

  private func isUpdateInfoForTag(updateInfo: DFUUpdateInfo) -> Bool {
    let tagComponent = context.connectedTag.tagComponent
    if tagComponent.vendor.id == updateInfo.vid && tagComponent.product.id == updateInfo.pid {
      return true
    }
    return false
  }

  private func createDFUExecuteNotificationSubsctiption(_ tag: SubscribableTag) {
    executeNotificationObserver = tag.subscribe(DFUExecuteNotificationSubscription())
      .sink { [weak self] notification in
        guard let self = self else { return }
        self.marshalQueue.async {
          self.invalidateExecutionTimer()

          switch notification.status {
          case .ok:
            jqLogger.info(
              "\(notification.productID) \(notification.vendorID) got flashed OK."
            )
            self.handleEvent(.completed)

          default:
            jqLogger.error(
              "Status \(notification.status) found when trying to execute DFU upgrade."
            )
            let firmwareUpdateError = FirmwareUpdateError.internalError(
              "Status \(notification.status) found when trying to execute DFU upgrade."
            )
            self.handleEvent(.didReceiveExecutionError(firmwareUpdateError))
            return
          }
        }
      }
  }

  @objc private func signalDFUFailure() {
    marshalQueue.async {
      let firmwareUpdateError = FirmwareUpdateError.internalError(
        "Connection timeout: could not re-connect to the component after flashing firmware."
      )
      self.handleEvent(.didReceiveExecutionError(firmwareUpdateError))
    }
  }

  private func invalidateExecutionTimer() {
    executionTimer?.invalidate()
    executionTimer = nil
  }

}

//MARK: - External methods.

extension FirmwareUpdateStateMachine {

  /// Stops the firmware updates if transferring is in progress.
  func stopUpdates() throws {
    switch state {
    case .preparingForTransfer, .transferring(_), .transferred:
      marshalQueue.async {
        do {
          guard let writer = self.context.writerStateMachines.first else {
            throw FirmwareUpdateError.internalError("No DFU transfer is in progress.")
          }
          try writer.stopWriting()
        } catch let error as NSError {
          jqLogger.error("Exception in stopping updates: \(error)")
        }
      }

    default:
      throw FirmwareUpdateError.internalError("Can not stop DFU updates on state `\(state)`.")
    }
  }

  /// Starts the firmware transfer process.
  func applyUpdates() {

    marshalQueue.async { [weak self] in
      guard let self = self else { return }

      // Verify tag is connected before apply updates.
      guard self.tagConnectionStatus != .notConnected else {
        self.handleEvent(.tagDisconnected)
        return
      }

      self.fetchBatteryStatus()
        .sink { completion in
          if case .failure = completion {
            self.marshalQueue.async {
              self.handleEvent(.internalError("Battery status request failed."))
            }
          }
        } receiveValue: { batteryLevel in
          self.batteryLevel = Int(batteryLevel)
          self.marshalQueue.async { [weak self] in
            guard let self = self else { return }

            // Check if update info has any module updates.
            guard self.context.updates.contains(where: { $0.mid != nil }) else {
              jqLogger.debug("No module info found. Proceeding with normal update flow.")
              if self.validatePreconditionsForTransferImages() {
                self.startWriting()
              }
              return
            }

            // List all modules available in tag and check if any module is activated.
            self.retrieveModules(self.context.connectedTag)
              .receive(on: self.marshalQueue)
              .sink { completion in
                if case .failure = completion {
                  self.handleEvent(.internalError("List module request failed."))
                }
              } receiveValue: { [weak self] modules in
                guard let self = self else { return }

                if let activatedModule = modules.first(where: { $0.isEnabled }) {
                  jqLogger.debug("Activated module \(activatedModule.name) found.")
                  // Deactivatation of module is recommended before module transfer (Otherwise
                  // there are chances of module to be corrupted).
                  self.deactivateModule(self.context.connectedTag, module: activatedModule)
                    .receive(on: self.marshalQueue)
                    .sink { completion in
                      if case .failure = completion {
                        let error: Event = .internalError(
                          "Deactivate module \(activatedModule.moduleID) request failed."
                        )
                        self.handleEvent(error)
                      }
                    } receiveValue: {
                      jqLogger.debug("Module deactivated. Proceeding with update flow.")
                      if self.validatePreconditionsForTransferImages() {
                        self.startWriting()
                      }
                    }.addTo(&self.observations)
                } else {
                  jqLogger.debug("No activated module found. Proceeding with update flow.")
                  // If there is no activated module, Transfer all update info.
                  if self.validatePreconditionsForTransferImages() {
                    self.startWriting()
                  }
                }
              }.addTo(&self.observations)
          }
        }.addTo(&self.observations)
    }
  }

  func executeUpdates() {
    marshalQueue.async { [weak self] in
      guard let self = self else { return }

      if self.validatePreconditionsForExecuteImages() {
        self.handleEvent(.startExecution)
      }
    }
  }
}

// MARK: Module command helpers

extension FirmwareUpdateStateMachine {

  func retrieveModules(_ tag: ConnectedTag) -> AnyPublisher<[Module], Error> {
    // Get all the modules on the device.
    jqLogger.debug("Sending List Module command for tag:\(tag.identifier)")
    let listModulesRequest = ListModulesCommand()
    return tag.enqueue(listModulesRequest)
  }

  func deactivateModule(_ tag: ConnectedTag, module: Module) -> AnyPublisher<Void, Error> {
    jqLogger.debug("Sending deactivate module command for module:\(module.moduleID)")
    let deactivateIMURequest = DeactivateModuleCommand(module: module)
    return tag.enqueue(deactivateIMURequest)
  }
}

//MARK: - Transitions.

extension FirmwareUpdateStateMachine {

  /// Examines events and current state to apply transitions.
  private func handleEvent(_ event: Event) {
    dispatchPrecondition(condition: .onQueue(marshalQueue))

    if state.isTerminal {
      jqLogger.info("State machine is already terminal, ignoring event: \(event)")
    }

    jqLogger.debug("Entering \(self).handleEvent(\(state), \(event)")

    switch (state, event) {

    // (e1)
    case (_, .tagDisconnected):
      state = .error(.tagDisconnected)

    // (e2)
    case (_, .internalError(let errorMessage)):
      jqLogger.error(errorMessage)
      state = .error(.internalError(errorMessage))

    // (e3)
    case (_, .lowBattery):
      state = .error(.lowBattery)

    // (e4)
    case (_, .invalidState(let errorMessage)):
      state = .error(.invalidState(errorMessage))

    // (t5)
    case (.idle, .preparingForTransfer):
      state = .preparingForTransfer

    // (e6)
    case (_, .dataUnavailable):
      state = .error(.dataUnavailable)

    // (t7)
    case (.preparingForTransfer, .transferring(let bytesWritten)):
      state = .transferring(calculateProgress(bytesWritten: bytesWritten))

    // (t8)
    case (.transferring(_), .transferring(let bytesWritten)):
      state = .transferring(calculateProgress(bytesWritten: bytesWritten))

    // (t9, t10)
    case (.transferring(_), .transferred(let bytesWritten)),
      (.preparingForTransfer, .transferred(let bytesWritten)):

      context.totalBytesTransferred += bytesWritten
      context.writerStateMachines.removeFirst()
      if context.writerStateMachines.isEmpty {
        // If tag has only module updates, and module update does not require execution so we can
        // directly mark state completed.
        if context.updates.allSatisfy({ $0.mid != nil }) {
          state = .completed
        } else {
          state = .transferred
          startWriting()
        }
      } else {
        startWriting()
      }

    // (e11)
    case (.preparingForTransfer, .didReceiveTransferError(let error)),
      (.transferring(_), .didReceiveTransferError(let error)):
      state = .error(.transfer(error))

    // (t12)
    case (.transferred, .startExecution):
      state = .executing
      startExecution()

    // (t13)
    case (.executing, .completed):
      context.updates.removeFirst()
      if context.updates.isEmpty {
        state = .completed
      } else {
        // Safe to force unwrap here, as the updates array is not empty.
        execute(updateInfo: context.updates.first!)
      }

    // (e14)
    case (.executing, .didReceiveExecutionError(let error)):
      state = .error(.execution(error))

    // (t15)
    case (.preparingForTransfer, .stopped),
      (.transferring(_), .stopped),
      (.transferred, .stopped):
      state = .stopped
      context.writerStateMachines.removeAll()
      context.isTagUpdateInProgress = false

    // No valid transition found.
    default:
      jqLogger.error("No transition found for (\(state), \(event))")
      state = .error(.internalError("No transition found for (\(state), \(event))"))
    }

    if state.isTerminal {
      executeNotificationObserver?.cancel()
      executeNotificationObserver = nil
      invalidateExecutionTimer()
      observations.removeAll()
    }

    jqLogger.debug("Exiting \(self).handleEvent() new state: \(state)")
  }
}

private struct DFUExecuteNotificationSubscription: NotificationSubscription {

  typealias Notification = Google_Jacquard_Protocol_DFUExecuteUpdateNotification

  func extract(from outerProto: Any) -> Google_Jacquard_Protocol_DFUExecuteUpdateNotification? {
    guard let notification = outerProto as? Google_Jacquard_Protocol_Notification else {
      jqLogger.assert(
        "calling extract() with anything other than Google_Jacquard_Protocol_Notification is an error"
      )
      return nil
    }

    // Silently ignore other notifications.
    guard
      notification.hasGoogle_Jacquard_Protocol_DFUExecuteUpdateNotification_dfuExecuteUdpateNotif
    else {
      return nil
    }

    let innerProto =
      notification.Google_Jacquard_Protocol_DFUExecuteUpdateNotification_dfuExecuteUdpateNotif
    return innerProto
  }

}

//MARK: - Dot Statechart

// Note that the order is important - the transition events/guards will be evaluated in order and
// only the first matching transition will have effect.

//digraph G {
//
//    "start" -> "idle"
//
//    "_" -> "error"
//    [label = "(e1)
//              tagDisconnected"];
//
//    "_" -> "error"
//    [label = "(e2)
//              internalError"];
//
//    "_" -> "error"
//    [label = "(e3)
//              lowBattery"];
//
//    "_" -> "error"
//    [label = "(e4)
//              invalidState"];
//
//    "idle" -> "preparingForTransfer"
//    [label = "(t5)
//              Checking preconditions"];
//
//    "_" -> "error"
//    [label = "(e6)
//              dataUnavailable"];
//
//    "preparingForTransfer" -> "transferring"
//    [label = "(t7)
//              calculateProgress
//              / transferring progress"];
//
//    "transferring" -> "transferring"
//    [label = "(t8)
//              calculateProgress
//              / transferring progress"];
//
//    "transferring" -> "transferred"
//    [label = "(t9)
//              Check for more images to transfer
//              / If shouldAutoExecute is true, start execution of transferred images
//              / Otherwise changed state to transferred"];
//
//    "preparingForTransfer" -> "transferred"
//    [label = "(t10)
//              Check for more images to transfer
//              / If shouldAutoExecute is true, start execution of transferred images
//              / Otherwise changed state to transferred"];
//
//    "transferred" -> "executing"
//    [label = "(t11)
//              executing
//              / startExecution()"];
//
//    "executing" -> "completed"
//    [label = "(t12)
//              Check for more images to execute
//              / If present, start execution of the next image
//              / Otherwise changed state to completed"];
//
//    "transferring" -> "error"
//    [label = "(e13)
//              didReceiveTransferError(error)"];
//
//    "executing" -> "error"
//    [label = "(e14)
//              didReceiveExecutionError(error)"];
//
//    "preparingForTransfer" -> "stopped"
//    [label = "(t15)
//              Update interrupted by user
//              / stopped"];
//
//    "transferring" -> "stopped"
//    [label = "(t16)
//              Update interrupted by user
//              / stopped"];
//
//    "transferred" -> "stopped"
//    [label = "(t17)
//              Update interrupted by user
//              / stopped"];
//
//    "completed" -> "end"
//    "stopped" -> "end"
//
//    error [color=red style=filled]
//    start [shape=diamond]
//    end [shape=diamond]
//}
