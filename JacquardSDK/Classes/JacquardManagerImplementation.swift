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

  /// The queue used for all callbacks.
  private let userPublishQueue: DispatchQueue
  private var centralStateSubject = CurrentValueSubject<CBManagerState, Never>(.unknown)
  private let advertisingTagsSubject = PassthroughSubject<AdvertisedTag, Never>()

  /// Retains a reference to all actively connection state machine instances, indexed by `CBPeripheral.identifier`.
  private func retainConnectionStateMachine(
    _ stateMachine: TagConnectionStateMachine, identifier: UUID
  ) {
    connectionStateMachinesAccessLock.lock()
    connectionStateMachinesInternal[identifier] = stateMachine
    connectionStateMachinesAccessLock.unlock()
  }
  private func clearConnectionStateMachine(for identifier: UUID) {
    connectionStateMachinesAccessLock.lock()
    connectionStateMachinesInternal.removeValue(forKey: identifier)
    connectionStateMachinesAccessLock.unlock()
  }
  private func connectionStateMachine(identifier: UUID) -> TagConnectionStateMachine? {
    connectionStateMachinesAccessLock.lock()
    let stateMachine = connectionStateMachinesInternal[identifier]
    connectionStateMachinesAccessLock.unlock()
    return stateMachine
  }
  private var connectionStateMachinesInternal = [UUID: TagConnectionStateMachine]()
  private let connectionStateMachinesAccessLock = NSLock()

  /// Callback if peripheral required to restore its connection with device.
  ///
  /// - Parameter identifier: Peripheral identifier.
  /// - Returns: `true` if user wants to restore peripheral connection otherwise `false`.
  public var shouldRestoreConnection: ((_ identifier: UUID) -> Bool)?

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

  /// `CentralManagerProtocol` responsible for discovering and connecting/disconnecting peripherals.
  private var centralManager: CentralManagerProtocol?

  /// You should only create one instance of `JacquardManagerImplementation`.
  public convenience init(
    publishQueue: DispatchQueue = .main,
    options: [String: String]? = nil
  ) {

    // If this initialization is ever moved further away from super.init() reconsider the force
    // unwrap property declaration.
    // Note that if this SDK is used in an app that also talks to other BLE devices this will result
    // in multiple `CBCentralManager`s in the same process. This is ok from iOS 9 onwards
    // (https://developer.apple.com/forums/thread/20810,
    // https://developer.apple.com/library/archive/documentation/NetworkingInternetWeb/Conceptual/CoreBluetooth_concepts/CoreBluetoothBackgroundProcessingForIOSApps/PerformingTasksWhileYourAppIsInTheBackground.html
    // ).

    self.init(
      publishQueue: publishQueue
    ) { CBCentralManager(delegate: $0, queue: publishQueue, options: options) }
  }

  init(
    publishQueue: DispatchQueue = .main,
    centralManagerFactory: (CBCentralManagerDelegate) -> CentralManagerProtocol
  ) {
    userPublishQueue = publishQueue
    super.init()
    centralManager = centralManagerFactory(self)
  }
}

extension JacquardManagerImplementation: JacquardManager {
  /// Starts scanning for connectable Jacquard tags.
  ///
  /// See `JacquardManager.startScanning()` for api documentation.
  public func startScanning() throws {
    if centralStateSubject.value != .poweredOn {
      throw ManagerScanningError.bluetoothUnavailable(centralStateSubject.value)
    }
    let options: [String: Any] = [CBCentralManagerScanOptionAllowDuplicatesKey: false]
    centralManager?.scanForPeripherals(
      withServices: [JacquardServices.v2Service],
      options: options)
  }

  /// Stops scanning for connectable Jacquard tags.
  ///
  /// See `JacquardManager.stopScanning()` for api documentation.
  public func stopScanning() {
    centralManager?.stopScan()
  }

  /// Returns any Jacquard tags already connected with the phone.
  ///
  /// See `JacquardManager.preConnectedTags` for api documentation.
  public func preConnectedTags() -> [PreConnectedTag] {
    guard let centralManager = centralManager else {
      jqLogger.preconditionAssertFailure("CentralManager must be initialized before use.")
      return []
    }
    return
      centralManager
      .retrieveConnectedPeripherals(withServices: [JacquardServices.v2Service])
      .map { PreConnectedTagModel(peripheral: PeripheralImplementation(peripheral: $0)) }
  }

  /// Connects to a connectable tag.
  ///
  /// See `JacquardManager.connect(_ tag:)` for api documentation.
  public func connect(_ tag: ConnectableTag) -> AnyPublisher<TagConnectionState, Error> {
    if let peripheralTag = tag as? TagPeripheralAccess,
      let peripheral = peripheralTag.peripheral as? PeripheralImplementation
    {
      return connect(peripheral.peripheral).mapNeverToError()
    }
    return Fail(error: TagConnectionError.unconnectableTag).eraseToAnyPublisher()
  }

  /// Connects to a known tag identifier.
  ///
  /// See `JacquardManager.connect(_ identifier:)` for api documentation.
  public func connect(_ identifier: UUID) -> AnyPublisher<TagConnectionState, Error> {
    guard let centralManager = centralManager else {
      jqLogger.preconditionAssertFailure("CentralManager must be initialized before use.")
      return Fail(error: TagConnectionError.internalError)
        .eraseToAnyPublisher()
    }
    let peripherals = centralManager.retrievePeripherals(withIdentifiers: [identifier])
    guard let peripheral = peripherals.first else {
      return Fail(error: TagConnectionError.bluetoothDeviceNotFound)
        .eraseToAnyPublisher()
    }

    return connect(peripheral).mapNeverToError().eraseToAnyPublisher()
  }

