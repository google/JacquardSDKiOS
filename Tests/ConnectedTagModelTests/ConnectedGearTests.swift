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

final class ConnectedGearTests: XCTestCase {
  private var observers = [Cancellable]()

  class FakeTransport: Transport {
    var didWriteCommandPublisher = PassthroughSubject<Error?, Never>().eraseToAnyPublisher()

    private var notificationSubject = PassthroughSubject<
      Google_Jacquard_Protocol_Notification, Never
    >()
    lazy var notificationPublisher = notificationSubject.eraseToAnyPublisher()
    var peripheralNamePublisher = Just<String>("Fake").eraseToAnyPublisher()
    var peripheralName = "Fake"
    var peripheralIdentifier = UUID()

    init() {}

    required init(peripheral: Peripheral, characteristics: RequiredCharacteristics) {
      preconditionFailure()
    }

    func stopCachingNotifications() {}

    func enqueue(
      request: V2ProtocolCommandRequestIDInjectable, type: CharacteristicWriteType, retries: Int,
      callback: @escaping RequestCallback
    ) {
      guard let request = request as? Google_Jacquard_Protocol_Request else {
        preconditionFailure()
      }

      var data: Data

      // Expecting setTouchMode and writeConfig commands during gear attachment.
      if request.domain == .gear && request.opcode == .gearData {
        // Send the expected result for set touch mode.
        let response = Google_Jacquard_Protocol_Response.with { outerProto in
          let inner = Google_Jacquard_Protocol_DataChannelResponse()
          outerProto.Google_Jacquard_Protocol_DataChannelResponse_data = inner
          outerProto.id = 1
          outerProto.status = .ok
        }
        data = try! response.serializedData()
      } else if request.domain == .base && request.opcode == .configWrite {
        let response = Google_Jacquard_Protocol_Response.with {
          $0.id = 1
          $0.status = .ok
        }
        data = try! response.serializedData()
      } else {
        XCTFail("Unexpected request: \(request)")
        return
      }
      DispatchQueue.main.async {
        callback(.success(data))
      }
    }

    func postGearAttach() {
      let notification = Google_Jacquard_Protocol_Notification.with { outerProto in
        let attached = Google_Jacquard_Protocol_AttachedNotification.with {
          $0.attachState = true
          $0.vendorID = 1_957_219_924
          $0.productID = 2_321_961_204
          $0.componentID = 42
        }
        outerProto.Google_Jacquard_Protocol_AttachedNotification_attached = attached
      }
      notificationSubject.send(notification)
    }
  }

  func testConnectedGear() {
    let transport = FakeTransport()
    let connectedTag = ConnectedTagModel(transport: transport, userPublishQueue: .main)

    let expectAttach = expectation(description: "Expecting attachment")
    connectedTag.connectedGear.sink { component in
      XCTAssertEqual(component?.vendor.name, "Levi's")
      expectAttach.fulfill()
    }.addTo(&observers)

    transport.postGearAttach()
    wait(for: [expectAttach], timeout: 1)

    // Ensure attached gear is replayed immediately.

    let expectAttachReplay = expectation(description: "Expecting attachment replay")
    connectedTag.connectedGear.sink { component in
      XCTAssertEqual(component?.vendor.name, "Levi's")
      expectAttachReplay.fulfill()
    }.addTo(&observers)

    wait(for: [expectAttachReplay], timeout: 1)
  }
}
