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

extension PlayHapticCommand {

  /// :nodoc:
  public var request: V2ProtocolCommandRequestIDInjectable {
    var request = Google_Jacquard_Protocol_Request()
    request.domain = .gear
    request.opcode = .gearHaptic
    request.componentID = component.componentID

    let protoPattern = Google_Jacquard_Protocol_HapticRequest(sequence: frame)
    request.Google_Jacquard_Protocol_HapticRequest_haptic = protoPattern

    return request
  }

  /// :nodoc:
  public func parseResponse(outerProto: Any) -> Result<Void, Swift.Error> {
    guard outerProto is Google_Jacquard_Protocol_Response else {
      return .failure(CommandResponseStatus.errorAppUnknown)
    }
    return .success(())
  }
}

extension Google_Jacquard_Protocol_HapticRequest {
  init(sequence: PlayHapticCommand.HapticFrame) {
    var frame = Google_Jacquard_Protocol_HapticSymbol()
    frame.onMs = sequence.onMs
    frame.offMs = sequence.offMs
    frame.pattern = Google_Jacquard_Protocol_HapticSymbolType(sequence.pattern)
    frame.maxAmplitudePercent = sequence.maxAmplitudePercent
    frame.repeatNMinusOne = sequence.repeatNMinusOne
    self.frames = frame
  }
}

extension Google_Jacquard_Protocol_HapticSymbolType {

  init(_ patternType: PlayHapticCommand.HapticPatternType) {
    switch patternType {
    case .hapticSymbolHalted: self = .hapticSymbolHalted
    case .hapticSymbolSineIncrease: self = .hapticSymbolSineIncrease
    case .hapticSymbolSineDecrease: self = .hapticSymbolSineDecrease
    case .hapticSymbolLinearIncrease: self = .hapticSymbolLinearIncrease
    case .hapticSymbolLinearDecrease: self = .hapticSymbolLinearDecrease
    case .hapticSymbolParabolicIncrease: self = .hapticSymbolParabolicIncrease
    case .hapticSymbolParabolicDecrease: self = .hapticSymbolParabolicDecrease
    case .hapticSymbolConstOn: self = .hapticSymbolConstOn
    }
  }
}
