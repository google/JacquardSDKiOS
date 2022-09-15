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

// TODO: http://b/210576529 Remove API key from code and run unit test without any server connection
let config = SDKConfig(
  apiKey: "AIzaSyAcSpUJydJ2uBjrFqpEfZ5plfFbDkQgydQ",
  server: APIServer(baseURL: URL(string: "https://autopush-jacquard.sandbox.googleapis.com")!)
)

final class FirmwareUpdateStateMachineTests: XCTestCase {

  private var observations = [Cancellable]()
  private var centralManager: FakeCentralManager?
  private var connectCancellable: Cancellable?

  override func tearDown() {
    if let centralManager = centralManager {
      JacquardManagerImplementation.clearConnectionStateMachine(
        for: centralManager.peripheral.identifier)
    }
    super.tearDown()
  }

  func testApplyAndExecuteUpdateStateMachineSuccess() throws {
    throw XCTSkip("b/204121008 - flaky tests")

    // Connect fake tag before apply update.
    connectFakeTag()

    let attachNotificationExpectation = expectation(description: "attachNotificationExpectation")

    func createSubscriptions(_ tag: SubscribableTag) {
      tag.subscribe(AttachedNotificationSubscription())
        .sink { component in
          XCTAssertNotNil(component)
          XCTAssertEqual(component!.vendor.name, "Levi's")
          XCTAssert(component!.isAttached)
          attachNotificationExpectation.fulfill()
        }.addTo(&observations)
    }

    let transport = FakeTransport()
    let connectedTag = ConnectedTagModel(
      transport: transport,
      userPublishQueue: .main,
      tagComponent: FakeConnectedTag(transport: transport).tagComponent,
      sdkConfig: config
    )
    connectedTag.registerSubscriptions(createSubscriptions(_:))

    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
      transport.postGearAttach()
    }
    wait(for: [attachNotificationExpectation], timeout: 2.0)

    // After attach notification, tag sends bluetooth config (notifQueueDepth) command. Hold
    // execution before we start firmware update.
    sleep(1.0)

    let idleExpectation = expectation(description: "idleExpectation")
    let prepareForTransferExpectation = expectation(description: "prepareForTransferExpectation")
    let transferredExpectation = expectation(description: "transferredExpectation")
    let executingExpectation = expectation(description: "executingExpectation")
    let executeRequestForGearExpectation = expectation(
      description: "executeRequestForGearExpectation")
    let executeRequestForTagExpectation = expectation(
      description: "executeRequestForTagExpectation")
    let executedExpectation = expectation(description: "executedExpectation")
    let image = Data((0..<1000).map { UInt8($0 % 255) })
    let updateInfoTag = DFUUpdateInfo(
      date: "21-06-2016",
      version: "1.0.0",
      dfuStatus: .mandatory,
      vid: "11-78-30-c8",
      pid: "28-3b-e7-a0",
      downloadURL: "https://www.google.com",
      image: image
    )

    let updateInfoInterposer = DFUUpdateInfo(
      date: "21-06-2016",
      version: "1.0.0",
      dfuStatus: .mandatory,
      vid: "74-a8-ce-54",
      pid: "8a-66-50-f4",
      downloadURL: "https://www.google.com",
      image: image
    )

    let updateStateMachine = FirmwareUpdateStateMachine(
      updates: [updateInfoTag, updateInfoInterposer],
      connectedTag: connectedTag,
      shouldAutoExecute: false
    )

    updateStateMachine.statePublisher.sink { state in
      switch state {
      case .idle:
        idleExpectation.fulfill()
      case .preparingForTransfer:
        prepareForTransferExpectation.fulfill()
      case .transferring(_):
        // We dont have specific count for this state to be fulfill. Hence not setting any
        // expectation here.
        break
      case .transferred:
        transferredExpectation.fulfill()
      case .executing:
        executingExpectation.fulfill()
      case .completed:
        executedExpectation.fulfill()
      default:
        XCTFail("Unexpected state \(state)")
      }
    }.addTo(&observations)

    let batteryStatusExpectation = expectation(description: "batteryStatusExpectation")
    enqueueBatteryStatusRequest(transport, expectation: batteryStatusExpectation)
    updateStateMachine.applyUpdates()
    wait(for: [batteryStatusExpectation], timeout: 1.0)

    // This looping will required to reset enqueueRequestHandler for dfu status, prepare, write
    // command for each component.
    [updateInfoTag, updateInfoInterposer].forEach { _ in
      enqueueDFUStatusRequest(transport)
      enqueueDFUPrepareRequest(transport)
      enqueueDFUWriteRequest(transport, image: image)
    }

    wait(
      for: [idleExpectation, prepareForTransferExpectation, transferredExpectation],
      timeout: 1.0,
      enforceOrder: true
    )

