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

enum SampleLEDPattern: CaseIterable, Identifiable {
  var id: UUID { UUID() }

  case blueBlink
  case greenBlink
  case pinkBlink
  case blink
  case strobe
  case shine
  case stopAll

  var name: String {
    switch self {
    case .blueBlink: return "Blue Blink"
    case .greenBlink: return "Green Blink"
    case .pinkBlink: return "Pink Blink"
    case .blink: return "Blink"
    case .strobe: return "Strobe"
    case .shine: return "Shine"
    case .stopAll: return "Stop All"
    }
  }

  var icon: String {
    switch self {
    case .blueBlink: return "Blue"
    case .greenBlink: return "Green"
    case .pinkBlink: return "Pink"
    case .blink: return "Blink"
    case .strobe: return "Strobe"
    case .shine: return "Shine"
    case .stopAll: return "StopAll"
    }
  }
}

// LED cell view
struct LEDRow: View {
  var pattern: SampleLEDPattern

  var body: some View {
    HStack {
      Image(pattern.icon)
        .resizable()
        .frame(width: 40, height: 40)

      Text("\(pattern.name)")
        .font(.system(size: 18.0, weight: .medium))
        .padding(.leading, 25)

      Spacer()

      Button {
      } label: {
        Image("Play")
      }
      .padding(.trailing, 5)
    }
    .frame(
      minWidth: 0, maxWidth: .infinity, minHeight: 60, maxHeight: 60, alignment: .leading
    )
  }
}

struct LEDView: View {

  private enum Constants {
    static let title = "LED"
    static let description =
      """
      Choose Tag LED, Garment LED, or both. With the API you can define and play arbitrary LED
      patterns
      """
    static let tagLED = "Tag LED"
    static let gearLED = "Gear LED"
    static let durationText = "Duration in seconds"
    static let playLEDOnAllTag = "Play LED on all Tags"
  }

  // Publishes a value every time the tag connects or disconnects.
  @State private var tagPublisher: AnyPublisher<ConnectedTag, Never>
  // Retains references to the Cancellable instances created by publisher subscriptions.
  @State private var observers = [Cancellable]()
  @State private var isGearConnected = false
  @State private var isKeyboardOpen = false
  @State private var tagLEDToggle = true
  @State private var gearLEDToggle = false
  @State private var allTagsToggle = true
  @State private var textFieldID = UUID().uuidString
  @State private var defaultLEDDurationInSec = 5
  @State private var durationText = ""

  // The maximum value that can be sent to tag is UInt32.max miliseconds.
  private let maximumAllowedDuration = UInt32.max / 1000

  var body: some View {
    VStack {
      Text(Constants.title)
        .frame(maxWidth: .infinity, alignment: .leading)
        .font(.system(size: 30.0, weight: .medium))
        .padding(.top, 20)
        .padding(.leading, 20)

      Text(Constants.description)
        .frame(maxWidth: .infinity, alignment: .leading)
        .font(.system(size: 16.0, weight: .regular))
        .foregroundColor(Color(.tableViewSectionTitle))
        .padding(.top, 10)
        .padding(.leading, 20)
        .padding(.trailing, 20)

      VStack(spacing: 0) {
        // Tag LED row.
        HStack {
          Image("ActiveTag")
            .frame(width: 40, height: 40)

          Text(Constants.tagLED)
            .font(.system(size: 16.0, weight: .medium))
            .padding(.leading, 25.0)
            .frame(maxWidth: .infinity, alignment: .leading)

          Toggle("", isOn: $tagLEDToggle)
            .frame(maxWidth: 51, maxHeight: 32)
        }
        .frame(maxWidth: .infinity)
        .padding(.leading, 20)
        .padding(.trailing, 20)

        // Gear LED row.
        HStack {
          Image(isGearConnected ? "ActiveGear" : "InactiveGear")
            .frame(width: 40, height: 40)

          Text(Constants.gearLED)
            .font(.system(size: 16.0, weight: .medium))
            .foregroundColor(isGearConnected ? .black : Color(.border))
            .padding(.leading, 25)
            .frame(maxWidth: .infinity, alignment: .leading)

          Toggle("", isOn: $gearLEDToggle)
            .disabled(!isGearConnected)
            .frame(maxWidth: 51, maxHeight: 32)
        }
        .frame(maxWidth: .infinity)
        .padding(.leading, 20)
        .padding(.trailing, 20)

        // LED duration row.
        HStack {
          Image("duration")
            .frame(width: 40, height: 40)

          Text(Constants.durationText)
            .font(.system(size: 16.0, weight: .medium))
            .padding(.leading, 25)
            .frame(maxWidth: .infinity, alignment: .leading)

          TextField(
            "Duration",
            text: $durationText,
            onEditingChanged: { status in
              isKeyboardOpen = status
            }
          )
          .id(textFieldID)
          .padding(EdgeInsets(top: 0, leading: 5, bottom: 0, trailing: 5))
          .multilineTextAlignment(.trailing)
          .keyboardType(.numberPad)
          .overlay(
            RoundedRectangle(cornerRadius: 3)
              .stroke(lineWidth: 1)
              .foregroundColor(isKeyboardOpen ? Color.black : Color(.grayBorder))
          )
          .onTapGesture {}
          .frame(width: 100, height: 30)
        }
        .frame(maxWidth: .infinity)
        .padding(.leading, 20)
        .padding(.trailing, 20)

        // All tags LED row.
        HStack {
          Image("ActiveTag")
            .frame(width: 40, height: 40)

          Text(Constants.playLEDOnAllTag)
            .font(.system(size: 16.0, weight: .medium))
            .lineLimit(1)
            .padding(.leading, 25)
            .frame(maxWidth: .infinity, alignment: .leading)

          Toggle("", isOn: $allTagsToggle)
            .frame(maxWidth: 51, maxHeight: 32)
        }
        .frame(maxWidth: .infinity)
        .padding(.leading, 20)
        .padding(.trailing, 20)
      }

      List(SampleLEDPattern.allCases) { led in
        LEDRow(pattern: led)
          .onTapGesture {
            // Send LED command
            if gearLEDToggle {
              // Send LED play request for Gear.
              playGearLED(led)
            }
            if allTagsToggle {
              // Send LED play request for all connected Tag.
              playAllConnectedTagLED(led)
            } else if tagLEDToggle {
              // Send LED play request for active Tag.
              playTagLED(led)
            }
          }
      }
      .listStyle(PlainListStyle())
    }
    .simultaneousGesture(
      TapGesture()
        .onEnded { _ in
          if isKeyboardOpen {
            textFieldID = UUID().uuidString
            isKeyboardOpen = false
            updateTextField()
          }
        }
    )
    .onAppear {
      durationText = "\(defaultLEDDurationInSec)"
      tagPublisher
        .flatMap { $0.connectedGear }
        .sink { gear in
          guard let gear = gear, gear.capabilities.contains(where: { $0 == .led }) else {
            isGearConnected = false
            gearLEDToggle = false
            return
          }
          isGearConnected = true
          gearLEDToggle = true
        }.addTo(&observers)
    }
  }

