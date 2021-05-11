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

extension DisconnectTagCommand {

  /// :nodoc:
  public var request: V2ProtocolCommandRequestIDInjectable {
    var request = Google_Jacquard_Protocol_Request()
    request.domain = .base
    request.opcode = .requestDisconnect

    let bleDisconnectRequest = Google_Jacquard_Protocol_BleDisconnectRequest(
      timeoutSecond: timeoutSecond,
      reconnectOnlyOnWom: reconnectOnlyOnWom
    )
    request.Google_Jacquard_Protocol_BleDisconnectRequest_bleDisconnectRequest =
      bleDisconnectRequest

    return request
  }

  /// :nodoc:
  public func parseResponse(outerProto: Any) -> Result<Void, Error> {
    guard outerProto is Google_Jacquard_Protocol_Response else {
      return .failure(CommandResponseStatus.errorAppUnknown)
    }
    return .success(())
  }
}

extension Google_Jacquard_Protocol_BleDisconnectRequest {
  init(timeoutSecond: UInt32, reconnectOnlyOnWom: Bool) {
    self.timeoutSecond = timeoutSecond
    self.reconnectOnlyOnWom = reconnectOnlyOnWom
  }
}
