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

/// Defines the sampling rate for Accelerometer and Gyroscope sensors of the Tag.
///
/// Using high configuration reduces battery life of the tag.
/// Default configuration is set to low.
public struct IMUSamplingRate {

  /// Low level configuration for sampling rate.
  /// Values for accelerometer: hertz25 & gyroscope: hertz25
  public static let low = IMUSamplingRate(accelerometer: .low, gyroscope: .low)

  /// Mid level configuration for sampling rate.
  /// Values for accelerometer: hertz100 & gyroscope: hertz200
  public static let mid = IMUSamplingRate(accelerometer: .mid, gyroscope: .mid)

  /// High level configuration for sampling rate.
  /// Values for accelerometer: hertz400 & gyroscope: hertz800
  public static let high = IMUSamplingRate(accelerometer: .high, gyroscope: .high)

  let accelerometer: AccelerometerSamplingRate
  let gyroscope: GyroscopeSamplingRate

  /// :nodoc:
  public init(accelerometer: AccelerometerSamplingRate, gyroscope: GyroscopeSamplingRate) {
    self.accelerometer = accelerometer
    self.gyroscope = gyroscope
  }
}

/// Sampling rate for Accelerometer sensor.
public enum AccelerometerSamplingRate {
  /// :nodoc:
  case hertz25

  /// :nodoc:
  case hertz50

  /// :nodoc:
  case hertz78

  /// :nodoc:
  case hertz100

  /// :nodoc:
  case hertz125

  /// :nodoc:
  case hertz156

  /// :nodoc:
  case hertz200

  /// :nodoc:
  case hertz312

  /// :nodoc:
  case hertz400

  /// :nodoc:
  case hertz625

  /// :nodoc:
  case hertz800

  /// :nodoc:
  case hertz1600

  static let low = AccelerometerSamplingRate.hertz25
  static let mid = AccelerometerSamplingRate.hertz100
  static let high = AccelerometerSamplingRate.hertz400
  static let veryHigh = AccelerometerSamplingRate.hertz1600

  var rate: Google_Jacquard_Protocol_ImuAccelSampleRate {
    switch self {
    case .hertz25:
      return .accelOdr25Hz
    case .hertz50:
      return .accelOdr50Hz
    case .hertz78:
      return .accelOdr078Hz
    case .hertz125:
      return .accelOdr125Hz
    case .hertz100:
      return .accelOdr100Hz
    case .hertz156:
      return .accelOdr156Hz
    case .hertz200:
      return .accelOdr200Hz
    case .hertz312:
      return .accelOdr312Hz
    case .hertz400:
      return .accelOdr400Hz
    case .hertz625:
      return .accelOdr625Hz
    case .hertz800:
      return .accelOdr800Hz
    case .hertz1600:
      return .accelOdr1600Hz
    }
  }
}

/// Sampling rate for Gyroscope sensor.
public enum GyroscopeSamplingRate {

  /// :nodoc:
  case hertz25

  /// :nodoc:
  case hertz50

  /// :nodoc:
  case hertz100

  /// :nodoc:
  case hertz200

  /// :nodoc:
  case hertz400

  /// :nodoc:
  case hertz800

  /// :nodoc:
  case hertz1600

  /// :nodoc:
  case hertz3200

  static let low = GyroscopeSamplingRate.hertz25
  static let mid = GyroscopeSamplingRate.hertz200
  static let high = GyroscopeSamplingRate.hertz800
  static let veryHigh = GyroscopeSamplingRate.hertz3200

  var rate: Google_Jacquard_Protocol_ImuGyroSampleRate {
    switch self {
    case .hertz25:
      return .gyroOdr25Hz
    case .hertz50:
      return .gyroOdr50Hz
    case .hertz100:
      return .gyroOdr100Hz
    case .hertz200:
      return .gyroOdr200Hz
    case .hertz400:
      return .gyroOdr400Hz
    case .hertz800:
      return .gyroOdr800Hz
    case .hertz1600:
      return .gyroOdr1600Hz
    case .hertz3200:
      return .gyroOdr3200Hz
    }
  }
}

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

  /// Unique identifier for the IMU recording.
  public let sessionID: String
  /// Identifier the Campaign of a recording session.
  public let campaignID: String
  /// Identifier the group or setting of a recording session.
  public let groupID: String
  /// Product used for recording the IMU Data.
  public let productID: String
  /// Identifier for the Subject/User performing the motion.
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
  ///   - campaignID: Identifier the Campaign of a recording session. Should be non empty & less than 30 characters.
  ///   - groupID: Identifier the Group or setting of a recording session. Should be non empty & less than 30 characters.
  ///   - productID: Identifier the Product used for recording the IMU Data. Should be non empty & less than 30 characters.
  ///   - subjectID: Identifier for the Subject/User performing the motion. Should be non empty & less than 30 characters.
  ///   - samplingRate: Sampling rate for Accelerometer and Gyroscope sensors of the Tag.
  /// - Returns: Any publisher with a `DataCollectionStatus` Result. Verify status to confirm IMU recording was started
  ///   or return an error if recording could not be started.
  func startRecording(
    sessionID: String,
    campaignID: String,
    groupID: String,
    productID: String,
    subjectID: String,
    samplingRate: IMUSamplingRate
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
  func eraseSession(_ session: IMUSessionInfo) -> AnyPublisher<Void, Error>

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
  /// - Parameter at: File path of the downloaded IMU session file.
  /// - Returns: Any publisher with a `bool` and `IMUSessionData` as Result.
  ///   Bool indicates if file was fully parsed, publisher will publish an error if the session data could not be parsed.
  func parseIMUSession(
    at url: URL
  ) -> AnyPublisher<(fullyParsed: Bool, session: IMUSessionData), Error>

  /// Retrieves data for an IMUSession.
  ///
  /// - Parameter session: IMU session to be parsed.
  /// - Returns: Any publisher with a `bool` and `IMUSessionData` as Result.
  ///   Bool indicates if file was fully parsed, publisher will publish an error if the session data could not be parsed.
  func parseIMUSession(
    _ session: IMUSessionInfo
  ) -> AnyPublisher<(fullyParsed: Bool, session: IMUSessionData), Error>

  /// Starts streaming IMU data.
  ///  - Parameter samplingRate: Sampling rate for Accelerometer and Gyroscope sensors of the Tag.

  /// - Returns: Any publisher with a `IMUSample` Result, indicating motion sensor data for the sample from the stream
  ///   or will publish an error if streaming could not be started.
  func startIMUStreaming(samplingRate: IMUSamplingRate) -> AnyPublisher<IMUSample, Error>

  /// Stops the IMU streaming.
  ///
  /// - Returns: Any publisher with a `Void` Result, indicating that IMU streaming was stopped
  ///   or will publish an error if streaming could not be stopped.
  func stopIMUStreaming() -> AnyPublisher<Void, Error>

  /// Provides current data collection mode.
  /// It is valid only if `DataCollectionStatus` is `.logging`. User is responsible to check
  /// the `DataCollectionStatus` and if it is `.logging` then only this API should be called.
  /// It might return an old stored value of mode or an error if config couldn't be fetched.
  ///
  /// - Returns: Any publisher with a `DataCollectionMode` indicating current data collection mode
  ///   or will publish an error if data collection mode could not be retrieved from the saved config.
  func getDataCollectionMode() -> AnyPublisher<DataCollectionMode, Error>

}