    transport.enqueueRequestHandler = { (request, _, _) in

      // Safe to force unwrap here as the request will always be of type
      // `Google_Jacquard_Protocol_Request`.
      let request = request as! Google_Jacquard_Protocol_Request

      let executeRequest = request.Google_Jacquard_Protocol_DFUExecuteRequest_dfuExecute
      // For a gear component, after successful response for dfu execute command, need to send dfu
      // execute notification.
      if executeRequest.vendorID != 293_089_480 && executeRequest.productID != 675_014_560 {
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 1.0) {
          transport.postDFUExecute()
        }
        executeRequestForGearExpectation.fulfill()
      } else {
        executeRequestForTagExpectation.fulfill()
      }
      if request.domain == .dfu && request.opcode == .dfuExecute {
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 2.0) {
          self.reconnectFakeTag()
        }
        return .success(FakeDFUCommands.prepareDFUExecuteResponse(status: .ok))
      } else {
        preconditionFailure()
      }
    }
    updateStateMachine.executeUpdates()

    wait(
      for: [
        executingExpectation,
        executeRequestForGearExpectation,
        executeRequestForTagExpectation,
        executedExpectation,
      ],
      timeout: 6.0,
      enforceOrder: true
    )
  }

  func testApplyAndAutoExecuteUpdateStateMachineSuccess() throws {
    throw XCTSkip("b/204121008 - flaky tests")

    // Connect fake tag before apply update.
    connectFakeTag()

    let attachNotificationExpectation = expectation(description: "attachNotificationExpectation")

    func createSubscriptions(_ tag: SubscribableTag) {
      tag.subscribe(AttachedNotificationSubscription())
        .sink { component in
          XCTAssertNotNil(component)
          XCTAssertEqual(component!.vendor.name, "Levi's")
          XCTAssert(component!.isAttached)
          attachNotificationExpectation.fulfill()
        }.addTo(&observations)
    }

    let transport = FakeTransport()
    let connectedTag = ConnectedTagModel(
      transport: transport,
      userPublishQueue: .main,
      tagComponent: FakeConnectedTag(transport: transport).tagComponent,
      sdkConfig: config
    )
    connectedTag.registerSubscriptions(createSubscriptions(_:))

    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
      transport.postGearAttach()
    }
    wait(for: [attachNotificationExpectation], timeout: 2.0)

    // After attach notification, tag send blutooth config (notifQueueDepth) command. Hold execution
    // before we start firmware update.
    sleep(1.0)

    let idleExpectation = expectation(description: "idleExpectation")
    let prepareForTransferExpectation = expectation(description: "prepareForTransferExpectation")
    let transferredExpectation = expectation(description: "transferredExpectation")
    let executingExpectation = expectation(description: "executingExpectation")
    let executeRequestForGearExpectation = expectation(
      description: "executeRequestForGearExpectation")
    let executeRequestForTagExpectation = expectation(
      description: "executeRequestForTagExpectation")
    let executedExpectation = expectation(description: "executedExpectation")
    let image = Data((0..<1000).map { UInt8($0 % 255) })
    let updateInfoTag = DFUUpdateInfo(
      date: "21-06-2016",
      version: "1.0.0",
      dfuStatus: .mandatory,
      vid: "11-78-30-c8",
      pid: "28-3b-e7-a0",
      downloadURL: "https://www.google.com",
      image: image
    )

    let updateInfoInterposer = DFUUpdateInfo(
      date: "21-06-2016",
      version: "1.0.0",
      dfuStatus: .mandatory,
      vid: "74-a8-ce-54",
      pid: "8a-66-50-f4",
      downloadURL: "https://www.google.com",
      image: image
    )

    let updateStateMachine = FirmwareUpdateStateMachine(
      updates: [updateInfoTag, updateInfoInterposer],
      connectedTag: connectedTag,
      shouldAutoExecute: true
    )

    updateStateMachine.statePublisher.sink { state in
      switch state {
      case .idle:
        idleExpectation.fulfill()
      case .preparingForTransfer:
        prepareForTransferExpectation.fulfill()
      case .transferring(_):
        // We dont have specific count for this state to be fulfill. Hence not setting any
        // expectation here.
        break
      case .transferred:
        transferredExpectation.fulfill()
      case .executing:
        executingExpectation.fulfill()
      case .completed:
        executedExpectation.fulfill()
      default:
        XCTFail("Unexpected state \(state)")
      }
    }.addTo(&observations)

    let batteryStatusExpectation = expectation(description: "batteryStatusExpectation")
    enqueueBatteryStatusRequest(transport, expectation: batteryStatusExpectation)
    updateStateMachine.applyUpdates()
    wait(for: [batteryStatusExpectation], timeout: 1.0)

    // This looping will required to reset enqueueRequestHandler for dfu status, prepare, write
    // command for each component.
    [updateInfoTag, updateInfoInterposer].forEach { _ in
      enqueueDFUStatusRequest(transport)
      enqueueDFUPrepareRequest(transport)
      enqueueDFUWriteRequest(transport, image: image)
    }

    transport.enqueueRequestHandler = { (request, _, _) in

      // Safe to force unwrap here as the request will always be of type
      // `Google_Jacquard_Protocol_Request`.
      let request = request as! Google_Jacquard_Protocol_Request

      let executeRequest = request.Google_Jacquard_Protocol_DFUExecuteRequest_dfuExecute
      // For a gear component, after successful response for dfu execute command, need to send dfu
      // execute notification.
      if executeRequest.vendorID != 293_089_480 && executeRequest.productID != 675_014_560 {
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 1.0) {
          transport.postDFUExecute()
        }
        executeRequestForGearExpectation.fulfill()
      } else {
        executeRequestForTagExpectation.fulfill()
      }
      if request.domain == .dfu && request.opcode == .dfuExecute {
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 2.0) {
          self.reconnectFakeTag()
        }
        return .success(FakeDFUCommands.prepareDFUExecuteResponse(status: .ok))
      } else {
        preconditionFailure()
      }
    }

    wait(
      for: [
        idleExpectation,
        prepareForTransferExpectation,
        transferredExpectation,
        executingExpectation,
        executeRequestForGearExpectation,
        executeRequestForTagExpectation,
        executedExpectation,
      ],
      timeout: 6.0,
      enforceOrder: true
    )
  }

  func testUpdateFailureWithDataUnavailable() {
    // Connect fake tag before apply update.
    connectFakeTag()

    let idleExpectation = expectation(description: "idleExpectation")
    let prepareForTransferExpectation = expectation(description: "prepareForTransferExpectation")
    let dataUnavailableExpectation = expectation(description: "dataUnavailableExpectation")
    let updateInfoTag = DFUUpdateInfo(
      date: "21-06-2016",
      version: "1.0.0",
      dfuStatus: .mandatory,
      vid: "11-78-30-c8",
      pid: "28-3b-e7-a0",
      downloadURL: "https://www.google.com",
      image: nil
    )

    let transport = FakeTransport()
    let connectedTag = ConnectedTagModel(
      transport: transport,
      userPublishQueue: .main,
      tagComponent: FakeConnectedTag(transport: transport).tagComponent,
      sdkConfig: config
    )

    let updateStateMachine = FirmwareUpdateStateMachine(
      updates: [updateInfoTag],
      connectedTag: connectedTag,
      shouldAutoExecute: false
    )

    updateStateMachine.statePublisher.sink { state in
      switch state {
      case .idle:
        idleExpectation.fulfill()
      case .preparingForTransfer:
        prepareForTransferExpectation.fulfill()
      case .error(let error):
        if case .dataUnavailable = error {
          XCTAssertEqual(
            error.localizedDescription, FirmwareUpdateError.dataUnavailable.localizedDescription
          )
          dataUnavailableExpectation.fulfill()
        } else {
          XCTFail("Unexpected error \(error.localizedDescription)")
        }
      default:
        XCTFail("Unexpected state \(state)")
      }
    }.addTo(&observations)

    let batteryStatusExpectation = expectation(description: "batteryStatusExpectation")
    enqueueBatteryStatusRequest(transport, expectation: batteryStatusExpectation)
    updateStateMachine.applyUpdates()
    wait(for: [batteryStatusExpectation], timeout: 1.0)

    wait(
      for: [idleExpectation, prepareForTransferExpectation, dataUnavailableExpectation],
      timeout: 1.0,
      enforceOrder: true
    )
  }

  func testUpdateFailureWithDidReceiveTransferError() {
    // Connect fake tag before apply update.
    connectFakeTag()

    let idleExpectation = expectation(description: "idleExpectation")
    let prepareForTransferExpectation = expectation(description: "prepareForTransferExpectation")
    let transferErrorExpectation = expectation(description: "transferErrorExpectation")
    let updateInfoTag = DFUUpdateInfo(
      date: "21-06-2016",
      version: "1.0.0",
      dfuStatus: .mandatory,
      vid: "11-78-30-c8",
      pid: "28-3b-e7-a0",
      downloadURL: "https://www.google.com",
      image: Data((0..<1000).map { UInt8($0 % 255) })
    )

    let transport = FakeTransport()
    let connectedTag = ConnectedTagModel(
      transport: transport,
      userPublishQueue: .main,
      tagComponent: FakeConnectedTag(transport: transport).tagComponent,
      sdkConfig: config
    )

    let updateStateMachine = FirmwareUpdateStateMachine(
      updates: [updateInfoTag],
      connectedTag: connectedTag,
      shouldAutoExecute: false
    )

    updateStateMachine.statePublisher.sink { state in
      switch state {
      case .idle:
        idleExpectation.fulfill()
      case .preparingForTransfer:
        prepareForTransferExpectation.fulfill()
      case .error(let error):
        if case .transfer = error {
          XCTAssert(state.isTerminal)
          XCTAssert(!error.localizedDescription.isEmpty)
          transferErrorExpectation.fulfill()
        } else {
          XCTFail("Unexpected error \(error.localizedDescription)")
        }
      default:
        XCTFail("Unexpected state \(state)")
      }
    }.addTo(&observations)

    let batteryStatusExpectation = expectation(description: "batteryStatusExpectation")
    enqueueBatteryStatusRequest(transport, expectation: batteryStatusExpectation)
    updateStateMachine.applyUpdates()
    wait(for: [batteryStatusExpectation], timeout: 1.0)

    // Provide failure response through enqueue function handler.
    transport.enqueueRequestHandler = { (request, _, _) in
      return .success(
        FakeDFUCommands.prepareDFUStatusResponse(status: .errorHardware, dfuStatusResponse: nil)
      )
    }

    wait(
      for: [idleExpectation, prepareForTransferExpectation, transferErrorExpectation],
      timeout: 1.0,
      enforceOrder: true
    )
  }

  func testUpdateFailureWithInvalidState() {
    // Connect fake tag before apply update.
    connectFakeTag()

    let idleExpectation = expectation(description: "idleExpectation")
    let prepareForTransferExpectation = expectation(description: "prepareForTransferExpectation")
    let invalidStateExpectation = expectation(description: "invalidStateExpectation")
    let updateInfoTag = DFUUpdateInfo(
      date: "21-06-2016",
      version: "1.0.0",
      dfuStatus: .mandatory,
      vid: "11-78-30-c8",
      pid: "28-3b-e7-a0",
      downloadURL: "https://www.google.com",
      image: Data((0..<1000).map { UInt8($0 % 255) })
    )

    let transport = FakeTransport()
    let connectedTag = ConnectedTagModel(
      transport: transport,
      userPublishQueue: .main,
      tagComponent: FakeConnectedTag(transport: transport).tagComponent,
      sdkConfig: config
    )

    let updateStateMachine = FirmwareUpdateStateMachine(
      updates: [updateInfoTag],
      connectedTag: connectedTag,
      shouldAutoExecute: false
    )

    updateStateMachine.statePublisher.sink { state in
      switch state {
      case .idle:
        idleExpectation.fulfill()
      case .preparingForTransfer:
        prepareForTransferExpectation.fulfill()
        updateStateMachine.applyUpdates()
      case .error(let error):
        if case .invalidState = error {
          XCTAssert(!error.localizedDescription.isEmpty)
          invalidStateExpectation.fulfill()
        } else {
          XCTFail("Unexpected error \(error.localizedDescription)")
        }
      default:
        XCTFail("Unexpected state \(state)")
      }
    }.addTo(&observations)

    let batteryStatusExpectation = expectation(description: "batteryStatusExpectation")
    enqueueBatteryStatusRequest(transport, expectation: batteryStatusExpectation)
    updateStateMachine.applyUpdates()
    wait(for: [batteryStatusExpectation], timeout: 1.0)

    // Provide failure response through enqueue function handler.
    transport.enqueueRequestHandler = { (request, _, _) in
      return .success(
        FakeDFUCommands.prepareDFUStatusResponse(status: .errorHardware, dfuStatusResponse: nil)
      )
    }

    wait(
      for: [
        idleExpectation,
        prepareForTransferExpectation,
        invalidStateExpectation,
      ],
      timeout: 2.0,
      enforceOrder: true
    )
  }

  func testUpdateFailureDueToExecutionError() {
    // Connect fake tag before apply update.
    connectFakeTag()

    let idleExpectation = expectation(description: "idleExpectation")
    let prepareForTransferExpectation = expectation(description: "prepareForTransferExpectation")
    let transferredExpectation = expectation(description: "transferredExpectation")
    let executingExpectation = expectation(description: "executingExpectation")
    let executionErrorExpectation = expectation(description: "executionErrorExpectation")

    let transport = FakeTransport()
    let connectedTag = ConnectedTagModel(
      transport: transport,
      userPublishQueue: .main,
      tagComponent: FakeConnectedTag(transport: transport).tagComponent,
      sdkConfig: config
    )
    let image = Data((0..<1000).map { UInt8($0 % 255) })
    let updateInfoTag = DFUUpdateInfo(
      date: "21-06-2016",
      version: "1.0.0",
      dfuStatus: .mandatory,
      vid: "11-78-30-c8",
      pid: "28-3b-e7-a0",
      downloadURL: "https://www.google.com",
      image: image
    )
    let updateStateMachine = FirmwareUpdateStateMachine(
      updates: [updateInfoTag],
      connectedTag: connectedTag,
      shouldAutoExecute: true
    )

    updateStateMachine.statePublisher.sink { state in
      switch state {
      case .idle:
        idleExpectation.fulfill()
      case .preparingForTransfer:
        prepareForTransferExpectation.fulfill()
      case .transferring(_):
        // We dont have specific count for this state to be fulfill. Hence not setting any
        // expectation here.
        break
      case .transferred:
        transferredExpectation.fulfill()
      case .executing:
        executingExpectation.fulfill()
      case .completed:
        XCTFail("Execution success is not expected.")
      case .error(let error):
        if case .execution = error {
          XCTAssert(!error.localizedDescription.isEmpty)
          executionErrorExpectation.fulfill()
        } else {
          XCTFail("Unexpected error \(error.localizedDescription)")
        }
      case .stopped:
        XCTFail("Execution stop is not expected.")
      }
    }.addTo(&observations)

    let batteryStatusExpectation = expectation(description: "batteryStatusExpectation")
    enqueueBatteryStatusRequest(transport, expectation: batteryStatusExpectation)
    updateStateMachine.applyUpdates()
    wait(for: [batteryStatusExpectation], timeout: 1.0)

    // This looping will required to reset enqueueRequestHandler for dfu status, prepare, write
    // command for each component.
    [updateInfoTag].forEach { _ in
      enqueueDFUStatusRequest(transport)
      enqueueDFUPrepareRequest(transport)
      enqueueDFUWriteRequest(transport, image: image)
    }

    transport.enqueueRequestHandler = { (request, _, _) in

      // Safe to force unwrap here as the request will always be of type
      // `Google_Jacquard_Protocol_Request`.
      let request = request as! Google_Jacquard_Protocol_Request

      if request.domain == .dfu && request.opcode == .dfuExecute {
        return .failure(FirmwareUpdateError.internalError("DFU execution error"))
      } else {
        preconditionFailure()
      }
    }

    wait(
      for: [
        idleExpectation,
        prepareForTransferExpectation,
        transferredExpectation,
        executingExpectation,
        executionErrorExpectation,
      ],
      timeout: 2.0,
      enforceOrder: true
    )
  }

  func testFirmwareApplyUpdateWhenTagDisconnected() {
    let idleExpectation = expectation(description: "idleExpectation")
    let tagDisconnectedExpectation = expectation(description: "tagDisconnectedExpectation")
    let updateInfoTag = DFUUpdateInfo(
      date: "21-06-2016",
      version: "1.0.0",
      dfuStatus: .mandatory,
      vid: "11-78-30-c8",
      pid: "28-3b-e7-a0",
      downloadURL: "https://www.google.com",
      image: Data((0..<1000).map { UInt8($0 % 255) })
    )

    let transport = FakeTransport()
    let connectedTag = ConnectedTagModel(
      transport: transport,
      userPublishQueue: .main,
      tagComponent: FakeConnectedTag(transport: transport).tagComponent,
      sdkConfig: config
    )

    JacquardManagerImplementation.clearConnectionStateMachine(for: connectedTag.identifier)

    let updateStateMachine = FirmwareUpdateStateMachine(
      updates: [updateInfoTag],
      connectedTag: connectedTag,
      shouldAutoExecute: false
    )

    updateStateMachine.statePublisher.sink { state in
      switch state {
      case .idle:
        idleExpectation.fulfill()
      case .error(let error):
        if case .tagDisconnected = error {
          XCTAssertEqual(
            error.localizedDescription, FirmwareUpdateError.tagDisconnected.localizedDescription
          )
          tagDisconnectedExpectation.fulfill()
        } else {
          XCTFail("Unexpected error \(error.localizedDescription)")
        }
      default:
        XCTFail("Unexpected state \(state)")
      }
    }.addTo(&observations)

    updateStateMachine.applyUpdates()

    wait(
      for: [
        idleExpectation,
        tagDisconnectedExpectation,
      ],
      timeout: 1.0,
      enforceOrder: true
    )
  }

  func testFirmwareApplyUpdateWhenLowBattery() {
    // Connect fake tag before apply update.
    connectFakeTag()

    let idleExpectation = expectation(description: "idleExpectation")
    let lowBatteryExpectation = expectation(description: "lowBatteryExpectation")
    let updateInfoTag = DFUUpdateInfo(
      date: "21-06-2016",
      version: "1.0.0",
      dfuStatus: .mandatory,
      vid: "11-78-30-c8",
      pid: "28-3b-e7-a0",
      downloadURL: "https://www.google.com",
      image: Data((0..<1000).map { UInt8($0 % 255) })
    )

    let transport = FakeTransport()
    let connectedTag = ConnectedTagModel(
      transport: transport,
      userPublishQueue: .main,
      tagComponent: FakeConnectedTag(transport: transport).tagComponent,
      sdkConfig: config
    )

    let updateStateMachine = FirmwareUpdateStateMachine(
      updates: [updateInfoTag],
      connectedTag: connectedTag,
      shouldAutoExecute: false
    )

    updateStateMachine.statePublisher.sink { state in
      switch state {
      case .idle:
        idleExpectation.fulfill()
      case .error(let error):
        if case .lowBattery = error {
          XCTAssertEqual(
            error.localizedDescription, FirmwareUpdateError.lowBattery.localizedDescription
          )
          lowBatteryExpectation.fulfill()
        } else {
          XCTFail("Unexpected error \(error.localizedDescription)")
        }
      default:
        XCTFail("Unexpected state \(state)")
      }
    }.addTo(&observations)

    let batteryStatusExpectation = expectation(description: "batteryStatusExpectation")
    enqueueBatteryStatusRequest(transport, expectation: batteryStatusExpectation, lowBattery: true)
    updateStateMachine.applyUpdates()
    wait(for: [batteryStatusExpectation], timeout: 1.0)

    wait(
      for: [
        idleExpectation,
        lowBatteryExpectation,
      ],
      timeout: 2.0,
      enforceOrder: true
    )
  }

  func testFirmwareApplyUpdateWhenBatteryStatusFailure() {
    // Connect fake tag before apply update.
    connectFakeTag()

    let idleExpectation = expectation(description: "idleExpectation")
    let batteryStatusRequestFailedExpectation = expectation(
      description: "batteryStatusRequestFailedExpectation"
    )
    let updateInfoTag = DFUUpdateInfo(
      date: "21-06-2016",
      version: "1.0.0",
      dfuStatus: .mandatory,
      vid: "11-78-30-c8",
      pid: "28-3b-e7-a0",
      downloadURL: "https://www.google.com",
      image: Data((0..<1000).map { UInt8($0 % 255) })
    )

    let transport = FakeTransport()
    let connectedTag = ConnectedTagModel(
      transport: transport,
      userPublishQueue: .main,
      tagComponent: FakeConnectedTag(transport: transport).tagComponent,
      sdkConfig: config
    )

    let updateStateMachine = FirmwareUpdateStateMachine(
      updates: [updateInfoTag],
      connectedTag: connectedTag,
      shouldAutoExecute: false
    )

    updateStateMachine.statePublisher.sink { state in
      switch state {
      case .idle:
        idleExpectation.fulfill()
      case .error(let error):
        if case .internalError = error {
          XCTAssert(!error.localizedDescription.isEmpty)
          batteryStatusRequestFailedExpectation.fulfill()
        } else {
          XCTFail("Unexpected error \(error.localizedDescription)")
        }
      default:
        XCTFail("Unexpected state \(state)")
      }
    }.addTo(&observations)

    updateStateMachine.applyUpdates()

    // Provide failure response through enqueue function handler.
    transport.enqueueRequestHandler = { (request, _, _) in
      let response = Google_Jacquard_Protocol_Response.with {
        $0.id = 1
        $0.status = .errorBattery
      }
      return .success(try! response.serializedData())
    }

    wait(
      for: [
        idleExpectation,
        batteryStatusRequestFailedExpectation,
      ],
      timeout: 1.0,
      enforceOrder: true
    )
  }
}

