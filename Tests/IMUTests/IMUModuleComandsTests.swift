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

import XCTest

@testable import JacquardSDK

class IMUModuleComandsTests: XCTestCase {

  struct CatchLogger: Logger {
    func log(level: LogLevel, file: String, line: Int, function: String, message: () -> String) {
      let _ = message()
      if level == .assertion {
        expectation.fulfill()
      }
    }

    var expectation: XCTestExpectation
  }

  override func setUp() {
    super.setUp()

    let logger = PrintLogger(
      logLevels: [.debug, .info, .warning, .error, .assertion, .preconditionFailure],
      includeSourceDetails: true
    )
    setGlobalJacquardSDKLogger(logger)
  }

  override func tearDown() {
    // Other tests may run in the same process. Ensure that any fake logger fulfillment doesn't
    // cause any assertions later.
    JacquardSDK.setGlobalJacquardSDKLogger(JacquardSDK.createDefaultLogger())

    super.tearDown()
  }

  func verifyBadProtoResponse<T: CommandRequest>(_ command: T) {
    let badResponseExpectation = expectation(description: "badResponseExpectation")
    let badResponse = Google_Jacquard_Protocol_Color()
    jqLogger = CatchLogger(expectation: badResponseExpectation)
    command.parseResponse(outerProto: badResponse).assertFailure()
    wait(for: [badResponseExpectation], timeout: 1)
  }

  func testListSessionsCommand() {
    let command = ListIMUSessionsCommand()

    guard let request = command.request as? Google_Jacquard_Protocol_Request else {
      XCTFail("Request type should be Jacquard Protocol Request")
      return
    }
    XCTAssertNotNil(command)
    XCTAssertEqual(request.domain, .dataCollection)
    XCTAssertEqual(request.opcode, .dataCollectionTrialList)

    let listSessionResponse = Google_Jacquard_Protocol_Response.with {
      let listResponse = Google_Jacquard_Protocol_DataCollectionTrialListResponse.with {
        $0.dcStatus = .dataCollectionXferData
      }
      $0.Google_Jacquard_Protocol_DataCollectionTrialListResponse_trialList = listResponse
    }

    command.parseResponse(outerProto: listSessionResponse).assertSuccess()
    verifyBadProtoResponse(command)
  }

  func testStartIMUSessionCommand() {
    let command = StartIMUSessionCommand(
      sessionID: "sessionID",
      campaignID: "campaignID",
      groupID: "groupID",
      productID: "productID",
      subjectID: "subjectID")
    XCTAssertNotNil(command)

    guard let request = command.request as? Google_Jacquard_Protocol_Request else {
      XCTFail("Request type should be Jacquard Protocol Request")
      return
    }
    XCTAssertEqual(request.domain, .dataCollection)
    XCTAssertEqual(request.opcode, .dataCollectionStart)

    let start = request.Google_Jacquard_Protocol_DataCollectionStartRequest_start
    XCTAssertEqual(start.metadata.campaignID, command.campaignID)
    XCTAssertEqual(start.metadata.sessionID, command.groupID)

    let startResponse = Google_Jacquard_Protocol_Response.with {
      let start = Google_Jacquard_Protocol_DataCollectionStartResponse.with {
        $0.dcStatus = .dataCollectionLogging
      }
      $0.Google_Jacquard_Protocol_DataCollectionStartResponse_start = start
    }

    command.parseResponse(outerProto: startResponse).assertSuccess { result in
      XCTAssertEqual(result, .dataCollectionLogging)
    }
    verifyBadProtoResponse(command)
  }

  func testStopIMUSessionCommand() {
    let command = StopIMUSessionCommand()
    XCTAssertNotNil(command)

    guard let request = command.request as? Google_Jacquard_Protocol_Request else {
      XCTFail("Request type should be Jacquard Protocol Request")
      return
    }
    XCTAssertEqual(request.domain, .dataCollection)
    XCTAssertEqual(request.opcode, .dataCollectionStop)

    let response = Google_Jacquard_Protocol_Response.with {
      let stop = Google_Jacquard_Protocol_DataCollectionStopResponse.with {
        $0.dcStatus = .dataCollectionIdle
      }
      $0.Google_Jacquard_Protocol_DataCollectionStopResponse_stop = stop
    }

    command.parseResponse(outerProto: response).assertSuccess()
    verifyBadProtoResponse(command)
  }

