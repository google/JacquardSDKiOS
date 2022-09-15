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

/// Notification to observe `Gesture` events.
///
/// - SeeAlso: `Notifications`
public struct GestureNotificationSubscription: NotificationSubscription {
  /// The response type published when a gesture event is received.
  public typealias Notification = Gesture

  /// Initialize a subscription request.
  public init() {}
}

/// The possible gesture types.
public enum Gesture: Int, CaseIterable {
  /// No gesture type.
  case noInference = 0

  /// Double tap gesture.
  case doubleTap = 1

  /// Brush in gesture.
  case brushIn = 2

  /// Brush out gesture.
  case brushOut = 3

  /// Short cover gesture.
  case shortCover = 7

  /// Brush up gesture.
  case brushUp = 13

  /// Brush down gesture.
  case brushDown = 14

  /// Gesture display name.
  public var name: String {
    switch self {
    case .noInference:
      return "No Gesture"
    case .doubleTap:
      return "Double Tap"
    case .brushIn:
      return "Brush In"
    case .brushOut:
      return "Brush Out"
    case .shortCover:
      return "Cover"
    case .brushUp:
      return "Brush Up"
    case .brushDown:
      return "Brush Down"
    }
  }
}

extension Gesture {
  init?(_ inferenceData: Google_Jacquard_Protocol_InferenceData) {
    guard let inferenceID = Gesture(rawValue: Int(inferenceData.event)) else {
      return nil
    }
    self = inferenceID
  }
}
