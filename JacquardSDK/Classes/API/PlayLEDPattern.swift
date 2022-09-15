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

/// Command to request the Gear to play an LED pattern.
///
/// Note that not all Gear components have LEDs, you can inspect `Component.capabilities`.
///
/// - SeeAlso: `Commands`
public struct PlayLEDPatternCommand: CommandRequest {
  /// Errors thrown by `PlayLEDPatternCommand`.
  public enum Error: Swift.Error {
    /// Throw this error if the component does not have an LED.
    case componentDoesNotSupportPlayLEDPattern
  }

  /// Available LED patterns.
  public enum LEDPatternType: CustomStringConvertible {
    /// Solid LED light blink.
    case solid

    /// Breathing light pattern.
    case breathing

    /// Pulse light pattern.
    case pulsing

    /// LED light will blink once.
    case singleBlink

    /// LED light will blink twice.
    case doubleBlink

    /// LED light will blink three times.
    case tripleBlink

    /// Custom LED pattern
    case custom

    public var description: String {
      switch self {
      case .solid: return "Solid"
      case .breathing: return "Breathing"
      case .pulsing: return "Pulsing"
      case .singleBlink: return "1 Blink"
      case .doubleBlink: return "2 Blink"
      case .tripleBlink: return "3 Blink"
      case .custom: return "Custom"
      }
    }
  }

  /// Options for modifying LED Commands.
  public enum LEDPatternPlayType: CustomStringConvertible {
    /// Play LED pattern.
    case play

    /// Play/Pause LED pattern.
    case toggle

    public var description: String {
      switch self {
      case .play: return "Play"
      case .toggle: return "Toggle"
      }
    }
  }

  /// PlayLEDPatternCommand response value is an empty Void to indicate success.
  public typealias Response = Void

  /// The sequence of `Frame`s that make a custom pattern, or a single frame representing the color for a predefined pattern.
  ///
  /// If the combined duration of Frames is less than `durationMs`, the pattern will be repeated until `durationMs` has elapsed.
  let frames: [Frame]

  /// The length of time to repeat the frames for.
  let durationMs: Int

  /// The component that the pattern will be played on.
  let component: Component

  /// Predefined pattern.
  var patternType: LEDPatternType?

  /// If `true` the Led Pattern will resume, if it is interrupted by another `PlayLEDPatternCommand`.
  let isResumable: Bool

  /// If consecutive similar PlayLEDPatternCommand are sent.
  /// The  Tag will use this flag to make a decision whether to start the new pattern or stop an ongoing pattern.
  let playPauseToggle: LEDPatternPlayType

  /// If `true` any Led Pattern that is playing will be stopped.
  let haltAll: Bool

  /// Initializes a `PlayLEDPattern` command with a custom pattern.
  ///
  /// If the combined duration of Frames is less than `durationMs`, the pattern will be repeated
  /// until `durationMs` has elapsed.
  ///
  /// - Parameters:
  ///   - frames: The sequence of `Frame`s that make a pattern.
  ///   - durationMs: The length of time to repeat the frames for.
  ///   - component: The component that the pattern will be played on.
  ///   - patternType: The pattern of the LED to play.
  ///   - isResumable: If `true` the Led Pattern will resume, if it is interrupted by another `PlayLEDPatternCommand`
  ///   - playPauseToggle: Enables tag to make a decision whether to start the new pattern or stop an ongoing pattern.
  ///   - haltAll: If `true` any Led Pattern that is playing will be stopped.
  ///   - Throws: if the component does not have an LED.
  public init(
    frames: [Frame],
    durationMs: Int,
    component: Component,
    patternType: LEDPatternType = .custom,
    isResumable: Bool = false,
    playPauseToggle: LEDPatternPlayType = .play,
    haltAll: Bool = false
  ) throws {
    if !component.capabilities.contains(.led) {
      throw Error.componentDoesNotSupportPlayLEDPattern
    }
    self.frames = frames
    self.durationMs = durationMs
    self.component = component
    self.patternType = patternType
    self.isResumable = isResumable
    self.playPauseToggle = playPauseToggle
    self.haltAll = haltAll
  }

  /// Initializes a `PlayLEDPattern` command with a predefined pattern.
  ///
  /// - Parameters:
  ///   - color: The color to use for the pattern.
  ///   - durationMs: The length of time to repeat the pattern for.
  ///   - component: The component that the pattern will be played on.
  ///   - patternType: The pattern of the LED to play.
  ///   - isResumable: If `true` the Led Pattern will resume, if it is interrupted by another `PlayLEDPatternCommand`
  ///   - playPauseToggle: Enables tag to make a decision whether to start the new pattern or stop an ongoing pattern.
  ///   - haltAll: If `true` any Led Pattern that is playing will be stopped.
  ///   - Throws: if the component does not have an LED.
  public init(
    color: Color,
    durationMs: Int,
    component: Component,
    patternType: LEDPatternType = .solid,
    isResumable: Bool = false,
    playPauseToggle: LEDPatternPlayType = .play,
    haltAll: Bool = false
  ) throws {

    let frame = [Frame(color: color, durationMs: durationMs)]

    try self.init(
      frames: frame,
      durationMs: durationMs,
      component: component,
      patternType: patternType,
      isResumable: isResumable,
      playPauseToggle: playPauseToggle,
      haltAll: haltAll
    )
  }

  /// RGB representation of target color.
  public struct Color {
    /// Red component of color from 0-255.
    public let red: Int

    /// Green component of color from 0-255.
    public let green: Int

    /// Blue component of color from 0-255.
    public let blue: Int

    /// Initialize an LED color.
    ///
    /// - Parameters:
    ///   - red: Red component of color from 0-255.
    ///   - green: Green component of color from 0-255.
    ///   - blue: Blue component of color from 0-255.
    public init(red: Int, green: Int, blue: Int) {
      self.red = red
      self.green = green
      self.blue = blue
    }
  }

  /// Color and time duration for frame.
  public struct Frame {
    /// Color of the LED.
    public let color: Color

    /// Duration for the color to be shown.
    public let durationMs: UInt32

    /// Initialize an LED pattern frame.
    ///
    /// - Parameters:
    ///   - color: The color to display for this frame.
    ///   - durationMs: The length of time this frame lasts.
    public init(color: Color, durationMs: Int) {
      self.color = color
      self.durationMs = UInt32(durationMs)
    }
  }
}

extension PlayLEDPatternCommand.Error: CustomStringConvertible {

  /// Error description.
  public var description: String {
    switch self {
    case .componentDoesNotSupportPlayLEDPattern:
      return "Component does not have LED capability"
    }
  }
}
