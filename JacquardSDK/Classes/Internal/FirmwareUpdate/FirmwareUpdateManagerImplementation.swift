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
  private var updateStateMachine: FirmwareUpdateStateMachine?

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
      componentVersion: tagVersion.asDecimalEncodedString
    )
    // Create publisher for tag update.
    let tagUpdatePublisher = firmwareUpdateRetriever.checkUpdate(
      request: tagComponentRequest,
      forceCheck: forceCheck
    )
    .prefix(1)

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

  func applyUpdates(
    _ updates: [DFUUpdateInfo],
    shouldAutoExecute: Bool
  ) -> AnyPublisher<FirmwareUpdateState, Never> {

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

  func checkModuleUpdate(
    _ module: Module,
    forceCheck: Bool
  ) -> AnyPublisher<DFUUpdateInfo, FirmwareUpdateError> {

    // Check if tag component is available.
    guard let tagComponent = tag.tagComponent as? ComponentImplementation else {
      // Publish tag connection error.
      jqLogger.assert("Tag component concrete type should be ComponentImplementation.")
      return Fail<DFUUpdateInfo, FirmwareUpdateError>(error: .tagDisconnected).eraseToAnyPublisher()
    }

    guard let version = tagComponent.version else {
      return Fail<DFUUpdateInfo, FirmwareUpdateError>(error: .dataUnavailable).eraseToAnyPublisher()
    }

    let request = FirmwareUpdateRequest(
      component: tagComponent,
      tagVersion: version.asDecimalEncodedString,
      module: module,
      componentVersion: module.version?.asDecimalEncodedString ?? ""
    )

    return firmwareUpdateRetriever.checkUpdate(request: request, forceCheck: forceCheck)
      .map { $0 }
      .mapError { .api($0) }
      .receive(on: userPublishQueue)
      .eraseToAnyPublisher()
  }
}