  init(tagPublisher: AnyPublisher<ConnectedTag, Never>) {
    self.tagPublisher = tagPublisher
  }
}

extension LEDView {
  private func updateTextField() {

    defer { durationText = "\(defaultLEDDurationInSec)" }

    guard let duration = Int(durationText) else {
      MDCSnackbarManager.default.show(MDCSnackbarMessage(text: "Enter a valid duration"))
      return
    }

    switch duration.signum() {
    case -1, 0:
      // Value is <= 0, set maximum allowed duration.
      defaultLEDDurationInSec = Int(maximumAllowedDuration)
      MDCSnackbarManager.default.show(MDCSnackbarMessage(text: "Maximum duration is set"))
      return
    case 1:
      if duration > (1...maximumAllowedDuration).upperBound {
        MDCSnackbarManager.default.show(
          MDCSnackbarMessage(
            text:
              """
              Maximum duration is \(maximumAllowedDuration) seconds.
              You can enter 0 to set max duration.
              """
          ))
      } else {
        // Value is within range, set the duration.
        defaultLEDDurationInSec = duration
      }
    default:
      assertionFailure("default state should not be reached.")
    }
  }
}

/// Configure LED command parameters like frame, patternType, patternPlayType, resumable etc.
extension SampleLEDPattern {

  var commandBuilder: (Component, Int) throws -> PlayLEDPatternCommand {
    var patternColor: PlayLEDPatternCommand.Color
    var playType: PlayLEDPatternCommand.LEDPatternPlayType

    switch self {
    case .blueBlink:
      patternColor = PlayLEDPatternCommand.Color(red: 0, green: 0, blue: 255)
      playType = .toggle
    case .greenBlink:
      patternColor = PlayLEDPatternCommand.Color(red: 0, green: 255, blue: 0)
      playType = .toggle
    case .pinkBlink:
      patternColor = PlayLEDPatternCommand.Color(red: 255, green: 102, blue: 178)
      playType = .toggle
    case .blink:
      patternColor = PlayLEDPatternCommand.Color(red: 220, green: 255, blue: 255)
      playType = .toggle
    case .shine:
      return {
        try PlayLEDPatternCommand(
          color: PlayLEDPatternCommand.Color(red: 220, green: 255, blue: 255),
          durationMs: $1.convertSecToMilliSec(),
          component: $0,
          patternType: .solid,
          isResumable: true,
          playPauseToggle: .toggle
        )
      }
    case .strobe:
      let colors = [
        PlayLEDPatternCommand.Color(red: 255, green: 0, blue: 0),
        PlayLEDPatternCommand.Color(red: 247, green: 95, blue: 0),
        PlayLEDPatternCommand.Color(red: 255, green: 204, blue: 0),
        PlayLEDPatternCommand.Color(red: 0, green: 255, blue: 0),
        PlayLEDPatternCommand.Color(red: 2, green: 100, blue: 255),
        PlayLEDPatternCommand.Color(red: 255, green: 0, blue: 255),
        PlayLEDPatternCommand.Color(red: 100, green: 255, blue: 255),
        PlayLEDPatternCommand.Color(red: 2, green: 202, blue: 255),
        PlayLEDPatternCommand.Color(red: 255, green: 0, blue: 173),
        PlayLEDPatternCommand.Color(red: 113, green: 5, blue: 255),
        PlayLEDPatternCommand.Color(red: 15, green: 255, blue: 213),
      ]
      let frames = colors.map { PlayLEDPatternCommand.Frame(color: $0, durationMs: 250) }
      return {
        try PlayLEDPatternCommand(
          frames: frames,
          durationMs: $1.convertSecToMilliSec(),
          component: $0,
          isResumable: true,
          playPauseToggle: .toggle
        )
      }
    case .stopAll:
      return {
        try PlayLEDPatternCommand(
          color: PlayLEDPatternCommand.Color(red: 0, green: 0, blue: 0),
          durationMs: $1.convertSecToMilliSec(),
          component: $0,
          haltAll: true
        )
      }
    }

    return {
      try PlayLEDPatternCommand(
        color: patternColor,
        durationMs: $1.convertSecToMilliSec(),
        component: $0,
        patternType: .singleBlink,
        isResumable: true,
        playPauseToggle: playType)
    }
  }
}

