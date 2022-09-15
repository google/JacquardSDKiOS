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

import Foundation

/// Command request to retrieve all the modules available in the device.
struct ListIMUSessionsCommand: CommandRequest {

  var request: V2ProtocolCommandRequestIDInjectable {
    var request = Google_Jacquard_Protocol_Request()
    request.domain = .dataCollection
    request.opcode = .dataCollectionTrialList

    let sessionListRequest = Google_Jacquard_Protocol_DataCollectionTrialListRequest()
    request.Google_Jacquard_Protocol_DataCollectionTrialListRequest_trialList = sessionListRequest
    return request
  }

  func parseResponse(outerProto: Any) -> Result<Void, Error> {

    guard let outerProto = outerProto as? Google_Jacquard_Protocol_Response
    else {
      jqLogger.assert(
        "calling parseResponse() with anything other than Google_Jacquard_Protocol_Response is an error"
      )
      return .failure(CommandResponseStatus.errorAppUnknown)
    }
    if outerProto.hasGoogle_Jacquard_Protocol_DataCollectionTrialListResponse_trialList {
      return .success(())
    }
    return .failure(CommandResponseStatus.errorAppUnknown)
  }
}

struct IMUSessionNotificationSubscription: NotificationSubscription {

  func extract(from outerProto: Any) -> IMUSessionInfo? {

    guard let notification = outerProto as? Google_Jacquard_Protocol_Notification else {
      jqLogger.assert(
        "calling extract() with anything other than Google_Jacquard_Protocol_Notification is an error"
      )
      return nil
    }

    // Silently ignore other notifications.
    guard notification.hasGoogle_Jacquard_Protocol_DataCollectionTrialListNotification_trialList
    else {
      return nil
    }

    let trial =
      notification.Google_Jacquard_Protocol_DataCollectionTrialListNotification_trialList.trial
    // If no trials are available, An empty session notification is sent by the tag.
    if trial.hasTrialID {
      let session = IMUSessionInfo(trial: trial)
      return session
    } else {
      return nil
    }
  }
}

/// Command request to start IMU recording.
struct StartIMUSessionCommand: CommandRequest {

  let sessionID: String
  let campaignID: String
  let groupID: String
  let productID: String
  let subjectID: String

  init(
    sessionID: String,
    campaignID: String,
    groupID: String,
    productID: String,
    subjectID: String
  ) {
    self.sessionID = sessionID
    self.campaignID = campaignID
    self.groupID = groupID
    self.productID = productID
    self.subjectID = subjectID
  }

  var request: V2ProtocolCommandRequestIDInjectable {
    var request = Google_Jacquard_Protocol_Request()
    request.domain = .dataCollection
    request.opcode = .dataCollectionStart

    var metaData = Google_Jacquard_Protocol_DataCollectionMetadata()
    metaData.mode = .store
    metaData.campaignID = campaignID
    // The `trialID` is named as `sessionID` for the client app.
    // `groupID` is introduced to replace `sessionID` for any public api's
    metaData.sessionID = groupID
    metaData.trialID = sessionID
    metaData.subjectID = subjectID
    metaData.productID = productID

    var sessionStartRequest = Google_Jacquard_Protocol_DataCollectionStartRequest()
    sessionStartRequest.metadata = metaData

    request.Google_Jacquard_Protocol_DataCollectionStartRequest_start = sessionStartRequest
    return request
  }

  func ignoreResponseErrorChecks() -> Bool { true }

  func parseResponse(outerProto: Any)
    -> Result<Google_Jacquard_Protocol_DataCollectionStatus, Error>
  {
    guard let outerProto = outerProto as? Google_Jacquard_Protocol_Response
    else {
      jqLogger.assert(
        "calling parseResponse() with anything other than Google_Jacquard_Protocol_Response is an error"
      )
      return .failure(CommandResponseStatus.errorAppUnknown)
    }
    if outerProto.hasGoogle_Jacquard_Protocol_DataCollectionStartResponse_start {
      return .success(
        outerProto.Google_Jacquard_Protocol_DataCollectionStartResponse_start.dcStatus)
    }
    return .failure(CommandResponseStatus.errorUnknown)
  }
}

