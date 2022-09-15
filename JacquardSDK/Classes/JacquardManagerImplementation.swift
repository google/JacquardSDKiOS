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

/// Concrete implementation of `JacquardManager`.
///
/// You access the singleton instance via `.shared`.
///
/// See `JacquardManager` for detailed api documentation.
public final class JacquardManagerImplementation: NSObject {

  private enum Constants {
    static let sampleClientKey = "REPLACE_WITH_CLIENT_ID"
    static let sampleAPIKey = "REPLACE_WITH_API_KEY"
  }

  /// The queue used for all callbacks.
  private let userPublishQueue: DispatchQueue
  private var centralStateSubject = CurrentValueSubject<CBManagerState, Never>(.unknown)
  private let advertisingTagsSubject = PassthroughSubject<AdvertisedTag, Never>()
  private var restorePeripheralsHandler: (([UUID]) -> Void)?
  private var targetUjtFirmwareVidPid: VidPidMid?

  /// Necessary configuration which can be used to identify user by clientID and api key.
  private let _sdkConfig: SDKConfig
  private var sdkConfig: SDKConfig {
    if _sdkConfig.clientID.isEmpty || _sdkConfig.clientID == Constants.sampleClientKey {
      jqLogger.warning("Invalid Client Key.")
    }
    if _sdkConfig.apiKey.isEmpty || _sdkConfig.apiKey == Constants.sampleAPIKey {
      jqLogger.error("******************************")
      jqLogger.error("* Invalid API Key.")
      jqLogger.error("* Cloud functions will not work (eg. firmware updating)")
      jqLogger.error("* Information on obtaining an API key is at")
      jqLogger.error("* https://google.github.io/JacquardSDKiOS/cloud-api-terms")
      jqLogger.error("******************************")
    }
    return _sdkConfig
  }

  /// Retains a reference to all actively connection state machine instances, indexed by `CBPeripheral.identifier`.
  static private func retainConnectionStateMachine(
    _ stateMachine: TagConnectionStateMachine, identifier: UUID
  ) {
    connectionStateMachinesAccessLock.lock()
    connectionStateMachinesInternal[identifier] = stateMachine
    connectionStateMachinesAccessLock.unlock()
  }

  static func clearConnectionStateMachine(for identifier: UUID) {
    connectionStateMachinesAccessLock.lock()
    connectionStateMachinesInternal.removeValue(forKey: identifier)
    connectionStateMachinesAccessLock.unlock()
  }

  static func connectionStateMachine(identifier: UUID) -> TagConnectionStateMachine? {
    connectionStateMachinesAccessLock.lock()
    let stateMachine = connectionStateMachinesInternal[identifier]
    connectionStateMachinesAccessLock.unlock()
    return stateMachine
  }

  static private var connectionStateMachinesInternal = [UUID: TagConnectionStateMachine]()
  static private let connectionStateMachinesAccessLock = NSLock()

  public var connectionTimeoutDuration: TimeInterval { 60.0 }

  /// Publishes any found Jacquard tags
  ///
  /// See `JacquardManager.advertisingTags` for api documentation.
  lazy public var advertisingTags =
    advertisingTagsSubject
    .buffer(size: Int.max, prefetch: .byRequest, whenFull: .dropOldest)
    .receive(on: userPublishQueue)
    .eraseToAnyPublisher()

  /// Publishes the current state of the `CBPeripheralManager`.
  ///
  /// See `JacquardManager.centralState` for api documentation.
  lazy public var centralState =
    centralStateSubject
    .buffer(size: Int.max, prefetch: .byRequest, whenFull: .dropOldest)
    .receive(on: userPublishQueue)
    .eraseToAnyPublisher()

  /// Responsible for discovering and connecting/disconnecting peripherals.
  private var centralManager: CentralManager!

