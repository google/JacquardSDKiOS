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

extension PlayLEDPatternCommand {

  /// :nodoc:
  public var request: V2ProtocolCommandRequestIDInjectable {
    var request = Google_Jacquard_Protocol_Request()

    if component.isTag {
      request.domain = Google_Jacquard_Protocol_Domain.base
      request.opcode = Google_Jacquard_Protocol_Opcode.ledPattern
      request.componentID = TagConstants.FixedComponent.tag.rawValue
    } else {
      request.domain = Google_Jacquard_Protocol_Domain.gear
      request.opcode = Google_Jacquard_Protocol_Opcode.gearLed
      request.componentID = component.componentID
    }

    let protoPattern = Google_Jacquard_Protocol_LedPatternRequest(
      sequence: frames,
      durationMs: durationMs,
      patternType: patternType,
      isResumable: isResumable,
      playPauseToggle: playPauseToggle,
      haltAll: haltAll
    )
    request.Google_Jacquard_Protocol_LedPatternRequest_ledPatternRequest = protoPattern

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

extension Google_Jacquard_Protocol_LedPatternRequest {
  init(
    sequence: [PlayLEDPatternCommand.Frame],
    durationMs: Int,
    patternType: PlayLEDPatternCommand.LEDPatternType?,
    isResumable: Bool,
    playPauseToggle: PlayLEDPatternCommand.LEDPatternPlayType,
    haltAll: Bool
  ) {
    var frames = [Google_Jacquard_Protocol_LedPatternFrames]()
    for pattern in sequence {
      var color = Google_Jacquard_Protocol_Color()
      color.red = UInt32(pattern.color.red)
      color.green = UInt32(pattern.color.green)
      color.blue = UInt32(pattern.color.blue)

      var frame = Google_Jacquard_Protocol_LedPatternFrames()
      frame.color = color
      frame.lengthMs = pattern.durationMs

      frames.append(frame)
    }
    self.frames = frames
    self.durationMs = UInt32(durationMs)
    self.patternType = Google_Jacquard_Protocol_PatternType(patternType)
    self.playPauseToggle = Google_Jacquard_Protocol_PatternPlayType(playPauseToggle)
    self.resumable = isResumable
    self.haltAll = haltAll
    self.intensityLevel = 100
  }
}

extension Google_Jacquard_Protocol_PatternType {
  init(_ patternType: PlayLEDPatternCommand.LEDPatternType?) {
    switch patternType {
    case .solid: self = .solid
    case .breathing: self = .breathing
    case .pulsing: self = .pulsing
    case .singleBlink: self = .singleBlink
    case .doubleBlink: self = .solid
    case .tripleBlink: self = .trippleBlink
    case .custom, nil: self = .custom
    }
  }
}

extension Google_Jacquard_Protocol_PatternPlayType {
  init(_ patternPlayType: PlayLEDPatternCommand.LEDPatternPlayType) {
    switch patternPlayType {
    case .play: self = .play
    case .toggle: self = .toggle
    }
  }
}