  private func connect(_ peripheral: CBPeripheral) -> AnyPublisher<TagConnectionState, Never> {
    let centralManagerConnect: (Peripheral, [String: Any]?) -> Void = { peripheral, options in
      guard let peripheral = peripheral as? PeripheralImplementation else {
        preconditionFailure("Unable to convert peripheral as CBPeripheral.")
      }
      self.centralManager?.connect(peripheral.peripheral, options: options)
    }

    let stateMachine = TagConnectionStateMachine(
      peripheral: PeripheralImplementation(peripheral: peripheral),
      userPublishQueue: userPublishQueue,
      connectionMethod: centralManagerConnect
    )

    retainConnectionStateMachine(stateMachine, identifier: peripheral.identifier)

    let tagConnectionStream = subscribeTagConnectionStream(stateMachine)
    stateMachine.connect()
    return tagConnectionStream
  }

  /// Disconnect a connected tag.
  ///
  /// See `JacquardManager.disconnect(_:)` for api documentation.
  public func disconnect(_ tag: ConnectedTag) -> AnyPublisher<TagConnectionState, Error> {
    guard let centralManager = centralManager else {
      jqLogger.preconditionAssertFailure("CentralManager must be initialized before use.")
      return Fail<TagConnectionState, Error>(error: TagConnectionError.internalError)
        .eraseToAnyPublisher()
    }
    let peripherals = centralManager.retrievePeripherals(withIdentifiers: [tag.identifier])
    guard let peripheral = peripherals.first else {
      return Fail<TagConnectionState, Error>(error: TagConnectionError.bluetoothDeviceNotFound)
        .eraseToAnyPublisher()
    }

    return disconnect(peripheral).mapNeverToError().eraseToAnyPublisher()
  }

  private func disconnect(_ peripheral: CBPeripheral) -> AnyPublisher<TagConnectionState, Never> {
    let centralManagerDisconnect: (Peripheral, [String: Any]?) -> Void = { peripheral, options in
      guard let peripheral = peripheral as? PeripheralImplementation else {
        preconditionFailure("Unable to convert peripheral as CBPeripheral.")
      }
      self.centralManager?.cancelPeripheralConnection(peripheral.peripheral)
    }
    guard let stateMachine = connectionStateMachine(identifier: peripheral.identifier) else {
      preconditionFailure("Failed to get connectionStateMachine instance.")
    }

    let tagConnectionStream = subscribeTagConnectionStream(stateMachine)
    stateMachine.disconnect(centralManagerDisconnect)
    return tagConnectionStream
  }

  private func subscribeTagConnectionStream(
    _ stateMachine: TagConnectionStateMachine
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
        case .connected(let tag):
          return .connected(tag)
        case .disconnected(let error):
          return .disconnected(error)
        }
      }.buffer(size: Int.max, prefetch: .byRequest, whenFull: .dropOldest)
      .receive(on: userPublishQueue)
      .eraseToAnyPublisher()

    return tagConnectionStream
  }
}

/// :nodoc:
extension JacquardManagerImplementation: CBCentralManagerDelegate {

  /// :nodoc: Conformance to `CBCentralManagerDelegate` is an implementation detail.
  public func centralManagerDidUpdateState(_ central: CBCentralManager) {
    centralStateSubject.send(central.state)
  }

  /// :nodoc: Conformance to `CBCentralManagerDelegate` is an implementation detail.
  public func centralManager(
    _ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
    advertisementData: [String: Any], rssi rssiValue: NSNumber
  ) {
    if let tag = AdvertisedTagModel(
      peripheral: PeripheralImplementation(peripheral: peripheral),
      advertisementData: advertisementData
    ) {
      advertisingTagsSubject.send(tag)
    }
    // Ignore peripherals we cannot identify. This may happen in apps that also connect to other
    // non-Jacquard BLE peripherals.
  }

  /// :nodoc: Conformance to `CBCentralManagerDelegate` is an implementation detail.
  public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
    if let stateMachine = connectionStateMachine(identifier: peripheral.identifier) {
      stateMachine.didConnect(peripheral: PeripheralImplementation(peripheral: peripheral))
    }
    // Ignore didConnect message for peripherals we do not have an active state machine for.
    // This may happen in apps that also connect to other non-Jacquard BLE peripherals.
  }

  /// :nodoc: Conformance to `CBCentralManagerDelegate` is an implementation detail.
  public func centralManager(
    _ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?
  ) {
    if let stateMachine = connectionStateMachine(identifier: peripheral.identifier) {
      let error = error ?? TagConnectionError.unknownCoreBluetoothError
      stateMachine.didFailToConnect(
        peripheral: PeripheralImplementation(peripheral: peripheral), error: error
      )
    }
    // Ignore didFailToConnect message for peripherals we do not have an active state machine for.
    // This may happen in apps that also connect to other non-Jacquard BLE peripherals.
  }

  /// :nodoc: Conformance to `CBCentralManagerDelegate` is an implementation detail.
  public func centralManager(
    _ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?
  ) {
    if let stateMachine = connectionStateMachine(identifier: peripheral.identifier) {
      stateMachine.didDisconnect(error: error)
    }
    // Ignore didFailToConnect message for peripherals we do not have an active state machine for.
    // This may happen in apps that also connect to other non-Jacquard BLE peripherals.
  }

  public func centralManager(_ central: CBCentralManager, willRestoreState dict: [String: Any]) {
    jqLogger.debug("willRestoreState for \(dict)")
    guard dict.count >= 1 else {
      jqLogger.warning("No restored connections")
      return
    }

    if let peripherals = dict[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral] {
      for peripheral in peripherals where shouldRestoreConnection?(peripheral.identifier) ?? false {
        let _ = connect(peripheral)
      }
    }
  }
}
