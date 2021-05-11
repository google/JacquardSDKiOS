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

/// Checks the status of the image if already present any(partial/full) for the specified component.
struct DFUStatusCommand: CommandRequest {

  /// Vendor ID of the component for which DFU has to be performed.
  let vendorID: UInt32
  /// Product ID of the component for which DFU has to be performed.
  let productID: UInt32

  var request: V2ProtocolCommandRequestIDInjectable {
    var request = Google_Jacquard_Protocol_Request()
    request.domain = .dfu
    request.opcode = .dfuStatus

    let dfuStatusRequest = Google_Jacquard_Protocol_DFUStatusRequest(
      vendorID: vendorID,
      productID: productID
    )
    request.Google_Jacquard_Protocol_DFUStatusRequest_dfuStatus = dfuStatusRequest

    return request
  }

  func parseResponse(outerProto: Any) -> Result<Google_Jacquard_Protocol_DFUStatusResponse, Error> {
    guard let outerProto = outerProto as? Google_Jacquard_Protocol_Response else {
      jqLogger.assert(
        "calling parseResponse() with anything other than Google_Jacquard_Protocol_Response is an error"
      )
      return .failure(CommandResponseStatus.errorAppUnknown)
    }
    guard outerProto.hasGoogle_Jacquard_Protocol_DFUStatusResponse_dfuStatus else {
      return .failure(JacquardCommandError.malformedResponse)
    }
    return .success((outerProto.Google_Jacquard_Protocol_DFUStatusResponse_dfuStatus))
  }
}

/// Prepares for uploading the image for the specified component.
struct DFUPrepareCommand: CommandRequest {

  /// Vendor ID of the component for which DFU has to be performed.
  let vendorID: UInt32
  /// Product ID of the component for which DFU has to be performed.
  let productID: UInt32
  /// ID of the component for which DFU has to be performed.
  let componentID: UInt32
  /// CRC for the image to be used for the DFU.
  let finalCrc: UInt32
  /// Final size of the image to be used for the DFU.
  let finalSize: UInt32

  var request: V2ProtocolCommandRequestIDInjectable {
    var request = Google_Jacquard_Protocol_Request()
    request.domain = .dfu
    request.opcode = .dfuPrepare

    let dfuPrepareRequest = Google_Jacquard_Protocol_DFUPrepareRequest(
      vendorID: vendorID,
      productID: productID,
      componentID: componentID,
      finalCrc: finalCrc,
      finalSize: finalSize
    )
    request.Google_Jacquard_Protocol_DFUPrepareRequest_dfuPrepare = dfuPrepareRequest

    return request
  }

  func parseResponse(outerProto: Any) -> Result<Void, Error> {
    guard outerProto is Google_Jacquard_Protocol_Response else {
      jqLogger.assert(
        "calling parseResponse() with anything other than Google_Jacquard_Protocol_Response is an error"
      )
      return .failure(CommandResponseStatus.errorAppUnknown)
    }
    return .success(())
  }
}

/// Writes the data chunk from the image being uploaded.
struct DFUWriteCommand: CommandRequest {

  /// Image data chunk to be transferred over the BLE.
  let data: Data
  /// Offset at which the data chunk has to be written.
  let offset: UInt32

  var request: V2ProtocolCommandRequestIDInjectable {
    var request = Google_Jacquard_Protocol_Request()
    request.domain = .dfu
    request.opcode = .dfuWrite

    let dfuWriteRequest = Google_Jacquard_Protocol_DFUWriteRequest(
      data: data,
      offset: offset
    )
    request.Google_Jacquard_Protocol_DFUWriteRequest_dfuWrite = dfuWriteRequest

    return request
  }

  func parseResponse(outerProto: Any) -> Result<Google_Jacquard_Protocol_DFUWriteResponse, Error> {
    guard let outerProto = outerProto as? Google_Jacquard_Protocol_Response else {
      jqLogger.assert(
        "calling parseResponse() with anything other than Google_Jacquard_Protocol_Response is an error"
      )
      return .failure(CommandResponseStatus.errorAppUnknown)
    }
    guard outerProto.hasGoogle_Jacquard_Protocol_DFUWriteResponse_dfuWrite else {
      return .failure(JacquardCommandError.malformedResponse)
    }
    return .success((outerProto.Google_Jacquard_Protocol_DFUWriteResponse_dfuWrite))
  }
}

/// Executes the uploaded image for the specified component.
struct DFUExecuteCommand: CommandRequest {

  /// Vendor ID of the component for which DFU has to be performed.
  let vendorID: UInt32
  /// Product ID of the component for which DFU has to be performed.
  let productID: UInt32

  var request: V2ProtocolCommandRequestIDInjectable {
    var request = Google_Jacquard_Protocol_Request()
    request.domain = .dfu
    request.opcode = .dfuExecute

    var dfuExecuteRequest = Google_Jacquard_Protocol_DFUExecuteRequest(
      vendorID: vendorID,
      productID: productID
    )
    dfuExecuteRequest.updateSched = Google_Jacquard_Protocol_UpdateSchedule.updateNow
    request.Google_Jacquard_Protocol_DFUExecuteRequest_dfuExecute = dfuExecuteRequest

    return request
  }

  func parseResponse(outerProto: Any) -> Result<Void, Error> {
    guard outerProto is Google_Jacquard_Protocol_Response else {
      jqLogger.assert(
        "calling parseResponse() with anything other than Google_Jacquard_Protocol_Response is an error"
      )
      return .failure(CommandResponseStatus.errorAppUnknown)
    }
    return .success(())
  }
}

extension Google_Jacquard_Protocol_DFUStatusRequest {
  init(vendorID: UInt32, productID: UInt32) {
    self.vendorID = vendorID
    self.productID = productID
  }
}

extension Google_Jacquard_Protocol_DFUPrepareRequest {

  init(
    vendorID: UInt32,
    productID: UInt32,
    componentID: UInt32,
    finalCrc: UInt32,
    finalSize: UInt32
  ) {
    self.vendorID = vendorID
    self.productID = productID
    self.component = componentID
    self.finalCrc = finalCrc
    self.finalSize = finalSize
  }
}

extension Google_Jacquard_Protocol_DFUWriteRequest {
  init(data: Data, offset: UInt32) {
    self.data = data
    self.offset = offset
  }
}

extension Google_Jacquard_Protocol_DFUExecuteRequest {
  init(vendorID: UInt32, productID: UInt32) {
    self.vendorID = vendorID
    self.productID = productID
  }
}