extension FirmwareUpdateStateMachineTests {

  private func reconnectFakeTag() {
    let connectionStream = JacquardManagerImplementation.connectionStateMachine(
      identifier: centralManager!.uuid
    )
    connectionStream?.connect()
  }

  private func connectFakeTag() {
    let stateExpectation = expectation(description: "StateExpectation")
    let peripheralConnectExpectation = expectation(description: "peripheralConnectExpectation")

    let queue: DispatchQueue = .main
    let jqm = JacquardManagerImplementation(publishQueue: queue, config: config) { delegate in
      centralManager = FakeCentralManager(delegate: delegate, queue: queue, options: nil)
      return centralManager!
    }

    jqm.centralState.sink { state in
      switch state {
      case .poweredOn:
        stateExpectation.fulfill()
      default:
        break
      }
    }.addTo(&observations)

    centralManager?.state = .poweredOn
    wait(for: [stateExpectation], timeout: 1.0)

    // setNotifyFor:Characteristics called for 3 characteristics.
    var characteristicCounter = 3

    centralManager?.peripheral.completionHandler = { peripheral, callbackType in
      switch callbackType {
      case .didDiscoverServices:
        peripheral.callbackType = .didDiscoverCharacteristics
      case .didDiscoverCharacteristics:
        peripheral.callbackType = .didUpdateNotificationState
      case .didUpdateNotificationState:
        if characteristicCounter == 1 {
          peripheral.callbackType = .didWriteValue(.helloCommand)
        } else {
          characteristicCounter -= 1
        }
      case .didWriteValue(let responseType):
        peripheral.callbackType = .didUpdateValue(responseType)
        if responseType == .helloCommand {
          peripheral.postUpdateForHelloCommandResponse()
        } else if responseType == .beginCommand {
          peripheral.postUpdateForBeginCommandResponse()
        } else if responseType == .componentInfoCommand {
          peripheral.postUpdateForComponentInfoResponse()
        }
      case .didUpdateValue(let responseType):
        if responseType == .helloCommand {
          peripheral.callbackType = .didWriteValue(.beginCommand)
        } else if responseType == .beginCommand {
          peripheral.callbackType = .didWriteValue(.componentInfoCommand)
        }
      default:
        break
      }
    }

    connectCancellable = jqm.connect(centralManager!.uuid).sink { error in
      XCTFail("Tag connection error \(error) should not received.")
    } receiveValue: { state in
      switch state {
      case .connected(let tag):
        XCTAssertEqual(tag.name, "Fake Device")
        XCTAssertNotNil(tag.tagComponent.product)
        XCTAssertNotNil(tag.tagComponent.vendor)
        XCTAssertEqual(tag.tagComponent.product.name, TagConstants.product)
        XCTAssertEqual(tag.tagComponent.vendor.name, FakePeripheralImplementation.tagVendorName)
        XCTAssertEqual(tag.tagComponent.version, FakePeripheralImplementation.tagVersion)
        XCTAssertEqual(tag.tagComponent.uuid, FakePeripheralImplementation.tagUUID)

        peripheralConnectExpectation.fulfill()
        self.connectCancellable?.cancel()
        self.connectCancellable = nil
      default:
        break
      }
    }

    wait(for: [peripheralConnectExpectation], timeout: 5.0)
  }

