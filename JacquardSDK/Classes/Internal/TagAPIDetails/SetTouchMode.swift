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

/// Note that this only sets the inference mode, the command to change the notification queue depth must be sent separately.
struct SetTouchModeCommand: CommandRequest {
  typealias Response = Void

  var component: Component
  var mode: TouchMode

  func parseResponse(outerProto: Any) -> Result<Response, Error> {
    guard let outerProto = outerProto as? Google_Jacquard_Protocol_Response else {
      jqLogger.assert(
        "calling parseResponse() with anything other than Google_Jacquard_Protocol_Response is an error"
      )
      return .failure(CommandResponseStatus.errorAppUnknown)
    }

    guard outerProto.hasGoogle_Jacquard_Protocol_DataChannelResponse_data else {
      return .failure(CommandResponseStatus.errorAppUnknown)
    }

    return .success(())
  }

  var request: V2ProtocolCommandRequestIDInjectable {
    var dataChannelRequest = Google_Jacquard_Protocol_DataChannelRequest()
    switch mode {
    case .gesture:
      dataChannelRequest.inference = .dataStreamEnable
      dataChannelRequest.touch = .dataStreamDisable
    case .continuous:
      dataChannelRequest.inference = .dataStreamDisable
      dataChannelRequest.touch = .dataStreamEnable
    }

    return Google_Jacquard_Protocol_Request.with {
      $0.domain = .gear
      $0.opcode = .gearData
      $0.componentID = component.componentID
      $0.Google_Jacquard_Protocol_DataChannelRequest_data = dataChannelRequest
    }
  }

}