// MARK: Play LED commands

extension LEDView {

  /// Play LED on Gear.
  private func playGearLED(_ pattern: SampleLEDPattern) {
    tagPublisher
      .flatMap {
        // Make a tagPublisher that is a tuple of tag and latest connected gear.
        Just($0).combineLatest($0.connectedGear.compactMap({ gear in gear }))
      }
      // Ensure the LED pattern is not replayed every time the tag or gear reconnects.
      .prefix(1)
      // Combine requires the Error type to match before applying flatMap.
      .mapNeverToError()
      .flatMap { (tag, gearComponent) -> AnyPublisher<Void, Error> in
        do {
          // Create command request.
          let request = try pattern.commandBuilder(gearComponent, self.defaultLEDDurationInSec)
          // Send the command request to play LED on Gear.
          return tag.enqueue(request)
        } catch (let error) {
          return Fail<Void, Error>(error: error).eraseToAnyPublisher()
        }
      }.sink { completion in
        switch completion {
        case .finished:
          break
        case .failure(let error):
          guard let ledError = error as? PlayLEDPatternCommand.Error,
            ledError == .componentDoesNotSupportPlayLEDPattern
          else {
            assertionFailure("Failed to play LED on Gear \(error.localizedDescription)")
            return
          }
          MDCSnackbarManager.default.show(MDCSnackbarMessage(text: ledError.description))
        }
      } receiveValue: { _ in
        print("Play gear LED pattern command sent.")
      }.addTo(&observers)
  }

  /// Play LED on Tag.
  private func playTagLED(_ pattern: SampleLEDPattern) {
    tagPublisher
      // Ensure the LED pattern is not replayed every time the tag or gear reconnects.
      .prefix(1)
      // Combine requires the Error type to match before applying flatMap.
      .mapNeverToError()
      .flatMap { tag -> AnyPublisher<Void, Error> in
        do {
          // Create command request.
          let request = try pattern.commandBuilder(tag.tagComponent, self.defaultLEDDurationInSec)
          // Send the command request to play LED on Gear.
          return tag.enqueue(request)
        } catch (let error) {
          return Fail<Void, Error>(error: error).eraseToAnyPublisher()
        }
      }.sink { completion in
        switch completion {
        case .finished:
          break
        case .failure(let error):
          guard let ledError = error as? PlayLEDPatternCommand.Error,
            ledError == .componentDoesNotSupportPlayLEDPattern
          else {
            assertionFailure("Failed to play LED on Tag \(error.localizedDescription)")
            return
          }
          MDCSnackbarManager.default.show(MDCSnackbarMessage(text: ledError.description))
        }
      } receiveValue: { _ in
        print("Play tag LED pattern command sent.")
      }.addTo(&observers)
  }

  /// Play LED on all connected Tags.
  private func playAllConnectedTagLED(_ pattern: SampleLEDPattern) {

    for knownTag in Preferences.knownTags {
      sharedJacquardManager.getConnectedTag(for: knownTag.identifier)
        .prefix(1)
        .sink { tag in
          if let tag = tag {
            // Tag connected, send the command request to play LED on tag.
            do {
              let request =
                try pattern.commandBuilder(tag.tagComponent, self.defaultLEDDurationInSec)
              let _ = tag.enqueue(request)
            } catch (let error) {
              print("Play LED pattern command request could not be created, \(error)")
            }
          } else {
            print("Connected tag: \(knownTag.identifier) not available.")
          }
        }.addTo(&observers)
    }
  }
}