  private func enqueueDFUStatusRequest(_ transport: FakeTransport) {
    let dfuStatusExpectation = expectation(description: "dfuStatusExpectation")

    transport.enqueueRequestHandler = { (request, _, _) in

      // Safe to force unwrap here as the request will always be of type
      // `Google_Jacquard_Protocol_Request`.
      let request = request as! Google_Jacquard_Protocol_Request

      if request.domain == .dfu && request.opcode == .dfuStatus {
        let dfuStatusResponse = Google_Jacquard_Protocol_DFUStatusResponse.with { response in
          response.finalSize = 0
          response.finalCrc = 0
          response.currentSize = 0
          response.currentCrc = 0
        }
        dfuStatusExpectation.fulfill()
        return
          .success(
            FakeDFUCommands.prepareDFUStatusResponse(
              status: .ok,
              dfuStatusResponse: dfuStatusResponse
            )
          )
      } else {
        preconditionFailure()
      }
    }
    wait(for: [dfuStatusExpectation], timeout: 1.0)
  }

  private func enqueueBatteryStatusRequest(
    _ transport: FakeTransport,
    expectation: XCTestExpectation,
    lowBattery: Bool = false
  ) {

    transport.enqueueRequestHandler = { (request, _, _) in

      // Safe to force unwrap here as the request will always be of type
      // `Google_Jacquard_Protocol_Request`.
      let request = request as! Google_Jacquard_Protocol_Request

      if request.domain == .base && request.opcode == .batteryStatus {
        let response = Google_Jacquard_Protocol_Response.with {
          $0.id = 1
          $0.status = .ok
          let battery = Google_Jacquard_Protocol_BatteryStatusResponse.with {
            $0.chargingStatus = .notCharging
            $0.batteryLevel = lowBattery ? 1 : 45
          }
          $0.Google_Jacquard_Protocol_BatteryStatusResponse_batteryStatusResponse = battery
        }
        expectation.fulfill()
        return .success(try! response.serializedData())
      } else {
        preconditionFailure()
      }
    }
  }

