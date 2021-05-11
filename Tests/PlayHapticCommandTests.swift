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

class PlayHapticCommandTests: XCTestCase {

  private let gearData = FakeComponentHelper.gearData(
    vendorID: "fb-57-a1-12", productID: "5c-d8-78-b0")

  private let gearCapabilities = FakeComponentHelper.capabilities(
    vendorID: "fb-57-a1-12", productID: "5c-d8-78-b0")

  private lazy var fakeGearComponent = FakeGearComponent(
    componentID: 1,
    vendor: gearData.vendor,
    product: gearData.product,
    isAttached: true)

  func testRequestCreation() throws {
    let expectedOnTime: UInt32 = 200
    let expectedOffTime: UInt32 = 0
    let expectedMaxAmplitude: UInt32 = 65
    let expectedRepeat: UInt32 = 3
    let expectedHapticPattern: PlayHapticCommand.HapticPatternType = .hapticSymbolSineIncrease
    let expectedDomain: Google_Jacquard_Protocol_Domain = .gear
    let expectedOpcode: Google_Jacquard_Protocol_Opcode = .gearHaptic

    let frame = PlayHapticCommand.HapticFrame(
      onMs: expectedOnTime,
      offMs: expectedOffTime,
      maxAmplitudePercent: expectedMaxAmplitude,
      repeatNMinusOne: expectedRepeat,
      pattern: expectedHapticPattern
    )

    // Compose the request.
    let hapticRequest = try PlayHapticCommand(frame: frame, component: fakeGearComponent)

    // Validate the request.
    guard let request = hapticRequest.request as? Google_Jacquard_Protocol_Request else {
      XCTFail("Unexpected type for the haptic command request.")
      return
    }
    XCTAssertEqual(request.domain, expectedDomain, "Haptic request has wrong domain.")
    XCTAssertEqual(request.opcode, expectedOpcode, "Haptic request has wrong opcode.")
    XCTAssertEqual(
      request.componentID, fakeGearComponent.componentID, "Haptic request has wrong componentID.")
    XCTAssert(request.hasGoogle_Jacquard_Protocol_HapticRequest_haptic)
    let hapticPattern = request.Google_Jacquard_Protocol_HapticRequest_haptic
    XCTAssertEqual(hapticPattern.frames.onMs, expectedOnTime)
    XCTAssertEqual(hapticPattern.frames.offMs, expectedOffTime)
    XCTAssertEqual(hapticPattern.frames.maxAmplitudePercent, expectedMaxAmplitude)
    XCTAssertEqual(hapticPattern.frames.repeatNMinusOne, expectedRepeat)
    XCTAssertEqual(
      hapticPattern.frames.pattern, Google_Jacquard_Protocol_HapticSymbolType(expectedHapticPattern)
    )
  }

  func testFailureForGearWithNoHapticCapability() {

    let frame = PlayHapticCommand.HapticFrame(
      onMs: 200,
      offMs: 0,
      maxAmplitudePercent: 65,
      repeatNMinusOne: 3,
      pattern: .hapticSymbolSineIncrease
    )

    // Update the fake gear component with no capabilities.
    fakeGearComponent = FakeGearComponent(
      componentID: 1,
      vendor: gearData.vendor,
      product: gearData.product,
      isAttached: true)

    // Validate that error is thrown while creating the request.
    do {
      let _ = try PlayHapticCommand(frame: frame, component: fakeGearComponent)
    } catch (let error) {
      guard let commandError = error as? PlayHapticCommand.Error else {
        XCTFail("Unexpected error returned from PlayHapticCommand init")
        return
      }
      XCTAssertEqual(commandError, PlayHapticCommand.Error.componentDoesNotSupportPlayHaptic)
      XCTAssertEqual(commandError.description, "Attached gear does not support the haptic.")
    }
  }

  func testGoodResponse() throws {
    let goodResponseExpectation = expectation(description: "goodResponseExpectation")

    let frame = PlayHapticCommand.HapticFrame(
      onMs: 200,
      offMs: 0,
      maxAmplitudePercent: 65,
      repeatNMinusOne: 3,
      pattern: .hapticSymbolSineIncrease
    )

    let hapticRequest = try PlayHapticCommand(frame: frame, component: fakeGearComponent)
    let goodResponse = Google_Jacquard_Protocol_Response()
    hapticRequest.parseResponse(outerProto: goodResponse).assertSuccess { _ in
      goodResponseExpectation.fulfill()
    }

    wait(for: [goodResponseExpectation], timeout: 0.5)
  }

  func testBadResponse() throws {
    let badResponseExpectation = expectation(description: "badResponseExpectation")

    let frame = PlayHapticCommand.HapticFrame(
      onMs: 200,
      offMs: 0,
      maxAmplitudePercent: 65,
      repeatNMinusOne: 3,
      pattern: .hapticSymbolSineIncrease
    )

    let hapticRequest = try PlayHapticCommand(frame: frame, component: fakeGearComponent)

    // Provide bad proto as response.
    let badResponse = Google_Jacquard_Protocol_Color()
    hapticRequest.parseResponse(outerProto: badResponse).assertFailure { _ in
      badResponseExpectation.fulfill()
    }

    wait(for: [badResponseExpectation], timeout: 0.5)
  }

  func testHapticCommandError() {
    let error = PlayHapticCommand.Error.componentDoesNotSupportPlayHaptic
    XCTAssertEqual(error.description, "Component does not have haptic capability")
  }
}