  /// Convenience initalizer for JacquardManagerImpementation.
  ///
  /// You should only create one instance of `JacquardManagerImplementation`.
  ///
  /// - Parameters:
  ///   - publishQueue: The dispatch queue on which the events will be dispatched. If `nil`, the main queue will be used.
  ///   - options:  An optional dictionary specifying options (CBCentralManagerOptionRestoreIdentifierKey, CBCentralManagerOptionShowPowerAlertKey) for the central manager.
  ///   - config: Configuration which can be used to identify user by bundleID and api key. See `SDKConfig`
  ///   - restorePeripheralsHandler: Callback with restore peripherals identifier. Peripherals that
  ///                               were connected or pending connection at the time the application
  ///                               was terminated by the system. Using `[UUID]` app can restore
  ///                               these peripherals state.
  public convenience init(
    publishQueue: DispatchQueue = .main,
    options: [String: String]? = nil,
    config: SDKConfig,
    restorePeripheralsHandler: (([UUID]) -> Void)? = nil
  ) {

    // If this initialization is ever moved further away from super.init() reconsider the force
    // unwrap property declaration.
    // Note that if this SDK is used in an app that also talks to other BLE devices this will result
    // in multiple `CBCentralManager`s in the same process. This is ok from iOS 9 onwards
    // (https://developer.apple.com/forums/thread/20810,
    // https://developer.apple.com/library/archive/documentation/NetworkingInternetWeb/Conceptual/CoreBluetooth_concepts/CoreBluetoothBackgroundProcessingForIOSApps/PerformingTasksWhileYourAppIsInTheBackground.html
    // ).

    // Added init support to create `CBCentralManager` using protocol for supporting fake central
    // manager for unit tests.
    self.init(
      publishQueue: publishQueue,
      config: config,
      centralManagerFactory: {
        CentralManagerImplementation(
          delegate: $0,
          publishQueue: publishQueue,
          options: options
        )
      },
      restorePeripheralsHandler: restorePeripheralsHandler
    )
  }

  init(
    publishQueue: DispatchQueue = .main,
    config: SDKConfig,
    centralManagerFactory: (CentralManagerDelegate) -> CentralManager,
    restorePeripheralsHandler: (([UUID]) -> Void)? = nil
  ) {
    userPublishQueue = publishQueue
    self.restorePeripheralsHandler = restorePeripheralsHandler
    _sdkConfig = config
    super.init()
    centralManager = centralManagerFactory(self)
  }
}

extension JacquardManagerImplementation: JacquardManager {

  /// Publishes a value whenever the CoreBluetooth scanning state changes.
  ///
  /// See `JacquardManager.startScanning()` for api documentation.
  public var isScanning: AnyPublisher<Bool, Never> {
    centralManager.isScanning
  }

  /// Starts scanning for connectable Jacquard tags.
  ///
  /// See `JacquardManager.startScanning()` for api documentation.
  public func startScanning(options: [String: Any]? = nil) throws {
    if centralStateSubject.value != .poweredOn {
      throw ManagerScanningError.bluetoothUnavailable(centralStateSubject.value)
    }
    centralManager.scanForPeripherals(
      withServices: [UUID(JacquardServices.v2Service)],
      options: options
    )
  }

  /// Stops scanning for connectable Jacquard tags.
  ///
  /// See `JacquardManager.stopScanning()` for api documentation.
  public func stopScanning() {
    centralManager.stopScan()
  }

  /// :nodoc:
  public func setTargetUjtFirmwareVidPid(_ targetUjtFirmwareVidPid: VidPidMid?) {
    self.targetUjtFirmwareVidPid = targetUjtFirmwareVidPid
  }

  /// Returns any Jacquard tags already connected with the phone.
  ///
  /// See `JacquardManager.preConnectedTags` for api documentation.
  public func preConnectedTags() -> [PreConnectedTag] {
    return
      centralManager
      .retrieveConnectedPeripherals(
        withServices: [UUID(JacquardServices.v2Service)]
      )
      .map { PreConnectedTagModel(peripheral: $0) }
  }

  /// Connects to a connectable tag.
  ///
  /// See `JacquardManager.connect(_ tag:)` for api documentation.
  public func connect(_ tag: ConnectableTag) -> AnyPublisher<TagConnectionState, Error> {
    if let peripheralTag = tag as? TagPeripheralAccess {
      return connect(peripheralTag.peripheral, shouldReconnect: false).mapNeverToError()
    }
    return Fail(error: TagConnectionError.unconnectableTag).eraseToAnyPublisher()
  }

  /// Connects to a known tag identifier.
  ///
  /// See `JacquardManager.connect(_ identifier:)` for api documentation.
  public func connect(_ identifier: UUID) -> AnyPublisher<TagConnectionState, Error> {
    let peripherals = centralManager.retrievePeripherals(withIdentifiers: [identifier])
    guard let peripheral = peripherals.first else {
      return Fail(error: TagConnectionError.bluetoothDeviceNotFound)
        .eraseToAnyPublisher()
    }

    return connect(peripheral).mapNeverToError().eraseToAnyPublisher()
  }

