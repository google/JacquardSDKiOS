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

extension GetCustomConfigCommand {

  /// :nodoc:
  public var request: V2ProtocolCommandRequestIDInjectable {
    let configGetRequest = Google_Jacquard_Protocol_ConfigGetRequest.with {
      $0.vid = ComponentImplementation.convertToDecimal(vendorID)
      $0.pid = ComponentImplementation.convertToDecimal(productID)
      $0.key = key
    }

    return Google_Jacquard_Protocol_Request.with {
      $0.domain = .base
      $0.opcode = .configGet
      $0.Google_Jacquard_Protocol_ConfigGetRequest_configGetRequest = configGetRequest
    }
  }

  /// :nodoc:
  public func parseResponse(outerProto: Any) -> Result<ConfigValue?, Error> {
    guard let outerProto = outerProto as? Google_Jacquard_Protocol_Response else {
      jqLogger.assert(
        "Calling parseResponse() with anything other than Google_Jacquard_Protocol_Response is an error."
      )
      return .failure(CommandResponseStatus.errorAppUnknown)
    }

    guard outerProto.hasGoogle_Jacquard_Protocol_ConfigGetResponse_configGetResponse else {
      return .failure(JacquardCommandError.malformedResponse)
    }
    let response = outerProto.Google_Jacquard_Protocol_ConfigGetResponse_configGetResponse

    return .success(fetchConfig(from: response))
  }

  private func fetchConfig(
    from response: Google_Jacquard_Protocol_ConfigGetResponse
  ) -> ConfigValue? {
    let configElement = response.config

    if configElement.hasBoolVal {
      return .bool(configElement.boolVal)
    } else if configElement.hasUint32Val {
      return .uint32(configElement.uint32Val)
    } else if configElement.hasUint64Val {
      return .uint64(configElement.uint64Val)
    } else if configElement.hasInt32Val {
      return .int32(configElement.int32Val)
    } else if configElement.hasInt64Val {
      return .int64(configElement.int64Val)
    } else if configElement.hasFloatVal {
      return .float(configElement.floatVal)
    } else if configElement.hasDoubleVal {
      return .double(configElement.doubleVal)
    } else if configElement.hasStringVal {
      return .string(configElement.stringVal)
    }
    return nil
  }
}
