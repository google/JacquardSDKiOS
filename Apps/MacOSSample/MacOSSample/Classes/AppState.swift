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
import JacquardSDK
import SwiftUI

/// Pairs TagConnectionState with the tag's identifier.
struct ConnectionState: Identifiable {
  /// Current connection state for the tag.
  var state: TagConnectionState
  /// Tag's unique identifier.
  var id: UUID

  init(_ pair: (UUID, TagConnectionState)) {
    self.id = pair.0
    self.state = pair.1
  }
}

//TODO: Convert to a protocol so it can be easily faked.

/// Manages app state.
///
/// This object owns the tag connections and provides access to tag connections in a way that's
/// convenient for SwiftUI. It is used throughout the SwiftUI views as the `@EnvironmentObject`
/// (set in `MacOSSampleApp`).
class AppState: ObservableBase {

  private var seenAdvertisingTags = [AdvertisedTag]()
  var advertisingTags: [AdvertisedTag] {
    let connections = Set(connectionStates.map(\.id))
    return seenAdvertisingTags.filter { !connections.contains($0.identifier) }
  }

  /// Observable connection state of every currently active tag.
  private(set) var connectionStates = [ConnectionState]()

  /// Observable property showing whether CoreBluetooth is currently scanning.
  private(set) var isScanning = false

  /// Observable property showing the current CoreBluetoothCentral state.
  private(set) var centralState = CBManagerState.unknown

  /// Publisher version of `isScanning.`
  ///
  /// Direct observation is necessary to manage button disabling.
  private(set) lazy var isScanningPublisher = jqManager.isScanning

  //TODO: remove UUID duplication.
  private var connections = [(UUID, AnyPublisher<(UUID, TagConnectionState), Never>)]() {
    didSet {
      let allStatePublisher = connections.map(\.1).combineLatest()
      connectionStatePublisherPublisher.send(allStatePublisher)
    }
  }
  private var connectionStatePublisherPublisher = PassthroughSubject<
    AnyPublisher<[(UUID, TagConnectionState)], Never>, Never
  >()

  private let jqManager: JacquardManager

  override init() {
    let logger = PrintLogger(
      logLevels: LogLevel.allCases,
      includeSourceDetails: true,
      includeFileLogs: true
    )
    setGlobalJacquardSDKLogger(logger)

    let options = [
      CBCentralManagerOptionRestoreIdentifierKey: "com.google.atap.jacquard.MacOSSample"
    ]

    self.jqManager = JacquardManagerImplementation(
      options: options,
      config: SDKConfig(apiKey: "REPLACE_WITH_API_KEY"))

    super.init()

    // Keep advertising tags up to date.
    let advertisingPubliser = self.jqManager
      .advertisingTags
      .filter { [weak self] tag in
        guard let self = self else { return false }
        return !self.seenAdvertisingTags.contains(where: { existingEntry in
          existingEntry.identifier == tag.identifier
        })
      }.eraseToAnyPublisher()
    bind(advertisingPubliser) { [weak self] in self?.seenAdvertisingTags.append($0) }

    // Observe isScanning.
    bind(self.jqManager.isScanning) { [weak self] in self?.isScanning = $0 }

    // Keep connectionStates up to date.
    let connectionPublisher =
      connectionStatePublisherPublisher
      .flatMap { $0 }
      .map { stateList in
        stateList
          .filter { connectionPair in
            // Disconnected normally only occurs after manual disconnection.
            switch connectionPair.1 {
            case .disconnected: return false
            default: return true
            }
          }.map { ConnectionState($0) }
      }.eraseToAnyPublisher()
    bind(connectionPublisher) { [weak self] in self?.connectionStates = $0 }

    // Keep centralState up to date.
    bind(self.jqManager.centralState) { [weak self] in self?.centralState = $0 }

    // Auto-connect to known tags whenever BLE powers on.
    self.jqManager.centralState
      .map { centralState -> Bool in centralState == .poweredOn }
      .filter { $0 }
      .sink { [weak self] _ in
        guard let self = self else { return }
        for knownTag in Preferences.knownTags {
          self.connect(knownTag.identifier, self.jqManager.connect(knownTag.identifier))
        }
      }.addTo(&observations)
  }

  func startScanning() throws {
    seenAdvertisingTags.removeAll()
    try jqManager.startScanning(options: nil)
  }

  func stopScanning() {
    jqManager.stopScanning()
  }

  func connect(_ tag: AdvertisedTag) {
    Preferences.addKnownTag(tag)
    connect(tag.identifier, jqManager.connect(tag))
  }

  private func connect(_ identifier: UUID, _ connection: AnyPublisher<TagConnectionState, Error>) {
    //TODO: reject duplicates.

    let connectionPair =
      connection
      .catch { error in
        Just(.disconnected(error))
      }
      .map { (identifier, $0) }
      .eraseToAnyPublisher()

    objectWillChange.send()
    connections.append((identifier, connectionPair))
  }

  func disconnect(_ identifier: UUID) {
    let _ = jqManager.disconnect(identifier)
  }
}
