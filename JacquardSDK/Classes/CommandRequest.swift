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

/// Types that implement this protocol describe a command request and its associated response type.
///
/// - SeeAlso: `Commands`
public protocol CommandRequest {
  /// The type that will be returned in the case of successful command execution.
  associatedtype Response

  /// Creates the request payload.
  var request: V2ProtocolCommandRequestIDInjectable { get }

  /// Parses the response payload and, if successful, creates a response of type `Response`.
  func parseResponse(outerProto: Any) -> Result<Response, Error>

  /// Parses the outer response payload and, if status == .ok, creates a protobuf response type.
  func parseOuterResponse(data: Data) -> Result<V2ProtocolCommandResponseInjectable, Error>

  /// Used  by `JacquardManager` to check if the outer proto error should be ignored while parsing
  /// command response.
  func ignoreResponseErrorChecks() -> Bool
}

/// Extension for CommandRequest that holds a default implementation for `ignoreResponseErrorChecks`.
extension CommandRequest {
  public func ignoreResponseErrorChecks() -> Bool { false }
}

/// The possible errors published by a command.
public enum JacquardCommandError: Error {
  /// The firmware reported an error.
  ///
  /// Inspect the associated status for more information on the error.
  case commandFailed(CommandResponseStatus)
  /// The Bluetooth response contained invalid data.
  case malformedResponse
}

/// The possible failure responses from a command.
public enum CommandResponseStatus: Int, Error {
  /// The domain or opcode is unsupported.
  case errorUnsupported = 1

  /// The parameters to this command were incorrect/invalid.
  case errorBadParam = 2

  /// The device has a critically low battery and will not execute the command.
  case errorBattery = 3

  /// We have experienced a failure in some hardware component.
  case errorHardware = 4

  /// The key in an authentication call was incorrect, or there has been
  /// no authentication yet and this call must happen on an authenticated
  /// connection.
  case errorAuth = 5

  /// The device has an invalid device type.
  case errorDeviceTypeInfo = 6

  /// Invalid state to perform requested operation.
  case errorInvalidState = 7

  /// Error accessing Flash for either read/write or erase operation request.
  case errorFlashAccess = 8

  /// Checksum error.
  case errorChecksum = 9

  /// Error Busy - e.g. Busy updating Interposer FW.
  case errorBusy = 10

  /// Flash memory less than 20% free
  case errorLowMemory = 15

  /// Error Generated in APP only
  case errorAppTimeout = 253

  /// Error Generated in APP only
  case errorAppUnknown = 254

  /// Some internal, unknown error has occurred.
  case errorUnknown = 255
}

/// Opaque type representing a command payload to be sent to the tag over Bluetooth.
///
/// :nodoc:
public protocol V2ProtocolCommandRequestIDInjectable {
  var id: UInt32 { get set }
  func serializedData(partial: Bool) throws -> Data
}

/// Opaque type representing a command response payload get from Bluetooth.
///
/// :nodoc:
public protocol V2ProtocolCommandResponseInjectable {}

/// Opaque type representing a notification payload get from Bluetooth.
///
/// :nodoc:
public protocol V2ProtocolNotificationInjectable {}

extension CommandRequest {

  public func parseOuterResponse(data: Data) -> Result<V2ProtocolCommandResponseInjectable, Error> {
    do {
      let outerProto = try Google_Jacquard_Protocol_Response(
        serializedData: data, extensions: Google_Jacquard_Protocol_Jacquard_Extensions)
      guard outerProto.status == .ok || ignoreResponseErrorChecks() else {
        let error =
          CommandResponseStatus(rawValue: outerProto.status.rawValue)
          ?? CommandResponseStatus.errorAppUnknown
        return .failure(error)
      }
      return .success(outerProto)
    } catch (let error) {
      return .failure(error)
    }
  }
}