  private func enqueueDFUPrepareRequest(_ transport: FakeTransport) {
    let dfuPrepareExpectation = expectation(description: "dfuPrepareExpectation")

    transport.enqueueRequestHandler = { (request, _, _) in

      // Safe to force unwrap here as the request will always be of type
      // `Google_Jacquard_Protocol_Request`.
      let request = request as! Google_Jacquard_Protocol_Request

      if request.domain == .dfu && request.opcode == .dfuPrepare {
        dfuPrepareExpectation.fulfill()
        return .success(FakeDFUCommands.prepareDFUPrepareResponse(status: .ok))
      } else {
        preconditionFailure()
      }
    }
    wait(for: [dfuPrepareExpectation], timeout: 1.0)
  }

  private func enqueueDFUWriteRequest(_ transport: FakeTransport, image: Data) {
    // Assert multiple write requests till entire image is written.
    stride(from: 0, to: image.count, by: FirmwareImageWriterStateMachine.imageChunkSize)
      .forEach { index in
        let offset = min(index + FirmwareImageWriterStateMachine.imageChunkSize, image.count)
        let data = image[index..<offset]
        let expectedWriteRequest = FakeDFUCommands.prepareDFUWriteRequest(
          data: data,
          offset: UInt32(index)
        )
        let dfuWriteRequestExpectation = expectation(description: "dfuWriteRequestExpectation")

        transport.enqueueRequestHandler = { (request, _, _) in

          // Safe to force unwrap here as the request will always be of type
          // `Google_Jacquard_Protocol_Request`.
          let request = request as! Google_Jacquard_Protocol_Request

          if request.domain == .dfu && request.opcode == .dfuWrite {

            XCTAssertEqual(request, expectedWriteRequest, "Incorrect request.")
            dfuWriteRequestExpectation.fulfill()

            let crc = UInt32(CRC16.compute(in: image[0..<offset], seed: 0))
            let writeResponse = Google_Jacquard_Protocol_DFUWriteResponse.with { response in
              response.offset = UInt32(offset)
              response.crc = crc
            }
            return .success(
              FakeDFUCommands.prepareDFUWriteResponse(status: .ok, writeResponse: writeResponse)
            )
          } else {
            preconditionFailure()
          }
        }
        wait(for: [dfuWriteRequestExpectation], timeout: 1.0)
      }
  }