  func testIMUDataCollectionStatusCommand() {
    let command = IMUDataCollectionStatusCommand()
    XCTAssertNotNil(command)

    guard let request = command.request as? Google_Jacquard_Protocol_Request else {
      XCTFail("Request type should be Jacquard Protocol Request")
      return
    }
    XCTAssertEqual(request.domain, .dataCollection)
    XCTAssertEqual(request.opcode, .dataCollectionStatus)

    let response = Google_Jacquard_Protocol_Response.with {
      let status = Google_Jacquard_Protocol_DataCollectionStatusResponse.with {
        $0.dcStatus = .dataCollectionIdle
      }
      $0.Google_Jacquard_Protocol_DataCollectionStatusResponse_status = status
    }

    command.parseResponse(outerProto: response).assertSuccess { result in
      XCTAssertEqual(result, .dataCollectionIdle)
    }
    verifyBadProtoResponse(command)
  }

  func testDeleteIMUSessionCommand() {

    let testSession = IMUSessionInfo(
      metadata: Google_Jacquard_Protocol_DataCollectionMetadata.with({
        $0.campaignID = "campaignID"
        $0.sessionID = "sessionID"
        $0.trialID = "trialID"
      }))

    let command = DeleteIMUSessionCommand(session: testSession)
    XCTAssertNotNil(command)

    guard let request = command.request as? Google_Jacquard_Protocol_Request else {
      XCTFail("Request type should be Jacquard Protocol Request")
      return
    }
    XCTAssertEqual(request.domain, .dataCollection)
    XCTAssertEqual(request.opcode, .dataCollectionTrialDataErase)

    let deleteTrialRequest =
      request.Google_Jacquard_Protocol_DataCollectionEraseTrialDataRequest_eraseTrialData
    XCTAssertEqual(deleteTrialRequest.campaignID, testSession.campaignID)
    XCTAssertEqual(deleteTrialRequest.sessionID, testSession.groupID)

    let response = Google_Jacquard_Protocol_Response.with {
      let delete = Google_Jacquard_Protocol_DataCollectionEraseTrialDataResponse.with {
        $0.dcStatus = .dataCollectionErasingData
      }
      $0.Google_Jacquard_Protocol_DataCollectionEraseTrialDataResponse_eraseTrialData = delete
    }

    command.parseResponse(outerProto: response).assertSuccess()
    verifyBadProtoResponse(command)
  }

  func testDeleteAllIMUSessionsCommand() {

    let command = DeleteAllIMUSessionsCommand()
    XCTAssertNotNil(command)

    guard let request = command.request as? Google_Jacquard_Protocol_Request else {
      XCTFail("Request type should be Jacquard Protocol Request")
      return
    }
    XCTAssertEqual(request.domain, .dataCollection)
    XCTAssertEqual(request.opcode, .dataCollectionDataErase)

    let response = Google_Jacquard_Protocol_Response.with {
      let deleteAll = Google_Jacquard_Protocol_DataCollectionEraseAllDataResponse.with {
        $0.dcStatus = .dataCollectionErasingData
      }
      $0.Google_Jacquard_Protocol_DataCollectionEraseAllDataResponse_eraseAllData = deleteAll
    }

    command.parseResponse(outerProto: response).assertSuccess()
    verifyBadProtoResponse(command)
  }

  func testRetreiveIMUSessionDataCommand() {

    let testSession = IMUSessionInfo(
      metadata: Google_Jacquard_Protocol_DataCollectionMetadata.with({
        $0.campaignID = "campaignID"
        $0.sessionID = "sessionID"
        $0.trialID = "trialID"
      }))

    let command = RetreiveIMUSessionDataCommand(session: testSession, offset: 100)
    XCTAssertNotNil(command)

    guard let request = command.request as? Google_Jacquard_Protocol_Request else {
      XCTFail("Request type should be Jacquard Protocol Request")
      return
    }
    XCTAssertEqual(request.domain, .dataCollection)
    XCTAssertEqual(request.opcode, .dataCollectionTrialData)

    let sessionDataRequest =
      request.Google_Jacquard_Protocol_DataCollectionTrialDataRequest_trialData
    XCTAssertEqual(sessionDataRequest.campaignID, testSession.campaignID)
    XCTAssertEqual(sessionDataRequest.sessionID, testSession.groupID)
    XCTAssertEqual(sessionDataRequest.offset, 100)

    let response = Google_Jacquard_Protocol_Response.with {
      let trialData = Google_Jacquard_Protocol_DataCollectionTrialDataResponse.with {
        $0.dcStatus = .dataCollectionXferData
      }
      $0.Google_Jacquard_Protocol_DataCollectionTrialDataResponse_trialData = trialData
    }

    command.parseResponse(outerProto: response).assertSuccess()
    verifyBadProtoResponse(command)
  }
}
