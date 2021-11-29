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

class FirmwareUpdateManagerTests: XCTestCase {

  struct CatchLogger: Logger {
    func log(
      level: LogLevel, file: StaticString, line: UInt, function: String, message: () -> String
    ) {
      let _ = message()
      if level == .assertion {
        expectation.fulfill()
      }
    }

    var expectation: XCTestExpectation
  }

  private var observations = [Cancellable]()
  private var centralManager: FakeCentralManager?
  private var connectCancellable: Cancellable?

  private var fakeTagComponent: FakeTagComponent {

    // LED capability for tag.
    guard let capability = GearMetadata.Capability(rawValue: 0) else {
      preconditionFailure("LED capability is not available.")
    }

    var product = GearMetadata.GearData.Product()
    product.id = TagConstants.product
    product.name = TagConstants.product
    product.capabilities = [capability]

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

  private var gearComponent: Component {
    let product = GearMetadata.GearData.Product.with {
      $0.id = "8a-66-50-f4"
      $0.name = "8a-66-50-f4"
      $0.image = "Levi's"
      $0.capabilities = [.led]
    }
    let vendor = GearMetadata.GearData.Vendor.with {
      $0.id = "74-a8-ce-54"
      $0.name = "74-a8-ce-54"
      $0.products = [product]
    }
    return ComponentImplementation(
      componentID: 1,
      vendor: vendor,
      product: product,
      isAttached: true,
      version: Version(major: 1, minor: 0, micro: 0)
    )
  }

  override func setUp() {
    super.setUp()

    let logger = PrintLogger(
      logLevels: [.warning, .assertion, .preconditionFailure],
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

  func testCheckFirmwareUpdateWhileTagConnect() {
    let firmwareUpdateExpectation = expectation(description: "firmwareUpdateExpectation")

    let connectedTag = FakeConnectedTag(transport: FakeTransport())
    connectedTag.firmwareUpdateManager.checkUpdates(forceCheck: true)
      .sink { completion in
        if case .failure(let error) = completion {
          XCTFail("Firmware check update failed with error \(error)")
        }
      } receiveValue: { updates in
        XCTAssert(updates.count == 1)
        firmwareUpdateExpectation.fulfill()
      }.addTo(&self.observations)

    wait(for: [firmwareUpdateExpectation], timeout: 1.0)
  }

  func testCheckUpdateWithFakeComponent() {
    let checkUpdateFailureExpectation = expectation(description: "checkUpdateFailureExpectation")
    let assertExpectation = expectation(description: "assertExpectation")
    jqLogger = CatchLogger(expectation: assertExpectation)

    let connectedTag = FakeConnectedTag(transport: FakeTransport())
    connectedTag.component = fakeTagComponent
    connectedTag.firmwareUpdateManager.checkUpdates(forceCheck: true)
      .sink { completion in
        if case .failure(let error) = completion {
          XCTAssertNotNil(error)
          checkUpdateFailureExpectation.fulfill()
        }
      } receiveValue: { updates in
        XCTFail("Update info success should not call.")
      }.addTo(&self.observations)

    wait(for: [assertExpectation, checkUpdateFailureExpectation], timeout: 1.0)
  }

  func testCheckFirmwareUpdateWhileTagAttached() {
    let firmwareUpdateExpectation = expectation(description: "firmwareUpdateExpectation")
    let connectedTag = FakeConnectedTag(transport: FakeTransport())
    connectedTag.gearComponent = gearComponent
    connectedTag.firmwareUpdateManager.checkUpdates(forceCheck: true)
      .sink { completion in
        if case .failure(let error) = completion {
          XCTFail("Firmware check update failed with error \(error)")
        }
      } receiveValue: { updates in
        XCTAssert(updates.count == 2)
        firmwareUpdateExpectation.fulfill()
      }.addTo(&self.observations)

    wait(for: [firmwareUpdateExpectation], timeout: 1.0)
  }

  func testCheckModuleUpdate() {
    let firmwareUpdateExpectation = expectation(description: "firmwareUpdateExpectation")
    let module = Module(
      name: "IMU module",
      moduleID: 1_024_190_291,
      vendorID: 293_089_480,
      productID: 4_013_841_288,
      version: nil,
      isEnabled: false
    )

    let connectedTag = FakeConnectedTag(transport: FakeTransport())
    connectedTag.firmwareUpdateManager.checkModuleUpdate(module, forceCheck: true)
      .sink { completion in
        if case .failure(let error) = completion {
          XCTFail("Firmware check update failed with error \(error)")
        }
      } receiveValue: { updates in
        firmwareUpdateExpectation.fulfill()
      }.addTo(&self.observations)

    wait(for: [firmwareUpdateExpectation], timeout: 5.0)
  }

  func testApplyAndExecuteUpdate() {
    // Connect fake tag before apply update.
    connectFakeTag()

    let batteryStatusExpectation = expectation(description: "batteryStatusExpectation")
    let dfuStatusExpectation = expectation(description: "dfuStatusExpectation")
    let dfuPrepareExpectation = expectation(description: "dfuPrepareExpectation")
    let applyUpdateExpectation = expectation(description: "applyUpdateExpectation")
    let executeUpdateExpectation = expectation(description: "executeUpdateExpectation")
    let stateApiExpectation = expectation(description: "stateApiExpectation")
    let repeatApplyUpdateCallExpectation = expectation(
      description: "repeatApplyUpdateCallExpectation"
    )

    let image = Data((0..<1000).map { UInt8($0 % 255) })
    let updateInfo = DFUUpdateInfo(
      date: "21-06-2016",
      version: "1.0.0",
      dfuStatus: .none,
      vid: "11-78-30-c8",
      pid: "28-3b-e7-a0",
      downloadURL: "https://www.google.com",
      image: image
    )

    let transport = FakeTransport()
    transport.enqueueRequestHandler = { (request, _, _) in

      // Safe to force unwrap here as the request will always be of type
      // `Google_Jacquard_Protocol_Request`.
      let request = request as! Google_Jacquard_Protocol_Request

      if request.domain == .dfu && request.opcode == .dfuStatus {
        let expectedStatusRequest = FakeDFUCommands.prepareDFUStatusRequest(
          vid: "11-78-30-c8", pid: "28-3b-e7-a0")

        XCTAssertEqual(request, expectedStatusRequest, "Incorrect status request")

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
      } else if request.domain == .dfu && request.opcode == .dfuPrepare {
        let expectedPrepareRequest = FakeDFUCommands.prepareDFUPrepareRequest(
          componentID: 0, vid: "11-78-30-c8", pid: "28-3b-e7-a0", image: image)

        XCTAssertEqual(request, expectedPrepareRequest, "Incorrect prepare request")
        dfuPrepareExpectation.fulfill()
        return .success(FakeDFUCommands.prepareDFUPrepareResponse(status: .ok))
      } else if request.domain == .base && request.opcode == .batteryStatus {

        let response = Google_Jacquard_Protocol_Response.with {
          $0.id = 1
          $0.status = .ok
          let battery = Google_Jacquard_Protocol_BatteryStatusResponse.with {
            $0.chargingStatus = .notCharging
            $0.batteryLevel = 45
          }
          $0.Google_Jacquard_Protocol_BatteryStatusResponse_batteryStatusResponse = battery
        }
        batteryStatusExpectation.fulfill()
        return .success(try! response.serializedData())
      } else {
        preconditionFailure()
      }
    }

    let connectedTag = ConnectedTagModel(
      transport: transport,
      userPublishQueue: .main,
      tagComponent: FakeConnectedTag(transport: transport).tagComponent,
      sdkConfig: config
    )

    connectedTag.firmwareUpdateManager.state.sink { state in
      if case .completed = state {
        stateApiExpectation.fulfill()
      }
    }.addTo(&observations)

    connectedTag.firmwareUpdateManager.applyUpdates(
      [updateInfo],
      shouldAutoExecute: false
    )
    .sink { state in
      if case .transferred = state {
        applyUpdateExpectation.fulfill()
      } else if case .completed = state {
        executeUpdateExpectation.fulfill()
      }
    }.addTo(&observations)

    connectedTag.firmwareUpdateManager.applyUpdates(
      [updateInfo],
      shouldAutoExecute: false
    )
    .sink { state in
      if case .error(let error) = state, case .invalidState(_) = error {
        repeatApplyUpdateCallExpectation.fulfill()
      }
    }.addTo(&observations)

    wait(
      for: [
        batteryStatusExpectation,
        dfuStatusExpectation,
        dfuPrepareExpectation,
        repeatApplyUpdateCallExpectation,
      ],
      timeout: 1.0,
      enforceOrder: false
    )

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
    wait(for: [applyUpdateExpectation], timeout: 1.0)

    transport.enqueueRequestHandler = { (request, _, _) in

      // Safe to force unwrap here as the request will always be of type
      // `Google_Jacquard_Protocol_Request`.
      let request = request as! Google_Jacquard_Protocol_Request

      if request.domain == .dfu && request.opcode == .dfuExecute {
        let expectedStatusRequest = FakeDFUCommands.prepareExecuteRequest(
          vid: "11-78-30-c8", pid: "28-3b-e7-a0")

        XCTAssertEqual(request, expectedStatusRequest, "Incorrect status request")
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
          self.reconnectFakeTag()
        }
        let dfuExecuteResponse = Google_Jacquard_Protocol_Response.with { response in
          response.status = .ok
          response.id = 1
        }
        return .success(try! dfuExecuteResponse.serializedData())
      } else {
        preconditionFailure()
      }
    }
    connectedTag.firmwareUpdateManager.executeUpdates()

    wait(for: [executeUpdateExpectation, stateApiExpectation], timeout: 5.0)
  }

  func testApplyModuleUpdate() {
    connectFakeTag()

    let batteryStatusExpectation = expectation(description: "batteryStatusExpectation")
    let dfuStatusExpectation = expectation(description: "dfuStatusExpectation")
    let dfuPrepareExpectation = expectation(description: "dfuPrepareExpectation")
    let applyUpdateExpectation = expectation(description: "applyUpdateExpectation")
    let moduleUpdateExpectation = expectation(description: "moduleUpdateExpectation")
    let image = Data((0..<1000).map { UInt8($0 % 255) })
    let updateInfo = DFUUpdateInfo(
      date: "21-06-2016",
      version: "5.6.7",
      dfuStatus: .none,
      vid: "11-78-30-c8",
      pid: "ef-3e-5b-88",
      mid: "3d-0b-e7-53",
      downloadURL: "https://www.google.com",
      image: image
    )

    let transport = FakeTransport()
    transport.enqueueRequestHandler = { (request, _, _) in

      // Safe to force unwrap here as the request will always be of type
      // `Google_Jacquard_Protocol_Request`.
      let request = request as! Google_Jacquard_Protocol_Request

      if request.domain == .dfu && request.opcode == .dfuStatus {
        let expectedStatusRequest = FakeDFUCommands.prepareDFUStatusRequest(
          vid: "11-78-30-c8", pid: "ef-3e-5b-88")

        XCTAssertEqual(request, expectedStatusRequest, "Incorrect status request")

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
      } else if request.domain == .dfu && request.opcode == .dfuPrepare {
        let expectedPrepareRequest = FakeDFUCommands.prepareDFUPrepareRequest(
          componentID: 0, vid: "11-78-30-c8", pid: "ef-3e-5b-88", image: image)

        XCTAssertEqual(request, expectedPrepareRequest, "Incorrect prepare request")
        dfuPrepareExpectation.fulfill()
        return .success(FakeDFUCommands.prepareDFUPrepareResponse(status: .ok))
      } else if request.domain == .base && request.opcode == .batteryStatus {
        let response = Google_Jacquard_Protocol_Response.with {
          $0.id = 1
          $0.status = .ok
          let battery = Google_Jacquard_Protocol_BatteryStatusResponse.with {
            $0.chargingStatus = .notCharging
            $0.batteryLevel = 45
          }
          $0.Google_Jacquard_Protocol_BatteryStatusResponse_batteryStatusResponse = battery
        }
        batteryStatusExpectation.fulfill()
        return .success(try! response.serializedData())
      } else {
        preconditionFailure()
      }
    }

    let connectedTag = ConnectedTagModel(
      transport: transport,
      userPublishQueue: .main,
      tagComponent: FakeConnectedTag(transport: transport).tagComponent,
      sdkConfig: config
    )

    connectedTag.firmwareUpdateManager.applyModuleUpdate(updateInfo).sink { state in
      if case .transferred = state {
        applyUpdateExpectation.fulfill()
      } else if case .completed = state {
        moduleUpdateExpectation.fulfill()
      }
    }.addTo(&observations)

    let expectations = [batteryStatusExpectation, dfuStatusExpectation, dfuPrepareExpectation]
    wait(for: expectations, timeout: 5.0)

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
        wait(for: [dfuWriteRequestExpectation], timeout: 5.0)
      }
    wait(for: [applyUpdateExpectation, moduleUpdateExpectation], timeout: 5.0)
  }
}

extension FirmwareUpdateManagerTests {

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
    let jacquardManagerImpl = JacquardManagerImplementation(publishQueue: queue, config: config) {
      delegate in
      centralManager = FakeCentralManager(delegate: delegate, queue: queue, options: nil)
      return centralManager!
    }

    jacquardManagerImpl.centralState.sink { state in
      switch state {
      case .poweredOn:
        stateExpectation.fulfill()
      default:
        break
      }
    }.addTo(&observations)

    centralManager?.state = .poweredOn
    wait(for: [stateExpectation], timeout: 1.0)

    // setNotifyFor:Characteristics called for 2 characteristics.
    var characteristicCounter = 2

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

    connectCancellable = jacquardManagerImpl.connect(centralManager!.uuid).sink { error in
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
}