  // Stop update api can be used only when the state machine is on `.preparingForTransfer`,
  // `.transferring` and `.transferred` states.Other than these states there is no mean to use stop
  // functionality.
  func testStopUpdatesStateMachineSuccess() throws {
    throw XCTSkip("b/204121008 | b/240381495 - flaky tests")

    // Connect fake tag before apply update.
    connectFakeTag()

    let transport = FakeTransport()
    let connectedTag = ConnectedTagModel(
      transport: transport,
      userPublishQueue: .main,
      tagComponent: FakeConnectedTag(transport: transport).tagComponent,
      sdkConfig: config
    )
    let image = Data((0..<1000).map { UInt8($0 % 255) })
    let updateInfoTag = DFUUpdateInfo(
      date: "21-06-2016",
      version: "1.0.0",
      dfuStatus: .mandatory,
      vid: "11-78-30-c8",
      pid: "28-3b-e7-a0",
      downloadURL: "https://www.google.com",
      image: image
    )
    let updateStateMachine = FirmwareUpdateStateMachine(
      updates: [updateInfoTag],
      connectedTag: connectedTag,
      shouldAutoExecute: false
    )

    var stopUpdatesCalled = false
    let idleExpectation = expectation(description: "idleExpectation")
    let prepareForTransferExpectation = expectation(description: "prepareForTransferExpectation")
    let transferStoppedExpectation = expectation(description: "transferStoppedExpectation")
    updateStateMachine.statePublisher.sink { state in
      switch state {
      case .idle:
        idleExpectation.fulfill()
      case .preparingForTransfer:
        prepareForTransferExpectation.fulfill()
      case .transferring(let progress):
        // This check is just for interruption to call `stop` update API.
        if progress > ((128 * 4) / 10) {
          do {
            try updateStateMachine.stopUpdates()
            stopUpdatesCalled = true
          } catch let error as NSError {
            XCTFail("Stop updates failed: \(error)")
          }
        }
      case .stopped:
        transferStoppedExpectation.fulfill()
      default:
        XCTFail("Unexpected state \(state)")
      }
    }.addTo(&observations)

    let batteryStatusExpectation = expectation(description: "batteryStatusExpectation")
    enqueueBatteryStatusRequest(transport, expectation: batteryStatusExpectation)
    updateStateMachine.applyUpdates()
    wait(for: [batteryStatusExpectation], timeout: 1.0)

    enqueueDFUStatusRequest(transport)
    enqueueDFUPrepareRequest(transport)

    stride(from: 0, to: image.count, by: FirmwareImageWriterStateMachine.imageChunkSize)
      .forEach { index in
        let offset = min(index + FirmwareImageWriterStateMachine.imageChunkSize, image.count)
        let data = image[index..<offset]
        let expectedWriteRequest = FakeDFUCommands.prepareDFUWriteRequest(
          data: data,
          offset: UInt32(index)
        )
        let dfuWriteRequestExpectation = expectation(description: "dfuWriteRequestExpectation")
        // On calling stop update api, writing process will be stopped.
        // Hence, there won't be further callback for dfu writing process
        // thus write request expectation won't be fulfilled in the callback closure.
        // This flag is denoting that stop api has been called
        // and pending expectations can be fulfilled further.
        if stopUpdatesCalled {
          dfuWriteRequestExpectation.fulfill()
        }
        transport.enqueueRequestHandler = { (request, _, _) in
          // Safe to force unwrap here as the request will always be of type
          // `Google_Jacquard_Protocol_Request`.
          let request = request as! Google_Jacquard_Protocol_Request
          if request.domain == .dfu && request.opcode == .dfuWrite {
            XCTAssertEqual(request, expectedWriteRequest, "Incorrect request.")

            dfuWriteRequestExpectation.fulfill()

            let crc = UInt32(CRC16.compute(in: image[0..<offset], seed: 0))
            let writeResponse = Google_Jacquard_Protocol_DFUWriteResponse.with { response in
              response.offset = UInt32(offset)
              response.crc = crc
            }
            return .success(
              FakeDFUCommands.prepareDFUWriteResponse(status: .ok, writeResponse: writeResponse)
            )
          } else {
            preconditionFailure()
          }
        }
        wait(for: [dfuWriteRequestExpectation], timeout: 1.0)
      }

    wait(
      for: [idleExpectation, prepareForTransferExpectation, transferStoppedExpectation],
      timeout: 1.0,
      enforceOrder: true
    )
  }

