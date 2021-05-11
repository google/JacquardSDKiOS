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
import UIKit

class LEDViewController: UIViewController {

  @IBOutlet private weak var tableView: UITableView!
  @IBOutlet private weak var tagToggleSwitch: UISwitch!
  @IBOutlet private weak var gearToggleSwitch: UISwitch!
  @IBOutlet private weak var gearImageView: UIImageView!
  @IBOutlet private weak var gearTitleLabel: UILabel!
  @IBOutlet private weak var tagImageView: UIImageView!
  @IBOutlet private weak var tagTitleLabel: UILabel!

  // Publishes a value every time the tag connects or disconnects.
  private var tagPublisher: AnyPublisher<ConnectedTag, Never>

  // Use to manage data and provide cells for a table view.
  private var diffableDataSource: UITableViewDiffableDataSource<Int, SampleLEDPattern>?

  // Retains references to the Cancellable instances created by publisher subscriptions.
  private var observers = [Cancellable]()

  init(tagPublisher: AnyPublisher<ConnectedTag, Never>) {
    self.tagPublisher = tagPublisher
    super.init(nibName: "LEDViewController", bundle: nil)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    gearToggleSwitch.isOn = false
    gearToggleSwitch.isEnabled = false
    observeGearConnection()
    configureTableDataSource()
  }

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
          let request = try pattern.commandBuilder(gearComponent)
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
          let request = try pattern.commandBuilder(tag.tagComponent)
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

  /// Observe gear connection.
  private func observeGearConnection() {
    tagPublisher
      .flatMap { $0.connectedGear }
      .sink { [weak self] gear in
        guard let self = self else { return }
        guard let gear = gear, gear.capabilities.contains(.led) else {
          self.gearToggleSwitch.isOn = false
          self.gearToggleSwitch.isEnabled = false
          self.updateUIForGearSwitch(isOn: false)
          return
        }
        self.gearToggleSwitch.isOn = true
        self.gearToggleSwitch.isEnabled = true
        self.updateUIForGearSwitch(isOn: true)
      }.addTo(&observers)
  }

  @IBAction func gearSwitchTapped(_ sender: UISwitch) {
    gearToggleSwitch.isOn ? updateUIForGearSwitch(isOn: true) : updateUIForGearSwitch(isOn: false)
  }

  @IBAction func tagSwitchTapped(_ sender: UISwitch) {
    tagToggleSwitch.isOn ? updateUIForTagSwitch(isOn: true) : updateUIForTagSwitch(isOn: false)
  }

  private func updateUIForTagSwitch(isOn: Bool) {
    if isOn {
      tagImageView.image = UIImage(named: "ActiveTag")
      tagTitleLabel.textColor = UIColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0)
    } else {
      tagImageView.image = UIImage(named: "InactiveTag")
      tagTitleLabel.textColor = UIColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.3)
    }
  }

  private func updateUIForGearSwitch(isOn: Bool) {
    if isOn {
      gearImageView.image = UIImage(named: "ActiveGear")
      gearTitleLabel.textColor = UIColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0)
    } else {
      gearImageView.image = UIImage(named: "InactiveGear")
      gearTitleLabel.textColor = UIColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.3)
    }
  }
}

/// LED screen datasource model.
enum SampleLEDPattern: CaseIterable {

  case blueBlink
  case greenBlink
  case pinkBlink
  case blink
  case strobe
  case shine

  var name: String {
    switch self {
    case .blueBlink: return "Blue Blink"
    case .greenBlink: return "Green Blink"
    case .pinkBlink: return "Pink Blink"
    case .blink: return "Blink"
    case .strobe: return "Strobe"
    case .shine: return "Shine"
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
    }
  }
}

/// Configure LED command parameters like frame, patternType, patternPlayType, resumable etc.
extension SampleLEDPattern {

  var commandBuilder: (Component) throws -> PlayLEDPatternCommand {
    let duration = 5000  // 5 seconds.
    var patternColor: PlayLEDPatternCommand.Color
    var playType: PlayLEDPatternCommand.LEDPatternPlayType

    switch self {
    case .blueBlink:
      patternColor = PlayLEDPatternCommand.Color(red: 0, green: 0, blue: 255)
      playType = .play
    case .greenBlink:
      patternColor = PlayLEDPatternCommand.Color(red: 0, green: 255, blue: 0)
      playType = .play
    case .pinkBlink:
      patternColor = PlayLEDPatternCommand.Color(red: 255, green: 102, blue: 178)
      playType = .play
    case .blink:
      patternColor = PlayLEDPatternCommand.Color(red: 220, green: 255, blue: 255)
      playType = .toggle
    case .shine:
      return {
        try PlayLEDPatternCommand(
          color: PlayLEDPatternCommand.Color(red: 220, green: 255, blue: 255),
          durationMs: duration,
          component: $0,
          patternType: .solid,
          isResumable: true,
          playPauseToggle: .toggle)
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
          durationMs: duration,
          component: $0,
          isResumable: true,
          playPauseToggle: .toggle)
      }
    }

    return {
      try PlayLEDPatternCommand(
        color: patternColor,
        durationMs: duration,
        component: $0,
        patternType: .singleBlink,
        isResumable: true,
        playPauseToggle: playType)
    }
  }
}

/// Configure tableView data source
extension LEDViewController {

  private func configureTableDataSource() {
    // Configure table view.
    let nib = UINib(nibName: "LEDCell", bundle: nil)
    tableView.register(nib, forCellReuseIdentifier: LEDCell.reuseIdentifier)

    diffableDataSource = UITableViewDiffableDataSource<Int, SampleLEDPattern>(tableView: tableView)
    {
      (tableView, indexPath, ledModel) -> UITableViewCell? in
      guard
        let cell = tableView.dequeueReusableCell(
          withIdentifier: LEDCell.reuseIdentifier,
          for: indexPath
        ) as? LEDCell
      else {
        return UITableViewCell()
      }
      cell.configureCell(data: ledModel)
      return cell
    }

    tableView.dataSource = diffableDataSource

    var snapshot = NSDiffableDataSourceSnapshot<Int, SampleLEDPattern>()
    snapshot.appendSections([0])
    snapshot.appendItems(SampleLEDPattern.allCases, toSection: 0)
    diffableDataSource?.apply(snapshot, animatingDifferences: false)
  }
}

/// Handle Tableview delegate methods.
extension LEDViewController: UITableViewDelegate {

  func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    // Play selected pattern on Tag or Gear.

    guard let patternModel = diffableDataSource?.itemIdentifier(for: indexPath) else {
      return
    }

    if gearToggleSwitch.isOn {
      // Send LED play request for Gear.
      playGearLED(patternModel)
    }
    if tagToggleSwitch.isOn {
      // Send LED play request for Tag.
      playTagLED(patternModel)
    }

    tableView.deselectRow(at: indexPath, animated: true)
  }
}
