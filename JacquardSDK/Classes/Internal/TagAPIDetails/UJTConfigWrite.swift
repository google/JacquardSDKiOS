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

struct UJTWriteConfigCommand: CommandRequest {

  var request: V2ProtocolCommandRequestIDInjectable {
    return Google_Jacquard_Protocol_Request.with {
      $0.domain = .base
      $0.opcode = .configWrite
      $0.Google_Jacquard_Protocol_UJTConfigWriteRequest_configWrite.bleConfig = config
    }
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

  typealias Response = Void

  let config: Google_Jacquard_Protocol_BleConfiguration
}
