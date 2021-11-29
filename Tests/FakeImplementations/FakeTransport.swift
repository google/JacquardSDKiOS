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

class FakeTransport: Transport {
  var peripheralRSSIPublisher = PassthroughSubject<Float, Never>().eraseToAnyPublisher()
  var didWriteCommandPublisher = PassthroughSubject<Error?, Never>().eraseToAnyPublisher()
  var rawDataPublisher: AnyPublisher<Data, Never> {
    return Just<Data>(Data()).eraseToAnyPublisher()
  }
  var rawBytesPublisher: AnyPublisher<[UInt8], Never> {
    return Just<[UInt8]>([UInt8]()).eraseToAnyPublisher()
  }

  private var notificationSubject = PassthroughSubject<
    Google_Jacquard_Protocol_Notification, Never
  >()
  lazy var notificationPublisher = notificationSubject.eraseToAnyPublisher()
  var peripheralNamePublisher = Just<String>("Fake").eraseToAnyPublisher()
  var peripheralName = "Fake"
  var peripheralIdentifier = UUID(uuidString: "BD415750-8EF1-43EE-8A7F-7EF1E365C35E")!

  var enqueueRequestHandler:
    ((V2ProtocolCommandRequestIDInjectable, CharacteristicWriteType, Int) -> Result<Data, Error>)?

  init() {}

  required init(peripheral: Peripheral, characteristics: RequiredCharacteristics) {
    preconditionFailure()
  }

  func stopCachingNotifications() {}
  func readRSSI() {}

  func enqueue(
    request: V2ProtocolCommandRequestIDInjectable,
    type: CharacteristicWriteType,
    retries: Int,
    requestTimeout: TimeInterval,
    callback: @escaping RequestCallback
  ) {

    if let handler = enqueueRequestHandler {
      DispatchQueue.main.async {
        callback(handler(request, type, retries))
      }
    } else {

      guard let request = request as? Google_Jacquard_Protocol_Request else {
        preconditionFailure()
      }

      var data: Data

      // Expecting setTouchMode, writeConfig and device info commands during gear attachment.
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
      } else if request.domain == .gear && request.opcode == .gearInfo {
        // Send the expected result for device info request.
        let response = Google_Jacquard_Protocol_Response.with { outerProto in
          var inner = Google_Jacquard_Protocol_DeviceInfoResponse()
          inner.firmwareMajor = 1
          inner.firmwareMinor = 2
          inner.firmwarePoint = 3
          inner.uuid = "123456789"
          inner.vendor = "Levi's"
          inner.model = "Backpack"
          inner.revision = 1
          inner.bootloaderMajor = 1
          inner.bootloaderMinor = 2
          inner.bootloaderPoint = 3
          inner.vendorID = 11
          inner.productID = 22
          inner.gearID = "33"
          inner.skuID = "44"
          inner.mlVersion = "55"

          outerProto.Google_Jacquard_Protocol_DeviceInfoResponse_deviceInfo = inner
          outerProto.id = 1
          outerProto.status = .ok
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

  func postDFUExecute() {
    let notification = Google_Jacquard_Protocol_Notification.with { notification in
      notification.Google_Jacquard_Protocol_DFUExecuteUpdateNotification_dfuExecuteUdpateNotif =
        Google_Jacquard_Protocol_DFUExecuteUpdateNotification.with { dfuExecuteNotification in
          dfuExecuteNotification.status = .ok
        }
    }
    notificationSubject.send(notification)
  }
}
