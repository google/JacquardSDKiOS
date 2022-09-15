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

final class FirmwareUpdateManagerImplementation: FirmwareUpdateManager {

  private var observers = [Cancellable]()
  private let userPublishQueue: DispatchQueue
  private let firmwareUpdateRetriever: FirmwareUpdateRetriever
  private let tag: ConnectedTag

  private var updateStateMachine: FirmwareUpdateStateMachine? {
    didSet {
      if let updateStateMachine = updateStateMachine {
        stateMachineSubject.send(updateStateMachine)
      }
    }
  }

  lazy private var stateMachineSubject =
    CurrentValueSubject<FirmwareUpdateStateMachine?, Never>(nil)

  var state: AnyPublisher<FirmwareUpdateState, Never> {
    return
      stateMachineSubject
      // If firmware update is not started yet or terminated, state should be idle by default.
      .flatMap { stateMachine -> AnyPublisher<FirmwareUpdateState, Never> in
        guard let stateMachine = stateMachine, !stateMachine.state.isTerminal else {
          return Just<FirmwareUpdateState>(.idle).eraseToAnyPublisher()
        }
        return stateMachine.statePublisher
      }
      .receive(on: userPublishQueue)
      .eraseToAnyPublisher()
  }

  private var isUpdateInProgress: Bool {
    if let stateMachine = updateStateMachine {
      return !stateMachine.state.isTerminal
    }
    return false
  }

  init(
    publishQueue: DispatchQueue = .main,
    firmwareUpdateRetriever: FirmwareUpdateRetriever,
    connectedTag: ConnectedTag
  ) {
    userPublishQueue = publishQueue
    self.firmwareUpdateRetriever = firmwareUpdateRetriever
    tag = connectedTag
  }

  func checkUpdates(
    vendorID: String?,
    productID: String?,
    forceCheck: Bool = false
  ) -> AnyPublisher<[DFUUpdateInfo], FirmwareUpdateError> {

    // Check if tag component is available.
    guard let tagComponent = tag.tagComponent as? ComponentImplementation else {
      jqLogger.assert("Tag component concrete type should be ComponentImplementation.")
      // Publish tag connection error.
      return
        Fail<[DFUUpdateInfo], FirmwareUpdateError>(error: .tagDisconnected).eraseToAnyPublisher()
    }

    guard let tagVersion = tagComponent.version else {
      return Fail<[DFUUpdateInfo], FirmwareUpdateError>(error: .dataUnavailable)
        .eraseToAnyPublisher()
    }

    let tagComponentRequest = FirmwareUpdateRequest(
      component: tagComponent,
      tagVersion: tagVersion.asDecimalEncodedString,
      module: nil,
      componentVersion: tagVersion.asDecimalEncodedString,
      vendorID: vendorID,
      productID: productID
    )
    // Create publisher for tag update.
    let tagUpdatePublisher = firmwareUpdateRetriever.checkUpdate(
      request: tagComponentRequest,
      forceCheck: forceCheck
    )
    .prefix(1)
    .map {
      DFUUpdateInfo(
        date: $0.date,
        version: Version.version(fromDecimalEncodedString: $0.version).description,
        dfuStatus: $0.dfuStatus,
        vid: self.tag.tagComponent.vendor.id,
        pid: self.tag.tagComponent.product.id,
        mid: nil,
        downloadURL: $0.downloadURL,
        image: $0.image
      )
    }

    // Check if gear component is available.
    guard let gearComponent = tag.gearComponent as? ComponentImplementation else {
      return
        tagUpdatePublisher
        .collect()
        .mapError { .api($0) }
        .receive(on: userPublishQueue)
        .eraseToAnyPublisher()
    }
    // Create publisher for gear update.
    let gearComponentRequest = FirmwareUpdateRequest(
      component: gearComponent,
      tagVersion: tagVersion.asDecimalEncodedString,
      module: nil,
      componentVersion: gearComponent.version?.asDecimalEncodedString
    )
    let interposerUpdatePublisher = self.firmwareUpdateRetriever.checkUpdate(
      request: gearComponentRequest,
      forceCheck: forceCheck
    )
    .prefix(1)

    // Merge tag & interposer publishers AnyPublisher<DFUUpdateInfo, ...> and collect them as
    // array AnyPublisher<[DFUUpdateInfo], ..>
    return
      tagUpdatePublisher
      .merge(with: interposerUpdatePublisher)
      .collect()
      .mapError { .api($0) }
      .receive(on: userPublishQueue)
      .eraseToAnyPublisher()
  }

