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

import SwiftProtobuf
import XCTest

@testable import JacquardSDK

class BatteryServiceTests: XCTestCase {

  struct CatchLogger: Logger {
    func log(level: LogLevel, file: String, line: Int, function: String, message: () -> String) {
      expectation.fulfill()
    }

    var expectation: XCTestExpectation
  }

  override class func tearDown() {
    super.tearDown()

    // Other tests may run in the same process. Ensure that any fake logger fulfillment doesn't
    // cause any assertions later.
    JacquardSDK.setGlobalJacquardSDKLogger(JacquardSDK.createDefaultLogger())
  }

  //MARK: General tests

  func testCreateCommandRequest() {
    let _ = BatteryStatusCommand()
  }

  //MARK: - Request construction tests

  func testRequestCreation() {
    guard let request = BatteryStatusCommand().request as? Google_Jacquard_Protocol_Request else {
      XCTFail("Unexpected type returned from .request")
      return
    }
    XCTAssertEqual(request.domain, .base)
    XCTAssertEqual(request.opcode, .batteryStatus)
    XCTAssertTrue(request.hasGoogle_Jacquard_Protocol_BatteryStatusRequest_batteryStatusRequest)
    let batteryRequest = request.Google_Jacquard_Protocol_BatteryStatusRequest_batteryStatusRequest
    XCTAssertTrue(batteryRequest.readBatteryLevel)
    XCTAssertTrue(batteryRequest.readChargingStatus)
  }

  //MARK: - Notification Proto payload tests

  /// Proto payload is Any type, so we need to ensure a bad payload is safely ignored.
  func testBadNotificationProtoContents() {
    let assertionExpectation = expectation(description: "Raised exception")
    jqLogger = CatchLogger(expectation: assertionExpectation)
    let notification = BatteryStatusNotificationSubscription()
    let badProto = Google_Jacquard_Protocol_Color()
    XCTAssertNil(notification.extract(from: badProto))
    wait(for: [assertionExpectation], timeout: 1)
  }

  /// Even once we have a response proto, it may be missing battery status information.
  func testEmptyNotification() {
    let notification = BatteryStatusNotificationSubscription()
    let badProto = Google_Jacquard_Protocol_Notification()
    XCTAssertNil(notification.extract(from: badProto))
  }

  /// Even once we have a notification proto with battery status information, it may be missing one of charging status or battery level.
  func testNotificationProtoMissingBatteryStatus() {
    let notification = BatteryStatusNotificationSubscription()
    let emptyProto = Google_Jacquard_Protocol_Notification.with {
      let battery = Google_Jacquard_Protocol_BatteryStatusNotification()
      $0.Google_Jacquard_Protocol_BatteryStatusNotification_batteryStatusNotification = battery
    }
    XCTAssertNil(notification.extract(from: emptyProto))

    let chargingOnlyProto = Google_Jacquard_Protocol_Notification.with {
      let battery = Google_Jacquard_Protocol_BatteryStatusNotification.with {
        $0.chargingStatus = .charging
      }
      $0.Google_Jacquard_Protocol_BatteryStatusNotification_batteryStatusNotification = battery
    }
    XCTAssertNil(notification.extract(from: chargingOnlyProto))

    let levelOnlyProto = Google_Jacquard_Protocol_Notification.with {
      let battery = Google_Jacquard_Protocol_BatteryStatusNotification.with {
        $0.batteryLevel = 1
      }
      $0.Google_Jacquard_Protocol_BatteryStatusNotification_batteryStatusNotification = battery
    }
    XCTAssertNil(notification.extract(from: levelOnlyProto))
  }

