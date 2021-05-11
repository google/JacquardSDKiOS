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

extension BatteryStatusCommand {

  /// :nodoc:
  public func parseResponse(outerProto: Any) -> Result<Response, Error> {
    guard let outerProto = outerProto as? Google_Jacquard_Protocol_Response else {
      jqLogger.assert(
        "calling parseResponse() with anything other than Google_Jacquard_Protocol_Response is an error"
      )
      return .failure(CommandResponseStatus.errorAppUnknown)
    }

    guard outerProto.hasGoogle_Jacquard_Protocol_BatteryStatusResponse_batteryStatusResponse,
      let response = BatteryStatus(
        outerProto.Google_Jacquard_Protocol_BatteryStatusResponse_batteryStatusResponse)
    else {
      return .failure(JacquardCommandError.malformedResponse)
    }

    return .success(response)
  }

  /// :nodoc:
  public var request: V2ProtocolCommandRequestIDInjectable {
    let batteryStatusRequest = Google_Jacquard_Protocol_BatteryStatusRequest.with {
      $0.readBatteryLevel = true
      $0.readChargingStatus = true
    }
    return Google_Jacquard_Protocol_Request.with {
      $0.domain = .base
      $0.opcode = .batteryStatus
      $0.Google_Jacquard_Protocol_BatteryStatusRequest_batteryStatusRequest = batteryStatusRequest
    }
  }

}

extension BatteryStatus.ChargingState {
  init(_ proto: Google_Jacquard_Protocol_ChargingStatus) {
    switch proto {
    case .charging: self = .charging
    case .notCharging: self = .notCharging
    }
  }
}

extension BatteryStatus {
  init?(_ proto: Google_Jacquard_Protocol_BatteryStatusResponse) {
    guard proto.hasBatteryLevel && proto.hasChargingStatus else {
      return nil
    }
    self.init(
      batteryLevel: proto.batteryLevel,
      chargingState: BatteryStatus.ChargingState(proto.chargingStatus))
  }

  init?(_ proto: Google_Jacquard_Protocol_BatteryStatusNotification) {
    guard proto.hasBatteryLevel && proto.hasChargingStatus else {
      return nil
    }
    self.init(
      batteryLevel: proto.batteryLevel,
      chargingState: BatteryStatus.ChargingState(proto.chargingStatus))
  }
}

extension BatteryStatusNotificationSubscription {
  /// :nodoc:
  public func extract(from outerProto: Any) -> BatteryStatus? {
    guard let notification = outerProto as? Google_Jacquard_Protocol_Notification else {
      jqLogger.assert(
        "calling extract() with anything other than Google_Jacquard_Protocol_Notification is an error"
      )
      return nil
    }

    // Silently ignore other notifications.
    guard
      notification.hasGoogle_Jacquard_Protocol_BatteryStatusNotification_batteryStatusNotification
    else {
      return nil
    }

    let innerProto = notification
      .Google_Jacquard_Protocol_BatteryStatusNotification_batteryStatusNotification
    return BatteryStatus(innerProto)
  }
}
