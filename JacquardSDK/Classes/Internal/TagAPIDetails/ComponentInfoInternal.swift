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

extension ComponentInfoCommand {

  /// :nodoc:
  public var request: V2ProtocolCommandRequestIDInjectable {
    var request = Google_Jacquard_Protocol_Request()
    request.domain = .base
    request.opcode = .deviceinfo
    request.componentID = componentID

    let deviceInfoRequest = Google_Jacquard_Protocol_DeviceInfoRequest(componentID: componentID)
    request.Google_Jacquard_Protocol_DeviceInfoRequest_deviceInfo = deviceInfoRequest

    return request
  }

  /// :nodoc:
  public func parseResponse(outerProto: Any) -> Result<ComponentInfo, Error> {
    guard let outerProto = outerProto as? Google_Jacquard_Protocol_Response else {
      jqLogger.assert(
        "Calling parseResponse() with anything other than Google_Jacquard_Protocol_Response is an error."
      )
      return .failure(CommandResponseStatus.errorAppUnknown)
    }

    guard outerProto.hasGoogle_Jacquard_Protocol_DeviceInfoResponse_deviceInfo
    else {
      return .failure(JacquardCommandError.malformedResponse)
    }
    let info = outerProto.Google_Jacquard_Protocol_DeviceInfoResponse_deviceInfo
    let firmwareVersion = "\(info.firmwareMajor).\(info.firmwareMinor).\(info.firmwarePoint)"

    return .success((ComponentInfo(version: firmwareVersion)))
  }
}

extension Google_Jacquard_Protocol_DeviceInfoRequest {
  init(componentID: UInt32) {
    self.component = componentID
  }
}