  func stopUpdates() throws {
    guard isUpdateInProgress, let stateMachine = updateStateMachine else {
      throw FirmwareUpdateError.internalError("DFU updates are not in progress.")
    }
    do {
      try stateMachine.stopUpdates()
    } catch let error as NSError {
      throw FirmwareUpdateError.internalError("Error `\(error)` in stopping the DFU updates.")
    }
  }

  func applyUpdates(
    _ updates: [DFUUpdateInfo],
    shouldAutoExecute: Bool
  ) -> AnyPublisher<FirmwareUpdateState, Never> {

    guard !isUpdateInProgress else {
      var message = "Unknown state found. State should be idle."
      if let stateMachine = updateStateMachine {
        message = "Incorrect state \(stateMachine.state) found. State should be idle."
      }
      jqLogger.info("Apply firmware updates called while update is in progress.")
      return Result.Publisher((.error(.invalidState(message)))).eraseToAnyPublisher()
    }

    let updateStateMachine = FirmwareUpdateStateMachine(
      userPublishQueue: userPublishQueue,
      updates: updates,
      connectedTag: tag,
      shouldAutoExecute: shouldAutoExecute
    )
    updateStateMachine.applyUpdates()
    self.updateStateMachine = updateStateMachine

    return
      updateStateMachine.statePublisher
      .buffer(size: Int.max, prefetch: .byRequest, whenFull: .dropOldest)
      .receive(on: userPublishQueue)
      .eraseToAnyPublisher()
  }

  func executeUpdates() {
    updateStateMachine?.executeUpdates()
  }

  func checkModuleUpdates(_ modules: [Module], forceCheck: Bool) -> DFUUpdatePublisher {

    jqLogger.debug("Check updates for modules: \(modules)")

    // Check if tag component is available.
    guard let tagComponent = tag.tagComponent as? ComponentImplementation else {
      // Publish tag connection error.
      jqLogger.assert("Tag component concrete type should be ComponentImplementation.")
      return Fail<[Result<DFUUpdateInfo, APIError>], FirmwareUpdateError>(
        error: .tagDisconnected
      ).eraseToAnyPublisher()
    }

    guard let version = tagComponent.version else {
      jqLogger.debug("Tag component version detail is missing.")
      return Fail<[Result<DFUUpdateInfo, APIError>], FirmwareUpdateError>(
        error: .dataUnavailable
      ).eraseToAnyPublisher()
    }

    if modules.isEmpty {
      jqLogger.debug("Empty module list provided.")
      return Result.Publisher(([])).eraseToAnyPublisher()
    }

    var publishers = [AnyPublisher<DFUUpdateInfo, APIError>]()
    for module in modules {
      let request = FirmwareUpdateRequest(
        component: tagComponent,
        tagVersion: version.asDecimalEncodedString,
        module: module,
        componentVersion: module.version?.asDecimalEncodedString ?? ""
      )

      let checkUpdatePublisher = firmwareUpdateRetriever.checkUpdate(
        request: request,
        forceCheck: forceCheck
      )
      .receive(on: userPublishQueue)
      .eraseToAnyPublisher()

      publishers.append(checkUpdatePublisher)
    }

    let dfuPublishers = publishers.map {
      $0
        .map { Result<DFUUpdateInfo, APIError>.success($0) }
        .catch {
          Just<Result<DFUUpdateInfo, APIError>>(.failure($0))
            .setFailureType(to: FirmwareUpdateError.self)
        }
        .eraseToAnyPublisher()
    }

    return Publishers.MergeMany(dfuPublishers)
      .collect()
      .receive(on: userPublishQueue)
      .eraseToAnyPublisher()
  }

  func checkModuleUpdates(forceCheck: Bool) -> DFUUpdatePublisher {
    return retrieveModules(tag)
      .mapError { _ in .moduleUnavailable }
      .flatMap { modules -> DFUUpdatePublisher in
        self.checkModuleUpdates(modules, forceCheck: forceCheck)
      }
      .receive(on: userPublishQueue)
      .eraseToAnyPublisher()
  }
}

// MARK: Module command helpers

extension FirmwareUpdateManagerImplementation {

  func retrieveModules(_ tag: ConnectedTag) -> AnyPublisher<[Module], Error> {
    // Get all the modules on the device.
    jqLogger.debug("Sending List Module command for tag:\(tag.identifier)")
    let listModulesRequest = ListModulesCommand()
    return tag.enqueue(listModulesRequest)
  }
}