  public func getConnectedTag(for identifier: UUID) -> AnyPublisher<ConnectedTag?, Never> {

    if let connectionState = JacquardManagerImplementation.connectionStateMachine(
      identifier: identifier
    )?.statePublisher {

      return connectionState.flatMap { state -> AnyPublisher<ConnectedTag?, Never> in
        if case .connected(let tag) = state {
          return Just<ConnectedTag?>(tag).eraseToAnyPublisher()
        }
        return Just<ConnectedTag?>(nil).eraseToAnyPublisher()
      }
      .eraseToAnyPublisher()
    } else {
      return Just<ConnectedTag?>(nil).eraseToAnyPublisher()
    }
  }

  private func connect(
    _ peripheral: Peripheral,
    shouldReconnect: Bool = true
  ) -> AnyPublisher<TagConnectionState, Never> {

    let centralManagerConnect: (Peripheral, [String: Any]?) -> Void = { peripheral, options in
      self.centralManager.connect(peripheral, options: options)
    }

    let stateMachine: TagConnectionStateMachine

    // Check if any existing state machine is retained for given peripheral to ignore duplicate
    // connect calls.
    if let connectionStateMachine = JacquardManagerImplementation.connectionStateMachine(
      identifier: peripheral.identifier)
    {
      stateMachine = connectionStateMachine
    } else {
      stateMachine = TagConnectionStateMachine(
        peripheral: peripheral,
        userPublishQueue: userPublishQueue,
        sdkConfig: sdkConfig,
        connectionTimeoutDuration: connectionTimeoutDuration,
        targetUjtFirmwareVidPid: targetUjtFirmwareVidPid,
        connectionMethod: centralManagerConnect
      )

      JacquardManagerImplementation.retainConnectionStateMachine(
        stateMachine, identifier: peripheral.identifier
      )

      stateMachine.connect()
    }

    stateMachine.shouldReconnect = shouldReconnect

    let tagConnectionStream = subscribeTagConnectionStream(
      stateMachine,
      peripheral: peripheral,
      shouldReconnect: shouldReconnect
    )
    return tagConnectionStream
  }

  /// Disconnect a connected tag.
  ///
  /// See `JacquardManager.disconnect(_:)` for api documentation.
  public func disconnect(_ tag: ConnectedTag) -> AnyPublisher<TagConnectionState, Error> {
    return disconnect(tag.identifier)
  }

  /// Disconnect a connected tag.
  ///
  /// See `JacquardManager.disconnect(_:)` for api documentation.
  public func disconnect(_ identifier: UUID) -> AnyPublisher<TagConnectionState, Error> {
    let peripherals = centralManager.retrievePeripherals(withIdentifiers: [identifier])
    guard let peripheral = peripherals.first else {
      return Fail<TagConnectionState, Error>(error: TagConnectionError.bluetoothDeviceNotFound)
        .eraseToAnyPublisher()
    }

    return disconnect(peripheral).mapNeverToError().eraseToAnyPublisher()
  }

  private func disconnect(_ peripheral: Peripheral) -> AnyPublisher<TagConnectionState, Never> {
    let centralManagerDisconnect: (Peripheral, [String: Any]?) -> Void = { peripheral, options in
      self.centralManager.cancelPeripheralConnection(peripheral)
    }
    guard
      let stateMachine = JacquardManagerImplementation.connectionStateMachine(
        identifier: peripheral.identifier
      )
    else {
      jqLogger.preconditionAssertFailure("Failed to get connectionStateMachine instance.")
      return Empty<TagConnectionState, Never>(completeImmediately: true).eraseToAnyPublisher()
    }

    let tagConnectionStream = subscribeTagConnectionStream(stateMachine, peripheral: peripheral)
    stateMachine.disconnect(centralManagerDisconnect)
    return tagConnectionStream
  }

