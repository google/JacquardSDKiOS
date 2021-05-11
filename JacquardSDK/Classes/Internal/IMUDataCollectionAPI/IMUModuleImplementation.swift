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

/// Represents the status of data collection.
public enum DataCollectionStatus {
  /// No logging in progress.
  case idle
  /// Session recording in progress.
  case recordingInProgress
  /// Session data transfer in progress.
  case dataTransferInProgress
  /// Erasing session data in progress.
  case erasingData
  /// Not sufficient storage to start logging.
  case lowMemory
  /// Not sufficient battery to start logging.
  case lowBattery
  /// Error state.
  case error

  static func valueFromProto(_ value: Google_Jacquard_Protocol_DataCollectionStatus) -> Self {
    switch value {
    case .dataCollectionIdle: return .idle
    case .dataCollectionLogging: return .recordingInProgress
    case .dataCollectionXferData: return .dataTransferInProgress
    case .dataCollectionErasingData: return .erasingData
    case .dataCollectionLowBattery: return .lowBattery
    case .dataCollectionLowStorage: return .lowMemory
    default: return .error
    }
  }
}

/// Provides implementation of `IMUModule` and helper methods for IMU sessions.
public final class IMUModuleImplementation: IMUModule {

  fileprivate enum Constants {
    static let imuModuleID: Identifier = 1_024_190_291
    static let imuVendorID: Identifier = 293_089_480
    static let imuProductID: Identifier = 4_013_841_288
  }

  private let userPublishQueue: DispatchQueue
  private var tag: ConnectedTag
  private var module: Module?
  private var listSessionObserver: Cancellable?
  private var loadModuleObserver: Cancellable?

  private var currentDownloadingSession: IMUSessionInfo?
  private var fileHandle: FileHandle?

  private var fileDownloadObserver: Cancellable?
  private var observations = [Cancellable]()

  /// Specifies the paths which are being used to manage IMU raw data files.
  private enum RawDataPath {
    static let imuDirectory =
      FileManager.default.temporaryDirectory.appendingPathComponent("IMURawData")

    static func filePath(for session: IMUSessionInfo) -> URL {
      return imuDirectory.appendingPathComponent("Session_\(session.sessionID).bin")
    }
  }

  /// Retrieves the list of sessions.
  ///
  /// - Parameters:
  ///   - publishQueue: The dispatch queue on which the events will be dispatched. If `nil`, the main queue will be used.
  ///   - connectedTag: Tag on which IMU recordings will be done.
  public init(
    publishQueue: DispatchQueue = .main,
    connectedTag: ConnectedTag
  ) {
    userPublishQueue = publishQueue
    tag = connectedTag
    subscribeForTagConnection()
  }

  private func subscribeForTagConnection() {
    JacquardManagerImplementation.connectionStateMachine(
      identifier: tag.identifier
    )?
    .statePublisher
    .map { state -> ConnectedTag? in
      if case .connected(let tag) = state {
        return tag
      }
      return nil
    }
    .removeDuplicates { previousState, currentState in
      // Coalesce duplicate sequence of nil values.
      if previousState == nil && currentState == nil {
        return true
      }
      return false
    }
    .sink { [weak self] optionalTag in
      guard let self = self else { return }
      if let updatedTag = optionalTag {
        // If tag reboots, new tag instane is created.
        // So, update the local tag instance with updated one.
        self.tag = updatedTag
      }
    }.addTo(&observations)
  }