  func testStopUpdatesExceptionOnExecutingState() throws {
    throw XCTSkip("b/204121008 | b/240381495 - flaky tests")

    // Connect fake tag before apply update.
    connectFakeTag()

    let transport = FakeTransport()
    let connectedTag = ConnectedTagModel(
      transport: transport,
      userPublishQueue: .main,
      tagComponent: FakeConnectedTag(transport: transport).tagComponent,
      sdkConfig: config
    )
    let image = Data((0..<1000).map { UInt8($0 % 255) })
    let updateInfoTag = DFUUpdateInfo(
      date: "21-06-2016",
      version: "1.0.0",
      dfuStatus: .mandatory,
      vid: "11-78-30-c8",
      pid: "28-3b-e7-a0",
      downloadURL: "https://www.google.com",
      image: image
    )
    let updateStateMachine = FirmwareUpdateStateMachine(
      updates: [updateInfoTag],
      connectedTag: connectedTag,
      shouldAutoExecute: true
    )

    let expectedError =
      FirmwareUpdateError.internalError("Can NOT stop DFU updates on state `executing`.") as NSError
    let idleExpectation = expectation(description: "idleExpectation")
    let prepareForTransferExpectation = expectation(description: "prepareForTransferExpectation")
    let transferredExpectation = expectation(description: "transferredExpectation")
    let stoppedExceptionExpectation = expectation(description: "stopUpdatesExceptionExpectation")
    updateStateMachine.statePublisher.sink { state in
      switch state {
      case .idle:
        idleExpectation.fulfill()
      case .preparingForTransfer:
        prepareForTransferExpectation.fulfill()
      case .transferring(_):
        // We dont have specific count for this state to be fulfill. Hence not setting any
        // expectation here.
        break
      case .transferred:
        transferredExpectation.fulfill()
      case .executing:
        do {
          try updateStateMachine.stopUpdates()
        } catch let error as NSError {
          XCTAssertEqual(error.description, expectedError.description)
          stoppedExceptionExpectation.fulfill()
        }
      case .stopped:
        XCTFail("\(state) state should NOT be called.")
      default:
        XCTFail("Unexpected state \(state)")
      }
    }.addTo(&observations)

    let batteryStatusExpectation = expectation(description: "batteryStatusExpectation")
    enqueueBatteryStatusRequest(transport, expectation: batteryStatusExpectation)
    updateStateMachine.applyUpdates()
    wait(for: [batteryStatusExpectation], timeout: 1.0)

    enqueueDFUStatusRequest(transport)
    enqueueDFUPrepareRequest(transport)
    enqueueDFUWriteRequest(transport, image: image)

    let executeRequestForTagExpectation = expectation(
      description: "executeRequestForTagExpectation")
    transport.enqueueRequestHandler = { (request, _, _) in
      // Safe to force unwrap here as the request will always be of type
      // `Google_Jacquard_Protocol_Request`.
      let request = request as! Google_Jacquard_Protocol_Request
      if request.domain == .dfu && request.opcode == .dfuExecute {
        executeRequestForTagExpectation.fulfill()
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 2.0) {
          self.reconnectFakeTag()
        }
        return .success(FakeDFUCommands.prepareDFUExecuteResponse(status: .ok))
      } else {
        preconditionFailure()
      }
    }