  private func subscribeTagConnectionStream(
    _ stateMachine: TagConnectionStateMachine,
    peripheral: Peripheral,
    shouldReconnect: Bool = true
  ) -> AnyPublisher<TagConnectionState, Never> {
    let tagConnectionStream = stateMachine.statePublisher
      .map { state -> TagConnectionState in
        switch state {
        case .preparingToConnect:
          return .preparingToConnect
        case .connecting(let n, let m):
          return .connecting(n, m)
        case .initializing(let n, let m):
          return .initializing(n, m)
        case .configuring(let n, let m):
          return .configuring(n, m)
        case .firmwareUpdateInitiated:
          return .firmwareUpdateInitiated
        case .firmwareTransferring(let progress):
          return .firmwareTransferring(progress)
        case .firmwareTransferCompleted:
          return .firmwareTransferCompleted
        case .firmwareExecuting:
          return .firmwareExecuting
        case .connected(let tag):
          return .connected(tag)
        case .disconnected(let error):
          if !shouldReconnect,
            let error = error as? TagConnectionError, case .connectionTimeout = error
          {
            // Cancel pending connection request for peripheral when timeout occur.
            self.centralManager.cancelPeripheralConnection(peripheral)
          }
          // Clear state machine from storage when disconnect error encountered.
          if let error = error as? TagConnectionError, case .bluetoothPowerOff = error {
            JacquardManagerImplementation.connectionStateMachinesInternal.removeAll()
          } else {
            JacquardManagerImplementation.clearConnectionStateMachine(for: peripheral.identifier)
          }

          return .disconnected(error)
        }
      }.buffer(size: Int.max, prefetch: .byRequest, whenFull: .dropOldest)
      .receive(on: userPublishQueue)
      .eraseToAnyPublisher()

    return tagConnectionStream
  }
}

/// :nodoc:
extension JacquardManagerImplementation: CentralManagerDelegate {

  /// :nodoc: Conformance to `CentralManagerDelegate` is an implementation detail.
  func centralManagerDidUpdateState(_ state: CBManagerState) {
    centralStateSubject.send(state)
    // Update state machine when Bluetooth state turns to powerOff.
    if state == .poweredOff {
      // Send disconnect event for all stored peripherals.
      for identifier in JacquardManagerImplementation.connectionStateMachinesInternal.keys {
        if let stateMachine = JacquardManagerImplementation.connectionStateMachine(
          identifier: identifier)
        {
          stateMachine.didDisconnect(error: TagConnectionError.bluetoothPowerOff)
        }
      }
    }
  }

  /// :nodoc: Conformance to `CentralManagerDelegate` is an implementation detail.
  func centralManager(
    _ central: CentralManager,
    didDiscover peripheral: Peripheral,
    advertisementData: [String: Any],
    rssi rssiValue: NSNumber
  ) {
    if let tag =
      AdvertisedTagModel(
        peripheral: peripheral,
        advertisementData: advertisementData,
        rssi: rssiValue.floatValue
      )
    {
      advertisingTagsSubject.send(tag)
    }
    // Ignore peripherals we cannot identify. This may happen in apps that also connect to other
    // non-Jacquard BLE peripherals.
  }

  /// :nodoc: Conformance to `CentralManagerDelegate` is an implementation detail.
  func centralManager(_ central: CentralManager, didConnect peripheral: Peripheral) {
    if let stateMachine = JacquardManagerImplementation.connectionStateMachine(
      identifier: peripheral.identifier)
    {
      stateMachine.didConnect(peripheral: peripheral)
    }
    // Ignore didConnect message for peripherals we do not have an active state machine for.
    // This may happen in apps that also connect to other non-Jacquard BLE peripherals.
  }

  /// :nodoc: Conformance to `CentralManagerDelegate` is an implementation detail.
  func centralManager(
    _ central: CentralManager,
    didFailToConnect peripheral: Peripheral,
    error: Error?
  ) {
    if let stateMachine = JacquardManagerImplementation.connectionStateMachine(
      identifier: peripheral.identifier)
    {
      let error = error ?? TagConnectionError.unknownCoreBluetoothError
      stateMachine.didFailToConnect(peripheral: peripheral, error: error)
    }
    // Ignore didFailToConnect message for peripherals we do not have an active state machine for.
    // This may happen in apps that also connect to other non-Jacquard BLE peripherals.
  }

  /// :nodoc: Conformance to `CentralManagerDelegate` is an implementation detail.
  func centralManager(
    _ central: CentralManager,
    didDisconnectPeripheral peripheral: Peripheral,
    error: Error?
  ) {
    if let stateMachine = JacquardManagerImplementation.connectionStateMachine(
      identifier: peripheral.identifier)
    {
      stateMachine.didDisconnect(error: error)
    }
    // Ignore didFailToConnect message for peripherals we do not have an active state machine for.
    // This may happen in apps that also connect to other non-Jacquard BLE peripherals.
  }

  /// :nodoc: Conformance to `CentralManagerDelegate` is an implementation detail.
  func centralManager(_ central: CentralManager, willRestoreState peripherals: [Peripheral]) {
    restorePeripheralsHandler?(peripherals.map { $0.identifier })
  }
}
