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

/// Command to request the Gear plays a haptic pattern.
///
/// Note that the only gear Components (not the tag Component) support haptics.
///
/// - SeeAlso: `Commands`
/// - SeeAlso: `Components and Gear`
public struct PlayHapticCommand: CommandRequest {

  /// Available haptic patterns.
  public enum HapticPatternType: Int {
    /// Halt haptics.
    case hapticSymbolHalted

    /// Sine increase haptic pattern.
    case hapticSymbolSineIncrease

    /// Sine decrease haptic pattern.
    case hapticSymbolSineDecrease

    /// Linear increase haptic pattern.
    case hapticSymbolLinearIncrease

    /// Linear decrease haptic pattern.
    case hapticSymbolLinearDecrease

    /// Parabolic increase haptic pattern.
    case hapticSymbolParabolicIncrease

    /// Parabolic decrease haptic pattern.
    case hapticSymbolParabolicDecrease

    /// Continuous haptic pattern.
    case hapticSymbolConstOn
  }

  /// Errors that can occur when playing Haptic patterns.
  public enum Error: Swift.Error {
    /// Throw this error if the component does not support an haptic.
    case componentDoesNotSupportPlayHaptic
  }

  /// PlayHapticCommand response value is an empty Void to indicate success.
  public typealias Response = Void

  /// Required configuration to play a haptic on the Gear.
  let frame: HapticFrame

  /// An object that holds information of a Tag or Interposser.
  let component: Component

  /// Creates a `PlayHapticCommand` instance.
  ///
  /// - Parameter frame: Configuration to play a haptic on the Gear.
  /// - Parameter component: An object that holds information of a Tag or Interposser.
  /// - Throws: if the component does not support haptic.
  public init(frame: HapticFrame, component: Component) throws {
    if !component.capabilities.contains(.haptic) {
      throw Error.componentDoesNotSupportPlayHaptic
    }
    self.frame = frame
    self.component = component
  }

  /// Configuration for haptic frame.
  public struct HapticFrame {

    /// 16 bit val length of time on playing pattern in msec
    public let onMs: UInt32

    /// 16 bit val length of off time in msec.
    public let offMs: UInt32

    /// 8 bit 0-100%
    public let maxAmplitudePercent: UInt32

    /// 8 bit Play symbol N times before next one
    public let repeatNMinusOne: UInt32

    /// Pattern to play, total 8 patterns are defined.
    public let pattern: HapticPatternType

    /// Creates a `HapticFrame` instance.
    ///
    /// - Parameter onMs: 16 bit val length of time on playing pattern in msec
    /// - Parameter val: 16 bit val  length of off time in msec.
    /// - Parameter maxAmplitudePercent: 8 bit 0-100%
    /// - Parameter repeatNMinusOne: 8 bit Tell to play symbol N times before next one
    public init(
      onMs: UInt32,
      offMs: UInt32,
      maxAmplitudePercent: UInt32,
      repeatNMinusOne: UInt32,
      pattern: HapticPatternType
    ) {
      self.onMs = onMs
      self.offMs = offMs
      self.maxAmplitudePercent = maxAmplitudePercent
      self.repeatNMinusOne = repeatNMinusOne
      self.pattern = pattern
    }
  }
}

extension PlayHapticCommand.Error: CustomStringConvertible {

  /// Error description.
  public var description: String {
    switch self {
    case .componentDoesNotSupportPlayHaptic:
      return "Component does not have haptic capability"
    }
  }
}
