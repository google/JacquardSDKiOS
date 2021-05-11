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

@testable import JacquardSDK

struct FakeDFUCommands {

  static func prepareDFUStatusRequest(
    vid: String,
    pid: String
  ) -> Google_Jacquard_Protocol_Request {
    return Google_Jacquard_Protocol_Request.with { request in
      request.domain = .dfu
      request.opcode = .dfuStatus

      request.Google_Jacquard_Protocol_DFUStatusRequest_dfuStatus =
        Google_Jacquard_Protocol_DFUStatusRequest.with { statusDFURequest in
          statusDFURequest.vendorID = ComponentImplementation.convertToDecimal(vid)
          statusDFURequest.productID = ComponentImplementation.convertToDecimal(pid)
        }
    }
  }

  static func prepareDFUStatusResponse(
    status: Google_Jacquard_Protocol_Status,
    dfuStatusResponse: Google_Jacquard_Protocol_DFUStatusResponse?
  ) -> Data {
    let response = Google_Jacquard_Protocol_Response.with { response in
      response.status = status
      response.id = 1

      if let dfuStatusResponse = dfuStatusResponse {
        response.Google_Jacquard_Protocol_DFUStatusResponse_dfuStatus = dfuStatusResponse
      }
    }
    return try! response.serializedData()
  }

  static func prepareDFUPrepareRequest(
    componentID: UInt32,
    vid: String,
    pid: String,
    image: Data
  ) -> Google_Jacquard_Protocol_Request {
    return Google_Jacquard_Protocol_Request.with { request in
      request.domain = .dfu
      request.opcode = .dfuPrepare

      return request.Google_Jacquard_Protocol_DFUPrepareRequest_dfuPrepare =
        Google_Jacquard_Protocol_DFUPrepareRequest.with { prepareRequest in
          prepareRequest.component = componentID
          prepareRequest.finalCrc = UInt32(CRC16.compute(in: image, seed: 0))
          prepareRequest.finalSize = UInt32(image.count)
          prepareRequest.vendorID = ComponentImplementation.convertToDecimal(vid)
          prepareRequest.productID = ComponentImplementation.convertToDecimal(pid)
        }
    }
  }

  static func prepareDFUPrepareResponse(status: Google_Jacquard_Protocol_Status) -> Data {
    let response = Google_Jacquard_Protocol_Response.with { response in
      response.status = status
      response.id = 1
    }
    return try! response.serializedData()
  }

  static func prepareDFUWriteRequest(data: Data, offset: UInt32)
    -> Google_Jacquard_Protocol_Request
  {
    return Google_Jacquard_Protocol_Request.with { request in
      request.domain = .dfu
      request.opcode = .dfuWrite

      request.Google_Jacquard_Protocol_DFUWriteRequest_dfuWrite =
        Google_Jacquard_Protocol_DFUWriteRequest.with { writeRequest in
          writeRequest.data = data
          writeRequest.offset = offset
        }
    }
  }

  static func prepareDFUWriteResponse(
    status: Google_Jacquard_Protocol_Status,
    writeResponse: Google_Jacquard_Protocol_DFUWriteResponse?
  ) -> Data {
    let response = Google_Jacquard_Protocol_Response.with { response in
      response.status = status
      response.id = 1
      if let writeResponse = writeResponse {
        response.Google_Jacquard_Protocol_DFUWriteResponse_dfuWrite = writeResponse
      }
    }
    return try! response.serializedData()
  }

  static func prepareExecuteRequest(vid: String, pid: String) -> Google_Jacquard_Protocol_Request {
    return Google_Jacquard_Protocol_Request.with { request in
      request.domain = .dfu
      request.opcode = .dfuExecute

      request.Google_Jacquard_Protocol_DFUExecuteRequest_dfuExecute =
        Google_Jacquard_Protocol_DFUExecuteRequest.with { dfuExecuteRequest in
          dfuExecuteRequest.vendorID = ComponentImplementation.convertToDecimal(vid)
          dfuExecuteRequest.productID = ComponentImplementation.convertToDecimal(pid)
          dfuExecuteRequest.updateSched = Google_Jacquard_Protocol_UpdateSchedule.updateNow
        }
    }
  }

  static func prepareDFUExecuteResponse(status: Google_Jacquard_Protocol_Status) -> Data {
    let response = Google_Jacquard_Protocol_Response.with { response in
      response.status = status
      response.id = 1
    }
    return try! response.serializedData()
  }
}
