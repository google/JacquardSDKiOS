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
import XCTest

@testable import JacquardSDK

class PlayLEDPatternTests: XCTestCase {

  private let gearData = FakeComponentHelper.gearData(
    vendorID: "fb-57-a1-12", productID: "5c-d8-78-b0")

  private let gearCapabilities = FakeComponentHelper.capabilities(
    vendorID: "fb-57-a1-12", productID: "5c-d8-78-b0")

  private lazy var fakeGearComponent = FakeGearComponent(
    componentID: 1,
    vendor: gearData.vendor,
    product: gearData.product,
    isAttached: true)

  // LED capability for tag.
  let capability = GearMetadata.Capability(rawValue: 0)

  private func createFakeTagComponent(withCapabilities: Bool = true) -> FakeTagComponent {

    var product = GearMetadata.GearData.Product()
    product.id = TagConstants.product
    product.name = TagConstants.product
    if withCapabilities {
      // LED capability for tag.
      guard let capability = GearMetadata.Capability(rawValue: 0) else {
        preconditionFailure("LED capability is not available.")
      }
      product.capabilities = [capability]
    }

    var vendor = GearMetadata.GearData.Vendor()
    vendor.id = TagConstants.vendor
    vendor.name = TagConstants.vendor
    vendor.products = [product]

    return FakeTagComponent(
      componentID: TagConstants.FixedComponent.tag.rawValue,
      vendor: vendor,
      product: product,
      isAttached: false)
  }

  func testRequestCreation() throws {

    let color = PlayLEDPatternCommand.Color(red: 0, green: 0, blue: 255)
    let duration = 5000
    let frame = PlayLEDPatternCommand.Frame(color: color, durationMs: duration)
    let isResumable = false
    let playPauseToggle: PlayLEDPatternCommand.LEDPatternPlayType = .play
    let expectedDomain: Google_Jacquard_Protocol_Domain = .gear
    let expectedOpcode: Google_Jacquard_Protocol_Opcode = .gearLed

    // Create and validate play LED on gear request.
    let ledRequest = try PlayLEDPatternCommand(
      frames: [frame],
      durationMs: duration,
      component: fakeGearComponent,
      isResumable: isResumable,
      playPauseToggle: playPauseToggle
    )

    guard let request = ledRequest.request as? Google_Jacquard_Protocol_Request else {
      XCTFail("Unexpected type for the LED command request.")
      return
    }

    XCTAssertEqual(request.domain, expectedDomain, "Gear LED request has wrong domain.")
    XCTAssertEqual(request.opcode, expectedOpcode, "Gear LED request has wrong opcode.")
    XCTAssertEqual(
      request.componentID,
      fakeGearComponent.componentID,
      "Gear LED request has wrong componentID."
    )

    XCTAssert(request.hasGoogle_Jacquard_Protocol_LedPatternRequest_ledPatternRequest)

    var frameColor = Google_Jacquard_Protocol_Color()
    frameColor.red = UInt32(frame.color.red)
    frameColor.green = UInt32(frame.color.green)
    frameColor.blue = UInt32(frame.color.blue)

    let ledPattern = request.Google_Jacquard_Protocol_LedPatternRequest_ledPatternRequest
    XCTAssertEqual(ledPattern.frames[0].color, frameColor, "Gear LED request has wrong color.")
    XCTAssertEqual(ledPattern.durationMs, UInt32(duration), "Gear LED request has wrong duration.")
    XCTAssertEqual(ledPattern.resumable, isResumable, "Gear LED request has wrong isResumable.")
    XCTAssertEqual(
      ledPattern.playPauseToggle,
      Google_Jacquard_Protocol_PatternPlayType(playPauseToggle),
      "Gear LED request has wrong playPauseToggle."
    )

    // Create and validate play LED on tag request.
    let fakeTagComponent = createFakeTagComponent()

    let tagLedRequest = try PlayLEDPatternCommand(
      frames: [frame],
      durationMs: duration,
      component: fakeTagComponent
    )

    guard let tagRequest = tagLedRequest.request as? Google_Jacquard_Protocol_Request else {
      XCTFail("Unexpected type for the LED command request.")
      return
    }
    XCTAssertEqual(
      tagRequest.componentID,
      fakeTagComponent.componentID,
      "Tag LED request has wrong componentID."
    )
  }

  func testFailureForGearAndTagWithNoLEDCapability() {

    let color = PlayLEDPatternCommand.Color(red: 0, green: 0, blue: 255)
    let duration = 5000
    let frame = PlayLEDPatternCommand.Frame(color: color, durationMs: duration)

    // Update the fake gear component with no capabilities.
    fakeGearComponent = FakeGearComponent(
      componentID: 1,
      vendor: gearData.vendor,
      product: gearData.product,
      isAttached: true)

    // Validate that error is thrown while creating the play gear LED request.
    do {
      let _ = try PlayLEDPatternCommand(
        frames: [frame],
        durationMs: duration,
        component: fakeGearComponent
      )
    } catch let error as PlayLEDPatternCommand.Error {
      XCTAssertEqual(error, .componentDoesNotSupportPlayLEDPattern)
      XCTAssertEqual(error.description, "Component does not support the LED capability.")
    } catch {
      XCTFail("Unexpected error type: \(error)")
    }

    // Update the fake tag component with no capabilities.
    let fakeTagComponent = createFakeTagComponent(withCapabilities: false)

    // Validate that error is thrown while creating the play tag LED request.
    do {
      let _ = try PlayLEDPatternCommand(
        frames: [frame],
        durationMs: duration,
        component: fakeTagComponent
      )
    } catch let error as PlayLEDPatternCommand.Error {
      XCTAssertEqual(error, .componentDoesNotSupportPlayLEDPattern)
    } catch {
      XCTFail("Unexpected error type: \(error)")
    }
  }