  /// Loads a module on the device if it's not already available and also activates it.
  public func initialize() -> AnyPublisher<Void, ModuleError> {

    if let module = module, module.isEnabled {
      // Module is loaded and activated.
      return Result.Publisher(()).eraseToAnyPublisher()
    }
    return retrieveModules()
      .mapError { _ in return .failedToLoadModule }
      .flatMap({ [weak self] modules -> AnyPublisher<Void, ModuleError> in
        guard let self = self else {
          return Fail<Void, ModuleError>(error: .moduleUnavailable).eraseToAnyPublisher()
        }

        self.module = modules.first { $0.moduleID == Constants.imuModuleID }
        guard let imuModule = self.module else {
          // Module is not available on the tag.
          return self.updateTagAndModule()
        }
        if imuModule.isEnabled {
          // Module is loaded and activated.
          return Result.Publisher(()).eraseToAnyPublisher()
        } else {
          // Module is available but not activated.
          // Send Activate module command.
          return self.activateModule(imuModule: imuModule)
            .mapError { _ in return .failedToActivateModule }
            .flatMap { () -> AnyPublisher<Void, ModuleError> in
              return Result.Publisher(()).eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
        }
      })
      .receive(on: userPublishQueue)
      .eraseToAnyPublisher()
  }

  private func updateTagAndModule() -> AnyPublisher<Void, ModuleError> {

    return tag.firmwareUpdateManager.checkUpdates(forceCheck: true)
      .mapError { _ in return .moduleUnavailable }
      .flatMap({ [weak self] updatesInfo -> AnyPublisher<Void, ModuleError> in
        guard let self = self else {
          return Fail<Void, ModuleError>(error: .moduleUnavailable).eraseToAnyPublisher()
        }

        let tagUpdateInfo = updatesInfo.first {
          $0.vid == self.tag.tagComponent.vendor.id && $0.pid == self.tag.tagComponent.product.id
            && $0.mid == nil
        }

        if let tagUpdateInfo = tagUpdateInfo {

          return self.tag.firmwareUpdateManager.applyUpdates(
            [tagUpdateInfo],
            shouldAutoExecute: true
          )
          .filter { state in
            // Filter out all other `FirmwareUpdateState`s except completed and error states.
            if case .completed = state {
              return true
            } else if case .error = state {
              return true
            }
            return false
          }
          .mapNeverToError()
          .mapError { _ in return .moduleUnavailable }
          .flatMap { state -> AnyPublisher<Void, ModuleError> in
            switch state {
            case .completed:
              return self.updateModule()
            case .error:
              return Fail<Void, ModuleError>(error: .moduleUnavailable).eraseToAnyPublisher()
            default:
              // All other intermediate `FirmwareUpdateState`s are ignored except completed and
              // error(terminal states) above. So, safe to add preconditionFailure here.
              preconditionFailure()
            }
          }
          .receive(on: self.userPublishQueue)
          .eraseToAnyPublisher()
        } else {
          // Tag update is not available or not required. Proceed with module update.
          return self.updateModule()
        }
      })
      .receive(on: userPublishQueue)
      .eraseToAnyPublisher()
  }

  private func updateModule() -> AnyPublisher<Void, ModuleError> {
    let imuModule = Module(
      name: "IMUModule",
      moduleID: Constants.imuModuleID,
      vendorID: Constants.imuVendorID,
      productID: Constants.imuProductID,
      version: nil,
      isEnabled: false)

    return tag.firmwareUpdateManager.checkModuleUpdate(imuModule, forceCheck: true)
      .mapError { _ in return .moduleUnavailable }
      .flatMap({ [weak self] updateInfo -> AnyPublisher<Void, ModuleError> in
        guard let self = self else {
          return Fail<Void, ModuleError>(error: .moduleUnavailable).eraseToAnyPublisher()
        }

        return self.tag.firmwareUpdateManager.applyModuleUpdate(updateInfo)
          .filter { state in
            // Filter out all other `FirmwareUpdateState`s except completed and error states.
            if case .completed = state {
              return true
            } else if case .error = state {
              return true
            }
            return false
          }
          .mapNeverToError()
          .mapError { _ in return .failedToLoadModule }
          .flatMap { state -> AnyPublisher<Void, ModuleError> in
            switch state {
            case .completed:
              return self.initialize()
            case .error:
              return Fail<Void, ModuleError>(error: .failedToLoadModule).eraseToAnyPublisher()
            default:
              // All other intermediate `FirmwareUpdateState`s are ignored except completed and
              // error(terminal states) above. So, safe to add preconditionFailure here.
              preconditionFailure()
            }
          }
          .receive(on: self.userPublishQueue)
          .eraseToAnyPublisher()
      })
      .receive(on: userPublishQueue)
      .eraseToAnyPublisher()
  }

  func retrieveModules() -> AnyPublisher<[Module], Error> {
    // Get all the modules on the device.
    jqLogger.info("Sending List Module command for tag:\(tag.identifier)")
    let listModulesRequest = ListModulesCommand()
    return tag.enqueue(listModulesRequest)
  }

  func activateModule(imuModule: Module) -> AnyPublisher<Void, Error> {
    jqLogger.info("Sending activate module command for module:\(imuModule.moduleID)")
    let activateIMURequest = ActivateModuleCommand(module: imuModule)
    return tag.enqueue(activateIMURequest)
      .flatMap { () -> AnyPublisher<Void, Error> in
        return self.registerForLoadModuleNotification()
      }
      .eraseToAnyPublisher()
  }

  /// Subscribe to LoadModule notification.
  private func registerForLoadModuleNotification()
    -> AnyPublisher<Void, Error>
  {
    let notificationSubject = PassthroughSubject<Void, Error>()
    let sessonNotification = ActivateModuleNotificationSubscription()
    tag.registerSubscriptions { subscribableTag in
      loadModuleObserver = subscribableTag.subscribe(sessonNotification).sink {
        jqLogger.info("Received module loaded notification: \($0)")
        if $0.status == .ok {
          notificationSubject.send()
          notificationSubject.send(completion: .finished)
        } else {
          notificationSubject.send(completion: .failure(ModuleError.failedToLoadModule))
        }
        self.loadModuleObserver?.cancel()
      }
    }
    return notificationSubject.eraseToAnyPublisher()
  }

  func deactivateModule(imuModule: Module) -> AnyPublisher<Void, Error> {
    jqLogger.info("Sending deactivate module command for module:\(imuModule.moduleID)")
    let deactivateIMURequest = DeactivateModuleCommand(module: imuModule)
    return tag.enqueue(deactivateIMURequest)
  }

  public func activateModule() -> AnyPublisher<Void, ModuleError> {

    guard let module = module else {
      return Fail<Void, ModuleError>(error: .moduleUnavailable).eraseToAnyPublisher()
    }
    if module.isEnabled {
      // Module is already activated.
      return Result.Publisher(()).eraseToAnyPublisher()
    } else {
      return activateModule(imuModule: module)
        .mapError { _ in return .failedToActivateModule }
        .flatMap { () -> AnyPublisher<Void, ModuleError> in
          return Result.Publisher(()).eraseToAnyPublisher()
        }
        .eraseToAnyPublisher()
    }
  }

  public func deactivateModule() -> AnyPublisher<Void, ModuleError> {

    guard let module = module else {
      return Fail<Void, ModuleError>(error: .moduleUnavailable).eraseToAnyPublisher()
    }
    return deactivateModule(imuModule: module)
      .mapError { _ in return .failedToDeactivateModule }
      .flatMap { () -> AnyPublisher<Void, ModuleError> in
        return Result.Publisher(()).eraseToAnyPublisher()
      }
      .eraseToAnyPublisher()
  }

  /// Starts recording IMU data.
  public func startRecording(
    sessionID: String,
    campaignID: String = "IMU_Campaign",
    groupID: String = "IMU_Group",
    productID: String = "IMU_Product",
    subjectID: String = "IMU_Subject"
  ) -> AnyPublisher<DataCollectionStatus, Error> {
    // Parameters should me non-empty & maximum length of 30 chars.
    let stringArgs = [sessionID, campaignID, groupID, productID, subjectID]
    let stringArgRange = 1...30

    guard stringArgs.map(\.count).allSatisfy({ stringArgRange.contains($0) }) else {
      return Result.Publisher(ModuleError.invalidParameter).eraseToAnyPublisher()
    }

    let startRecordingRequest = StartIMUSessionCommand(
      sessionID: sessionID,
      campaignID: campaignID,
      groupID: groupID,
      productID: productID,
      subjectID: subjectID
    )
    jqLogger.info("Sending command to Start recording IMU data")
    return tag.enqueue(startRecordingRequest)
      .map { status -> DataCollectionStatus in
        DataCollectionStatus.valueFromProto(status)
      }
      .eraseToAnyPublisher()
  }

  /// Stops the current data collection session.
  public func stopRecording() -> AnyPublisher<Void, Error> {
    jqLogger.info("Sending command to Stop recording IMU data")
    let stopDataCollectionRequest = StopIMUSessionCommand()
    return tag.enqueue(stopDataCollectionRequest)
  }

  /// Provides the current status of  data collection.
  public func checkStatus() -> AnyPublisher<DataCollectionStatus, Error> {
    jqLogger.info("Sending command to check the status of data collection.")
    let statusDCRequest = IMUDataCollectionStatusCommand()
    return tag.enqueue(statusDCRequest)
      .map { status -> DataCollectionStatus in
        DataCollectionStatus.valueFromProto(status)
      }
      .receive(on: userPublishQueue)
      .eraseToAnyPublisher()
  }

  /// Retrieves the list of sessions.
  public func listSessions() -> AnyPublisher<IMUSessionInfo, Error> {
    jqLogger.info("Sending command to get IMU Sessions")
    let listSessionRequest = ListIMUSessionsCommand()
    return tag.enqueue(listSessionRequest)
      .flatMap({ bool -> AnyPublisher<IMUSessionInfo, Error> in
        // Cancel existing observer if any.
        self.listSessionObserver?.cancel()
        // FW api defines that IMUSession notifications will be published only after successful
        // response of List sessions command. So it's safe to subscribe to notifications here.
        return self.registerForIMUSessionNotification()
      })
      .receive(on: userPublishQueue)
      .eraseToAnyPublisher()
  }

  /// Subscribe to ListIMUSession notification.
  private func registerForIMUSessionNotification() -> AnyPublisher<IMUSessionInfo, Error> {
    let notificationSubject = PassthroughSubject<IMUSessionInfo, Error>()
    let sessonNotification = IMUSessionNotificationSubscription()
    tag.registerSubscriptions { subscribableTag in
      listSessionObserver = subscribableTag.subscribe(sessonNotification).sink {
        jqLogger.info("Received IMU session: \($0)")
        notificationSubject.send($0)
      }
    }
    return notificationSubject.eraseToAnyPublisher()
  }
  /// Deletes a particular session from the device.
  public func eraseSession(session: IMUSessionInfo) -> AnyPublisher<Void, Error> {
    jqLogger.info("Sending command to delete IMU session:\(session.sessionID)")
    let eraseSessionRequest = DeleteIMUSessionCommand(session: session)
    return tag.enqueue(eraseSessionRequest)
  }

  /// Deletes all sessions from the device.
  public func eraseAllSessions() -> AnyPublisher<Void, Error> {
    jqLogger.info("Sending command to delete all IMU recordings")
    let eraseAllSessionRequest = DeleteAllIMUSessionsCommand()
    return tag.enqueue(eraseAllSessionRequest)
  }

  /// Will stop any current download in progress.
  public func stopDownloading() -> AnyPublisher<Void, Error> {

    // No download is currently in progress, return success.
    guard currentDownloadingSession != nil else {
      return Result.Publisher(()).eraseToAnyPublisher()
    }

    jqLogger.info("Sending command to Stop recording IMU data for canceling download")
    // Need to send .dataCollectionStop command to stop downloading.
    return stopRecording()
      .flatMap { [weak self] response -> AnyPublisher<Void, Error> in
        self?.cleanupFileDownloadHandling()
        return Result.Publisher(response).eraseToAnyPublisher()
      }.eraseToAnyPublisher()
  }

  /// Retrieves data for an IMUSesion.
  public func downloadIMUSessionData(
    session: IMUSessionInfo
  ) -> AnyPublisher<IMUSessionDownloadState, Error> {

    // If a download is currently in progress, return Error.
    guard currentDownloadingSession == nil else {
      return Fail(error: ModuleError.downloadInProgress).eraseToAnyPublisher()
    }

    // Check if file already exists, if not create one.
    let filePathSizeTuple: (filePath: URL, size: Int)
    do {
      filePathSizeTuple = try createOrRetrieveFile(for: session)
    } catch {
      jqLogger.error("Could not create directory to save RawData file")
      return Fail(error: ModuleError.directoryUnavailable).eraseToAnyPublisher()
    }

    let dataOffset = filePathSizeTuple.size

    // If file is already downloaded 100%, no need to download again. Return file path.
    if dataOffset == session.fsize {
      return Result.Publisher(.downloaded(filePathSizeTuple.filePath)).eraseToAnyPublisher()
    }

    // File is not 100% downloaded, request IMU data from current downloaded size offset.
    // Passing offset will resume the download.
    jqLogger.info("Sending command to retrieve IMUSessionData: offset:\(dataOffset)")
    let sessionDataRequest =
      RetreiveIMUSessionDataCommand(session: session, offset: UInt32(dataOffset))

    // Send command to request IMUSession data file. File is sent over rawData characteristic.
    return tag.enqueue(sessionDataRequest)
      .flatMap({ _ in
        self.subscribeIMUSessionData(session: session, filePathOffset: filePathSizeTuple)
      })
      .eraseToAnyPublisher()
  }

  // Subsribe to raw data channel.
  private func subscribeIMUSessionData(
    session: IMUSessionInfo,
    filePathOffset: (filePath: URL, size: Int)
  ) -> AnyPublisher<IMUSessionDownloadState, Error> {

    currentDownloadingSession = session
    var dataOffset = filePathOffset.size
    let dataDownloadSubject = PassthroughSubject<IMUSessionDownloadState, Error>()
    tag.registerSubscriptions { subscribableTag in
      fileDownloadObserver = subscribableTag.subscribeRawData()
        .sink(receiveValue: { data in
          print("Data packet recieved: \(data)")

          if data.isEmpty {
            jqLogger.error("Received empty data packet for session id: \(session.sessionID).")
            dataDownloadSubject.send(completion: .failure(ModuleError.emptyDataReceived))
            self.cleanupFileDownloadHandling()
          }

          self.fileHandle?.write(data)
          dataOffset = dataOffset + data.count

          jqLogger.info("IMU Data received: \(dataOffset)/\(session.fsize)")

          if dataOffset == session.fsize {
            dataDownloadSubject.send(.downloaded(filePathOffset.filePath))
            dataDownloadSubject.send(completion: .finished)
            self.cleanupFileDownloadHandling(session: session)
          } else if dataOffset < session.fsize {
            let percentage = (dataOffset * 100) / Int(session.fsize)
            dataDownloadSubject.send(.downloading(percentage))
          } else {
            jqLogger.assert("Received extra raw data, this should not happen.")
          }
        })
    }
    return dataDownloadSubject.eraseToAnyPublisher()
  }

  /// Parse downloaded IMU session file.
  public func parseIMUSession(
    path: URL
  ) -> AnyPublisher<(fullyParsed: Bool, session: IMUSessionData), Error> {

    guard let stream = InputStream(url: path) else {
      return Result.Publisher(ModuleError.directoryUnavailable).eraseToAnyPublisher()
    }
    do {
      let parser = try IMUParser(stream)
      let parsedAction = try parser.readAction()

      guard
        let samples = parsedAction?.samples,
        let completed = parsedAction?.completedSuccessfully
      else {
        return Result.Publisher(IMUParsingError.couldNotParseData).eraseToAnyPublisher()
      }

      let imuSessionData = IMUSessionData(metadata: parser.metadata, samples: samples)

      return Result.Publisher((completed, imuSessionData)).eraseToAnyPublisher()
    } catch {
      return Result.Publisher(error).eraseToAnyPublisher()
    }
  }

  /// Will parse the IMU session file if available.
  public func parseIMUSession(
    session: IMUSessionInfo
  ) -> AnyPublisher<(fullyParsed: Bool, session: IMUSessionData), Error> {
    let sessionFile = RawDataPath.filePath(for: session)
    return parseIMUSession(path: sessionFile)
  }
}

// File Manager handling
extension IMUModuleImplementation {
  // Create folder named IMURawData in documents directory.
  private func createIMURawDataFolder() throws {
    if !FileManager.default.fileExists(atPath: RawDataPath.imuDirectory.path) {
      try FileManager.default.createDirectory(
        at: RawDataPath.imuDirectory,
        withIntermediateDirectories: true,
        attributes: nil
      )
    }
  }

  // Creates a .bin file in IMURawData folder and return a tuple containing path and file size.
  private func createOrRetrieveFile(
    for session: IMUSessionInfo
  ) throws -> (filePath: URL, size: Int) {

    try createIMURawDataFolder()
    let sessionFile = RawDataPath.filePath(for: session)
    var dataOffset = 0

    if FileManager.default.fileExists(atPath: sessionFile.path) {
      let fileAttributes = try FileManager.default.attributesOfItem(atPath: sessionFile.path)
      dataOffset = fileAttributes[FileAttributeKey.size] as? Int ?? 0
    } else {
      FileManager.default.createFile(atPath: sessionFile.path, contents: nil, attributes: nil)
    }

    fileHandle = try FileHandle(forWritingTo: sessionFile)
    fileHandle?.seekToEndOfFile()

    return (sessionFile, dataOffset)
  }

  private func cleanupFileDownloadHandling(session: IMUSessionInfo? = nil) {
    try? fileHandle?.close()
    fileHandle = nil
    currentDownloadingSession = nil
    fileDownloadObserver?.cancel()
    // Erase files from tag, that are downloaded.
    if let session = session {
      let _ = eraseSession(session: session)
    }
  }
}