  func testGoodNotificationProtoContents() {
    let notification = BatteryStatusNotificationSubscription()

    let goodProto = Google_Jacquard_Protocol_Notification.with {
      let battery = Google_Jacquard_Protocol_BatteryStatusNotification.with {
        $0.chargingStatus = .charging
        $0.batteryLevel = 1
      }
      $0.Google_Jacquard_Protocol_BatteryStatusNotification_batteryStatusNotification = battery
    }

    guard let result = notification.extract(from: goodProto) else {
      XCTFail("extract(goodProto) returned nil")
      return
    }

    XCTAssertEqual(result.chargingState, .charging)
    XCTAssertEqual(result.batteryLevel, 1)

    let goodProto2 = Google_Jacquard_Protocol_Notification.with {
      let battery = Google_Jacquard_Protocol_BatteryStatusNotification.with {
        $0.chargingStatus = .notCharging
        $0.batteryLevel = 42
      }
      $0.Google_Jacquard_Protocol_BatteryStatusNotification_batteryStatusNotification = battery
    }

    guard let result2 = notification.extract(from: goodProto2) else {
      XCTFail("extract(goodProto2) returned nil")
      return
    }

    XCTAssertEqual(result2.chargingState, .notCharging)
    XCTAssertEqual(result2.batteryLevel, 42)
  }

  //MARK: - Command Response Proto payload tests

  /// Proto payload is Any type, so we need to ensure a bad payload is safely ignored.
  func testBadResponseProtoContents() {
    let assertionExpectation = expectation(description: "Raised exception")
    jqLogger = CatchLogger(expectation: assertionExpectation)
    let command = BatteryStatusCommand()
    let badProto = Google_Jacquard_Protocol_Color()
    command.parseResponse(outerProto: badProto).assertFailure()
    wait(for: [assertionExpectation], timeout: 1)
  }

  /// Even once we have a response proto, it may be missing battery status information.
  func testEmptyResponse() {
    let command = BatteryStatusCommand()
    let badProto = Google_Jacquard_Protocol_Response()
    command.parseResponse(outerProto: badProto).assertFailure()
  }

  /// Even once we have a notification proto with battery status information, it may be missing one of charging status or battery level.
  func testResponseProtoMissingBatteryStatus() {
    let command = BatteryStatusCommand()
    let emptyProto = Google_Jacquard_Protocol_Response.with {
      let battery = Google_Jacquard_Protocol_BatteryStatusResponse()
      $0.Google_Jacquard_Protocol_BatteryStatusResponse_batteryStatusResponse = battery
    }
    command.parseResponse(outerProto: emptyProto).assertFailure()

    let chargingOnlyProto = Google_Jacquard_Protocol_Response.with {
      let battery = Google_Jacquard_Protocol_BatteryStatusResponse.with {
        $0.chargingStatus = .charging
      }
      $0.Google_Jacquard_Protocol_BatteryStatusResponse_batteryStatusResponse = battery
    }
    command.parseResponse(outerProto: chargingOnlyProto).assertFailure()

    let levelOnlyProto = Google_Jacquard_Protocol_Response.with {
      let battery = Google_Jacquard_Protocol_BatteryStatusResponse.with {
        $0.batteryLevel = 1
      }
      $0.Google_Jacquard_Protocol_BatteryStatusResponse_batteryStatusResponse = battery
    }
    command.parseResponse(outerProto: levelOnlyProto).assertFailure()
  }

  func testGoodResponseProtoContents() {
    let command = BatteryStatusCommand()

    let goodProto = Google_Jacquard_Protocol_Response.with {
      let battery = Google_Jacquard_Protocol_BatteryStatusResponse.with {
        $0.chargingStatus = .charging
        $0.batteryLevel = 1
      }
      $0.Google_Jacquard_Protocol_BatteryStatusResponse_batteryStatusResponse = battery
    }

    command.parseResponse(outerProto: goodProto).assertSuccess { result in
      XCTAssertEqual(result.chargingState, .charging)
      XCTAssertEqual(result.batteryLevel, 1)
    }

    let goodProto2 = Google_Jacquard_Protocol_Response.with {
      let battery = Google_Jacquard_Protocol_BatteryStatusResponse.with {
        $0.chargingStatus = .notCharging
        $0.batteryLevel = 42
      }
      $0.Google_Jacquard_Protocol_BatteryStatusResponse_batteryStatusResponse = battery
    }

    command.parseResponse(outerProto: goodProto2).assertSuccess { result in
      XCTAssertEqual(result.chargingState, .notCharging)
      XCTAssertEqual(result.batteryLevel, 42)
    }
  }
}
