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

extension SetCustomConfigCommand {

  /// :nodoc:
  public var request: V2ProtocolCommandRequestIDInjectable {
    return Google_Jacquard_Protocol_Request.with {
      $0.domain = .base
      $0.opcode = .configSet
      $0.Google_Jacquard_Protocol_ConfigSetRequest_configSetRequest = configSetRequest()
    }
  }

  /// :nodoc:
  public func parseResponse(outerProto: Any) -> Result<Void, Error> {
    guard outerProto is Google_Jacquard_Protocol_Response else {
      jqLogger.assert(
        "calling parseResponse() with anything other than Google_Jacquard_Protocol_Response is an error"
      )
      return .failure(CommandResponseStatus.errorAppUnknown)
    }
    return .success(())
  }

  private func configSetRequest() -> Google_Jacquard_Protocol_ConfigSetRequest {
    var configElement = Google_Jacquard_Protocol_ConfigElement()
    configElement.key = config.key

    switch config.value {
    case .bool(let value):
      configElement.boolVal = value
    case .uint32(let value):
      configElement.uint32Val = value
    case .uint64(let value):
      configElement.uint64Val = value
    case .int32(let value):
      configElement.int32Val = value
    case .int64(let value):
      configElement.int64Val = value
    case .float(let value):
      configElement.floatVal = value
    case .double(let value):
      configElement.doubleVal = value
    case .string(let value):
      configElement.stringVal = value
    }

    let request = Google_Jacquard_Protocol_ConfigSetRequest.with {
      $0.vid = ComponentImplementation.convertToDecimal(config.vendorID)
      $0.pid = ComponentImplementation.convertToDecimal(config.productID)
      $0.config = configElement
    }
    return request
  }
}