    wait(
      for: [
        idleExpectation,
        prepareForTransferExpectation,
        transferredExpectation,
        stoppedExceptionExpectation,
        executeRequestForTagExpectation,
      ],
      timeout: 1.0,
      enforceOrder: true
    )
  }

  func testExceptionOnStoppingUpdatesWhenNoDFUTransferInProgress() throws {
    throw XCTSkip("b/204121008 | b/240381495 - flaky tests")

    // Connect fake tag before apply update.
    connectFakeTag()

    let transport = FakeTransport()
    let connectedTag = ConnectedTagModel(
      transport: transport,
      userPublishQueue: .main,
      tagComponent: FakeConnectedTag(transport: transport).tagComponent,
      sdkConfig: config
    )
    let image = Data((0..<1000).map { UInt8($0 % 255) })
    let updateInfoTag = DFUUpdateInfo(
      date: "21-06-2016",
      version: "1.0.0",
      dfuStatus: .mandatory,
      vid: "11-78-30-c8",
      pid: "28-3b-e7-a0",
      downloadURL: "https://www.google.com",
      image: image
    )
    let updateStateMachine = FirmwareUpdateStateMachine(
      updates: [updateInfoTag],
      connectedTag: connectedTag,
      shouldAutoExecute: true
    )

    let expectedError =
      FirmwareUpdateError.internalError("Can NOT stop DFU updates on state `idle`.") as NSError
    let canNotStopUpdatesExpectation = expectation(description: "stopUpdatesExceptionExpectation")
    updateStateMachine.statePublisher.sink { state in
      switch state {
      case .idle:
        do {
          try updateStateMachine.stopUpdates()
        } catch let error as NSError {
          XCTAssertEqual(error.description, expectedError.description)
          canNotStopUpdatesExpectation.fulfill()
        }
      default:
        XCTFail("Unexpected state \(state)")
      }
    }.addTo(&observations)

    wait(for: [canNotStopUpdatesExpectation], timeout: 1.0, enforceOrder: true)
  }
}

extension XCTestCase {

  /// Sleep execution for given timeinterval.
  func sleep(_ timeout: TimeInterval) {
    let sleep = expectation(description: "SleepExpectation")
    sleep.isInverted = true
    wait(for: [sleep], timeout: timeout)
  }
}