/// Command request to stop IMU recording.
struct StopIMUSessionCommand: CommandRequest {

  var request: V2ProtocolCommandRequestIDInjectable {
    var request = Google_Jacquard_Protocol_Request()
    request.domain = .dataCollection
    request.opcode = .dataCollectionStop

    var sessionStopRequest = Google_Jacquard_Protocol_DataCollectionStopRequest()
    sessionStopRequest.isError = true

    request.Google_Jacquard_Protocol_DataCollectionStopRequest_stop = sessionStopRequest
    return request
  }

  func parseResponse(outerProto: Any) -> Result<Void, Error> {

    guard let outerProto = outerProto as? Google_Jacquard_Protocol_Response else {
      jqLogger.assert(
        "calling parseResponse() with anything other than Google_Jacquard_Protocol_Response is an error"
      )
      return .failure(CommandResponseStatus.errorAppUnknown)
    }
    if outerProto.hasGoogle_Jacquard_Protocol_DataCollectionStopResponse_stop {
      return .success(())
    }
    return .failure(CommandResponseStatus.errorUnknown)
  }
}

/// Command request to get the current status of datacollection.
struct IMUDataCollectionStatusCommand: CommandRequest {

  var request: V2ProtocolCommandRequestIDInjectable {
    var request = Google_Jacquard_Protocol_Request()
    request.domain = .dataCollection
    request.opcode = .dataCollectionStatus

    let dcStatusRequest = Google_Jacquard_Protocol_DataCollectionStatusRequest()

    request.Google_Jacquard_Protocol_DataCollectionStatusRequest_status = dcStatusRequest
    return request
  }

  func parseResponse(
    outerProto: Any
  ) -> Result<Google_Jacquard_Protocol_DataCollectionStatus, Error> {

    guard let outerProto = outerProto as? Google_Jacquard_Protocol_Response
    else {
      jqLogger.assert(
        "calling parseResponse() with anything other than Google_Jacquard_Protocol_Response is an error"
      )
      return .failure(CommandResponseStatus.errorAppUnknown)
    }
    let dcStatus = outerProto.Google_Jacquard_Protocol_DataCollectionStatusResponse_status.dcStatus
    return .success(dcStatus)
  }
}

/// Command request to delete a session on the tag.
struct DeleteIMUSessionCommand: CommandRequest {

  let session: IMUSessionInfo

  init(session: IMUSessionInfo) {
    self.session = session
  }

  var request: V2ProtocolCommandRequestIDInjectable {
    var request = Google_Jacquard_Protocol_Request()
    request.domain = .dataCollection
    request.opcode = .dataCollectionTrialDataErase

    var deleteTrialRequest = Google_Jacquard_Protocol_DataCollectionEraseTrialDataRequest()
    deleteTrialRequest.campaignID = session.campaignID
    deleteTrialRequest.sessionID = session.groupID
    deleteTrialRequest.trialID = session.sessionID
    deleteTrialRequest.productID = session.productID
    deleteTrialRequest.subjectID = session.subjectID
    request.Google_Jacquard_Protocol_DataCollectionEraseTrialDataRequest_eraseTrialData =
      deleteTrialRequest
    return request
  }

  func parseResponse(outerProto: Any) -> Result<Void, Error> {

    guard
      let outerProto = outerProto as? Google_Jacquard_Protocol_Response
    else {
      jqLogger.assert(
        "calling parseResponse() with anything other than Google_Jacquard_Protocol_Response is an error"
      )
      return .failure(CommandResponseStatus.errorAppUnknown)
    }
    if outerProto.hasGoogle_Jacquard_Protocol_DataCollectionEraseTrialDataResponse_eraseTrialData {
      return .success(())
    }
    return .failure(CommandResponseStatus.errorUnknown)
  }
}

/// Command request to delete all sessions on the tag.
struct DeleteAllIMUSessionsCommand: CommandRequest {

  var request: V2ProtocolCommandRequestIDInjectable {
    var request = Google_Jacquard_Protocol_Request()
    request.domain = .dataCollection
    request.opcode = .dataCollectionDataErase

    let deleteAllRequest = Google_Jacquard_Protocol_DataCollectionEraseAllDataRequest()

    request.Google_Jacquard_Protocol_DataCollectionEraseAllDataRequest_eraseAllData =
      deleteAllRequest
    return request
  }

