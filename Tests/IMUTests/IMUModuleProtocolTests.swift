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

class IMUModuleProtocolTests: XCTestCase {

  func testIMUSessionInfoNotificationInitializer() {
    let testTrialList = Google_Jacquard_Protocol_DataCollectionTrialList.with {
      $0.campaignID = "testCampaign"
      $0.sessionID = "testCampaign"
      $0.trialID = "testCampaign"
      $0.productID = "testCampaign"
      $0.trialData = [
        Google_Jacquard_Protocol_DataCollectionTrialData.with {
          $0.subjectID = "testSubject"
          $0.sensorData = [
            Google_Jacquard_Protocol_DataCollectionTrialSensorData.with {
              $0.sensorID = 123
              $0.fsize = 999
            }
          ]
        }
      ]
    }

    let testIMUSession = IMUSessionInfo(trial: testTrialList)
    XCTAssertNotNil(testIMUSession)
    XCTAssertEqual(testIMUSession.campaignID, testTrialList.campaignID)
    // TrialID, is mapped to sessionID in app.
    XCTAssertEqual(testIMUSession.sessionID, testTrialList.trialID)
    XCTAssertEqual(testIMUSession.groupID, testTrialList.sessionID)
  }

  func testIMUSessionInfoMetadataInitializer() {
    let metadata = Google_Jacquard_Protocol_DataCollectionMetadata.with {
      $0.campaignID = "testCampaign"
      $0.sessionID = "testCampaign"
      $0.trialID = "testCampaign"
      $0.productID = "testCampaign"
    }
    let testIMUSession = IMUSessionInfo(metadata: metadata)
    XCTAssertNotNil(testIMUSession)
    XCTAssertEqual(testIMUSession.campaignID, metadata.campaignID)
    // TrialID, is mapped to sessionID in app.
    XCTAssertEqual(testIMUSession.sessionID, metadata.trialID)
    XCTAssertEqual(testIMUSession.groupID, metadata.sessionID)
  }
}
