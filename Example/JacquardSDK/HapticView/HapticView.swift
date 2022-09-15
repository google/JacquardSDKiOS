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

import Combine
import JacquardSDK
import MaterialComponents
import SwiftUI

struct HapticCellModel: Identifiable {
  let id = UUID()
  let description: String
  let onMs: UInt32
  let offMs: UInt32
  let maxAmplitudePercent: UInt32
  let repeatNMinusOne: UInt32
  let pattern: PlayHapticCommand.HapticPatternType
}

/// Create Haptic screen datasource.
private enum SampleHapticPattern: Int, CaseIterable {

  case insert = 0
  case gesture
  case notification
  case error
  case alert

  var cellModel: HapticCellModel {
    switch self {
    case .insert:
      return HapticCellModel(
        description: "Tag Insertion Pattern",
        onMs: 200,
        offMs: 0,
        maxAmplitudePercent: 60,
        repeatNMinusOne: 0,
        pattern: .hapticSymbolSineIncrease
      )
    case .gesture:
      return HapticCellModel(
        description: "Gesture Pattern",
        onMs: 170,
        offMs: 0,
        maxAmplitudePercent: 60,
        repeatNMinusOne: 0,
        pattern: .hapticSymbolSineIncrease
      )
    case .notification:
      return HapticCellModel(
        description: "Notification Pattern",
        onMs: 170,
        offMs: 30,
        maxAmplitudePercent: 60,
        repeatNMinusOne: 1,
        pattern: .hapticSymbolSineIncrease
      )
    case .error:
      return HapticCellModel(
        description: "Error Pattern",
        onMs: 170,
        offMs: 50,
        maxAmplitudePercent: 60,
        repeatNMinusOne: 3,
        pattern: .hapticSymbolSineIncrease
      )
    case .alert:
      return HapticCellModel(
        description: "Alert Pattern",
        onMs: 170,
        offMs: 700,
        maxAmplitudePercent: 60,
        repeatNMinusOne: 14,
        pattern: .hapticSymbolSineIncrease
      )
    }
  }

  static var allModels: [HapticCellModel] {
    return self.allCases.map { $0.cellModel }
  }
}

struct HapticRow: View {
  var haptic: HapticCellModel

  var body: some View {
    HStack {
      Image("HapticIcon")
        .frame(width: 50, height: 50)

      Text("\(haptic.description)")
        .font(.system(size: 18.0, weight: .medium))
        .padding(.leading, 10)

      Spacer()

      Image("Play")
        .frame(width: 20, height: 20)
    }
    .frame(
      minWidth: 0, maxWidth: .infinity, minHeight: 50, maxHeight: .infinity, alignment: .leading
    )
  }
}

struct HapticView: View {
  // Publishes a value every time the tag connects or disconnects.
  @State private var tagPublisher: AnyPublisher<ConnectedTag, Never>
  @State var tagObserver: AnyCancellable?

  // Retains references to the Cancellable instances created by publisher subscriptions.
  @State private var observers = [Cancellable]()
  @State private var isConnected = false

  var body: some View {
    VStack {
      Text("Haptics")
        .frame(maxWidth: .infinity, alignment: .leading)
        .font(.system(size: 30.0, weight: .medium))
        .padding(.top, 20)
        .padding(.leading, 20)

      Text("Your Jacquard product has haptic feedback.")
        .frame(maxWidth: .infinity, alignment: .leading)
        .font(.system(size: 16.0, weight: .regular))
        .foregroundColor(Color(.tableViewSectionTitle))
        .padding(.top, 5)
        .padding(.leading, 20)

      List(SampleHapticPattern.allModels) { haptic in
        HapticRow(haptic: haptic)
          .onTapGesture {
            if isConnected {
              playHaptic(for: haptic)
            }
          }
      }
      .listStyle(PlainListStyle())
      .padding(.top, 20)
    }
    .onAppear {
      tagObserver =
        tagPublisher
        .flatMap { $0.connectedGear }
        .sink { gear in
          guard gear != nil else {
            print("Gear not attached.")
            isConnected = false
            return
          }
          isConnected = true
        }
    }
    .onDisappear {
      let stopPattern = HapticCellModel(
        description: "Stop Pattern",
        onMs: 0,
        offMs: 0,
        maxAmplitudePercent: 0,
        repeatNMinusOne: 0,
        pattern: .hapticSymbolHalted
      )
      playHaptic(for: stopPattern)
    }
  }

  init(tagPublisher: AnyPublisher<ConnectedTag, Never>) {
    self.tagPublisher = tagPublisher
  }
}

extension HapticView {

  /// Play `haptic` on Gear
  ///
  /// - Parameter
  ///   - pattern: The Pattern type of the haptic to play.
  private func playHaptic(for configuration: HapticCellModel) {
    let frame = PlayHapticCommand.HapticFrame(
      onMs: configuration.onMs,
      offMs: configuration.offMs,
      maxAmplitudePercent: configuration.maxAmplitudePercent,
      repeatNMinusOne: configuration.repeatNMinusOne,
      pattern: configuration.pattern
    )

    tagPublisher
      .flatMap {
        // Returns a publisher that is a tuple of tag and latest connected gear.
        Just($0).combineLatest($0.connectedGear.compactMap({ gear in gear }))
      }
      .prefix(1)
      .mapNeverToError()
      .flatMap { (tag, gear) -> AnyPublisher<Void, Error> in
        // Play haptic with a given pattern.
        do {
          let request = try PlayHapticCommand(frame: frame, component: gear)
          return tag.enqueue(request)
        } catch (let error) {
          return Fail<Void, Error>(error: error).eraseToAnyPublisher()
        }
      }.sink { completion in
        switch completion {
        case .finished:
          break
        case .failure(let error):
          guard let hapticError = error as? PlayHapticCommand.Error,
            hapticError == .componentDoesNotSupportPlayHaptic
          else {
            assertionFailure("Failed to play haptic \(error.localizedDescription)")
            return
          }
          MDCSnackbarManager.default.show(MDCSnackbarMessage(text: hapticError.description))
        }
      } receiveValue: { _ in
        print("Haptic command sent.")
      }.addTo(&observers)
  }
}