  func parseResponse(outerProto: Any) -> Result<Void, Error> {

    guard let outerProto = outerProto as? Google_Jacquard_Protocol_Response
    else {
      jqLogger.assert(
        "calling parseResponse() with anything other than Google_Jacquard_Protocol_Response is an error"
      )
      return .failure(CommandResponseStatus.errorAppUnknown)
    }
    if outerProto.hasGoogle_Jacquard_Protocol_DataCollectionEraseAllDataResponse_eraseAllData {
      return .success(())
    }
    return .failure(CommandResponseStatus.errorUnknown)
  }
}

/// Command request to retrieve session data.
struct RetreiveIMUSessionDataCommand: CommandRequest {

  let session: IMUSessionInfo
  let offset: UInt32
  init(session: IMUSessionInfo, offset: UInt32) {
    self.session = session
    self.offset = offset
  }

  var request: V2ProtocolCommandRequestIDInjectable {
    var request = Google_Jacquard_Protocol_Request()
    request.domain = .dataCollection
    request.opcode = .dataCollectionTrialData

    var sessionDataRequest = Google_Jacquard_Protocol_DataCollectionTrialDataRequest()
    sessionDataRequest.campaignID = session.campaignID
    sessionDataRequest.sessionID = session.groupID
    sessionDataRequest.trialID = session.sessionID
    sessionDataRequest.productID = session.productID
    sessionDataRequest.subjectID = session.subjectID
    sessionDataRequest.sensorID = 0
    sessionDataRequest.offset = offset

    request.Google_Jacquard_Protocol_DataCollectionTrialDataRequest_trialData = sessionDataRequest
    return request
  }

  func parseResponse(outerProto: Any) -> Result<Void, Error> {

    guard
      let outerProto = outerProto as? Google_Jacquard_Protocol_Response
    else {
      jqLogger.assert(
        "calling parseResponse() with anything other than Google_Jacquard_Protocol_Response is an error"
      )
      return .failure(CommandResponseStatus.errorAppUnknown)
    }
    if outerProto.hasGoogle_Jacquard_Protocol_DataCollectionTrialDataResponse_trialData {
      return .success(())
    }
    return .failure(CommandResponseStatus.errorUnknown)
  }
}

/// Command request to start streaming motion sensor data.
struct StartIMUStreamingCommand: CommandRequest {

  let sessionID: String

  init() {
    self.sessionID = "\(Date().timeIntervalSinceReferenceDate)"
  }

  var request: V2ProtocolCommandRequestIDInjectable {
    var request = Google_Jacquard_Protocol_Request()
    request.domain = .dataCollection
    request.opcode = .dataCollectionStart

    var metadata = Google_Jacquard_Protocol_DataCollectionMetadata()
    metadata.mode = .streaming
    metadata.campaignID = "IMU_Campaign"
    metadata.sessionID = "IMU_Group"
    metadata.trialID = sessionID
    metadata.subjectID = "IMU_Subject"
    metadata.productID = "IMU_Product"
    metadata.sensorIds = [0]
    var startRequest = Google_Jacquard_Protocol_DataCollectionStartRequest()
    startRequest.metadata = metadata

    request.Google_Jacquard_Protocol_DataCollectionStartRequest_start = startRequest
    return request
  }

  func ignoreResponseErrorChecks() -> Bool { true }

  func parseResponse(
    outerProto: Any
  ) -> Result<Google_Jacquard_Protocol_DataCollectionStatus, Error> {

    guard
      let outerProto = outerProto as? Google_Jacquard_Protocol_Response
    else {
      jqLogger.assert(
        "calling parseResponse() with anything other than Google_Jacquard_Protocol_Response is an error"
      )
      return .failure(CommandResponseStatus.errorAppUnknown)
    }

    if outerProto.hasGoogle_Jacquard_Protocol_DataCollectionStartResponse_start {
      return .success(
        outerProto.Google_Jacquard_Protocol_DataCollectionStartResponse_start.dcStatus)
    }
    return .failure(CommandResponseStatus.errorUnknown)
  }
}