  func testGoodResponse() throws {
    let goodGearLEDResponseExpectation = expectation(description: "goodGearLEDResponseExpectation")

    let color = PlayLEDPatternCommand.Color(red: 0, green: 0, blue: 255)
    let duration = 5000
    let frame = PlayLEDPatternCommand.Frame(color: color, durationMs: duration)

    // Verify good response for play gear LED request.
    let ledRequest = try PlayLEDPatternCommand(
      frames: [frame],
      durationMs: duration,
      component: fakeGearComponent
    )
    let goodResponse = Google_Jacquard_Protocol_Response()
    ledRequest.parseResponse(outerProto: goodResponse).assertSuccess { _ in
      goodGearLEDResponseExpectation.fulfill()
    }

    let goodTagLEDResponseExpectation = expectation(description: "goodTagLEDResponseExpectation")

    // Verify good response for play tag LED request.
    let tagLedRequest = try PlayLEDPatternCommand(
      frames: [frame],
      durationMs: duration,
      component: createFakeTagComponent()
    )
    let goodTagLedResponse = Google_Jacquard_Protocol_Response()
    tagLedRequest.parseResponse(outerProto: goodTagLedResponse).assertSuccess { _ in
      goodTagLEDResponseExpectation.fulfill()
    }

    wait(for: [goodGearLEDResponseExpectation, goodTagLEDResponseExpectation], timeout: 1.0)
  }

  func testGoodResponseWithColorConstructor() throws {
    let goodGearLEDResponseExpectation = expectation(description: "goodGearLEDResponseExpectation")

    let color = PlayLEDPatternCommand.Color(red: 0, green: 0, blue: 255)
    let duration = 5000

    // Verify good response for play gear LED request.
    let ledRequest = try PlayLEDPatternCommand(
      color: color,
      durationMs: duration,
      component: fakeGearComponent
    )
    let goodResponse = Google_Jacquard_Protocol_Response()
    ledRequest.parseResponse(outerProto: goodResponse).assertSuccess { _ in
      goodGearLEDResponseExpectation.fulfill()
    }

    let goodTagLEDResponseExpectation = expectation(description: "goodTagLEDResponseExpectation")

    // Verify good response for play tag LED request.
    let tagLedRequest = try PlayLEDPatternCommand(
      color: color,
      durationMs: duration,
      component: createFakeTagComponent(withCapabilities: true)
    )
    let goodTagLedResponse = Google_Jacquard_Protocol_Response()
    tagLedRequest.parseResponse(outerProto: goodTagLedResponse).assertSuccess { _ in
      goodTagLEDResponseExpectation.fulfill()
    }

    wait(for: [goodGearLEDResponseExpectation, goodTagLEDResponseExpectation], timeout: 1.0)
  }

  func testLEDNotSupportedException() throws {
    let color = PlayLEDPatternCommand.Color(red: 0, green: 0, blue: 255)
    let duration = 5000

    XCTAssertThrowsError(
      try PlayLEDPatternCommand(
        color: color,
        durationMs: duration,
        component: createFakeTagComponent(withCapabilities: false)
      )
    ) { error in
      XCTAssertNotNil(error)
      XCTAssert(error is PlayLEDPatternCommand.Error)
      XCTAssertEqual(error as! PlayLEDPatternCommand.Error, .componentDoesNotSupportPlayLEDPattern)
    }
  }

  func testBadResponse() throws {
    let badGearResponseExpectation = expectation(description: "badGearResponseExpectation")

    let color = PlayLEDPatternCommand.Color(red: 0, green: 0, blue: 255)
    let duration = 5000
    let frame = PlayLEDPatternCommand.Frame(color: color, durationMs: duration)

    // Verify bad response for play gear LED request.
    let ledRequest = try PlayLEDPatternCommand(
      frames: [frame],
      durationMs: duration,
      component: fakeGearComponent
    )

    // Provide bad proto as response.
    let badResponse = Google_Jacquard_Protocol_TouchData()
    ledRequest.parseResponse(outerProto: badResponse).assertFailure { _ in
      badGearResponseExpectation.fulfill()
    }

    // Verify bad response for play tag LED request.
    let badTagResponseExpectation = expectation(description: "badTagResponseExpectation")

    let tagLedRequest = try PlayLEDPatternCommand(
      frames: [frame],
      durationMs: duration,
      component: createFakeTagComponent()
    )
    let badTagLedResponse = Google_Jacquard_Protocol_TouchData()
    tagLedRequest.parseResponse(outerProto: badTagLedResponse).assertFailure { _ in
      badTagResponseExpectation.fulfill()
    }

    wait(for: [badGearResponseExpectation, badTagResponseExpectation], timeout: 2.0)
  }

  func testLEDCommandError() {
    let error = PlayLEDPatternCommand.Error.componentDoesNotSupportPlayLEDPattern
    XCTAssertEqual(error.description, "Component does not have LED capability")
  }
}
