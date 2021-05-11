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

/// Information about the current state of IMU session download.
public enum IMUSessionDownloadState {

  /// Downloading of session is in progress, contains progress percentage.
  case downloading(Int)

  /// Session has been downloaded, contains downloaded file path.
  case downloaded(URL)
}

/// Metadata for a recorded IMU session.
///
/// All data collected as part of a data collection session can be organized with the following hierarchy:
/// Campaign
///   - Group
///     - Session
///       - Subject (User)
/// A campaign sets the overall goal for a data collection exercise.
/// Campaigns may contain one or more groups which in turn can contain one or more session which may contain one or more subjects.
/// For example, Campaign 1234 consists of motion data gathered while the subject is walking.
/// Data collection for Group 5 under campaign 1234 is recorded at 2pm on July 15 2021 and has 10 subjects/users.
/// Group 5 may carry out multiple Sessions. Therefore, each data collection session needs to be labelled with the
/// campaign identifier, group identifier, session identifier and subject identifier.
public struct IMUSessionInfo: Codable {

  /// Unique indentfier for the IMU recording.
  public let sessionID: String
  /// Identifies the Campaign of a recording session.
  public let campaignID: String
  /// Identifies the group or setting of a recording session.
  public let groupID: String
  /// Product used for recording the IMU Data.
  public let productID: String
  /// Indentfier for the Subject/User performing the motion.
  public let subjectID: String
  // This can be used to validate the size of the downloaded raw file.
  let fsize: UInt32
  // CRC16 (CCITT) of the data file.
  let crc16: UInt32

  init(trial: Google_Jacquard_Protocol_DataCollectionTrialList) {
    self.sessionID = trial.trialID
    self.campaignID = trial.campaignID
    self.groupID = trial.sessionID
    self.productID = trial.productID
    guard let trialData = trial.trialData.first,
      let sensorData = trialData.sensorData.first
    else {
      preconditionFailure("Cannot have a session without trial or sensor data")
    }
    self.subjectID = trialData.subjectID
    self.fsize = sensorData.fsize
    self.crc16 = sensorData.crc16
  }

  init(metadata: Google_Jacquard_Protocol_DataCollectionMetadata) {
    self.sessionID = metadata.trialID
    self.campaignID = metadata.campaignID
    self.groupID = metadata.sessionID
    self.productID = metadata.productID
    self.subjectID = metadata.subjectID
    self.fsize = 0
    self.crc16 = 0
  }
}

/// Provides an interface to perform various operations related to IMU.
public protocol IMUModule {

  /// Configures the tag for IMU data access.
  ///
  /// Before accessing IMU data, the tag must have IMU module loaded and activated.
  /// This method will perform all required steps asynchronously and publish when
  /// completed.
  ///
  /// - Returns: Any publisher with a `Void` Result, indicating that IMUModule activation was
  ///   successful or will publish a `ModuleError` in case of  an error.
  func initialize() -> AnyPublisher<Void, ModuleError>

  /// Activates the module.
  ///
  /// - Returns: Any publisher with a `Void` Result, indicating that IMUModule activation was
  ///   successful or a `ModuleError` in case of  failure.
  func activateModule() -> AnyPublisher<Void, ModuleError>

  /// Deactivates the module.
  ///
  /// - Returns: Any publisher with a `Void` Result, indicating that IMUModule deactivation was
  ///   successful or a `ModuleError` in case of  failure.
  func deactivateModule() -> AnyPublisher<Void, ModuleError>

  /// Starts recording IMU data.
  ///
  /// Parameters cannot be empty,
  /// - Parameters:
  ///   - sessionID: Unique id provided by the client app. Should be non empty & less than 30 characters.
  ///   - campaignID: Identifies the Campaign of a recording session. Should be non empty & less than 30 characters.
  ///   - groupID: Identifies the Group or setting of a recording session. Should be non empty & less than 30 characters.
  ///   - productID: Identifies the Product used for recording the IMU Data. Should be non empty & less than 30 characters.
  ///   - subjectID: Indentfier for the Subject/User performing the motion. Should be non empty & less than 30 characters.
  /// - Returns: Any publisher with a `DataCollectionStatus` Result. Verify status to confirm IMU recording was started
  ///   or return an error if recording could not be started.
  func startRecording(
    sessionID: String,
    campaignID: String,
    groupID: String,
    productID: String,
    subjectID: String
  ) -> AnyPublisher<DataCollectionStatus, Error>

  /// Stops the current IMU recording session.
  ///
  /// - Returns: Any publisher with a `Void` Result, indicating that IMU recording was stopped
  ///   or will publish an error if recording could not be stopped.
  func stopRecording() -> AnyPublisher<Void, Error>

  /// Requests Tag to send IMU sessions.
  ///
  /// - Returns: Any publisher that publishes `IMUSessionInfo` objects available on the tag,
  ///   or will publish an error if List sessions request was not acknowledged by the Tag.
  func listSessions() -> AnyPublisher<IMUSessionInfo, Error>

  /// Deletes a particular session from the device.
  ///
  /// - Parameter session: IMU session to delete.
  /// - Returns: Any publisher with a `Void` Result, indicating that session was erased
  ///   or will publish an error if the session could not be erased from the tag.
  func eraseSession(session: IMUSessionInfo) -> AnyPublisher<Void, Error>

  /// Deletes all sessions from the device.
  ///
  /// - Returns: Any publisher with a `Void` Result, indicating that all sessions were erased
  ///   or will publish an error if the sessions could not be erased from the tag.
  func eraseAllSessions() -> AnyPublisher<Void, Error>

  /// Retrieves data for an IMUSesion.
  ///
  /// - Parameter session: IMU session for which data download will be done.
  /// - Returns: Any publisher with `IMUSesionDownloadState` as Result,
  ///   `IMUSesionDownloadState.downloading` indicates the progress of download.
  ///   `IMUSesionDownloadState.downloaded` contains the URL path of the downloaded file .
  ///   will publish an error if the session data could not be fetched.
  func downloadIMUSessionData(
    session: IMUSessionInfo
  ) -> AnyPublisher<IMUSessionDownloadState, Error>

  /// Will stop the current IMU session downloading.
  ///
  /// - Returns: Any publisher with a `Void` Result, indicating that IMU session download was stopped.
  ///   or will publish an error if downloading could not be stopped.
  func stopDownloading() -> AnyPublisher<Void, Error>

  /// Retrieves data for an IMUSession.
  ///
  /// - Parameter path: File path of the downloaded IMU session file.
  /// - Returns: Any publisher with a `bool` and `IMUSessionData` as Result.
  ///   Bool indicates if file was fully parsed, publisher will publish an error if the session data could not be parsed.
  func parseIMUSession(
    path: URL
  ) -> AnyPublisher<(fullyParsed: Bool, session: IMUSessionData), Error>

  /// Retrieves data for an IMUSession.
  ///
  /// - Parameter session: IMU session to be parsed.
  /// - Returns: Any publisher with a `bool` and `IMUSessionData` as Result.
  ///   Bool indicates if file was fully parsed, publisher will publish an error if the session data could not be parsed.
  func parseIMUSession(
    session: IMUSessionInfo
  ) -> AnyPublisher<(fullyParsed: Bool, session: IMUSessionData), Error>

}
