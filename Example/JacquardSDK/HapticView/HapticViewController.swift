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

struct HapticCellModel: Hashable {
  var description: String
  var onMs: UInt32
  var offMs: UInt32
  var maxAmplitudePercent: UInt32
  var repeatNMinusOne: UInt32
  var pattern: PlayHapticCommand.HapticPatternType
}

class HapticViewController: UIViewController {

  @IBOutlet private weak var tableView: UITableView!

  // Publishes a value every time the tag connects or disconnects.
  private var tagPublisher: AnyPublisher<ConnectedTag, Never>

  // Use to manage data and provide cells for a table view.
  private var diffableDataSource: UITableViewDiffableDataSource<Int, HapticCellModel>!

  // Retains references to the Cancellable instances created by publisher subscriptions.
  private var observers = [Cancellable]()
  private var isConnectedGear = false

  init(tagPublisher: AnyPublisher<ConnectedTag, Never>) {
    self.tagPublisher = tagPublisher
    super.init(nibName: "HapticViewController", bundle: nil)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    configureTableDataSource()
    subscribeGearConnectionEvent()
  }

  private func subscribeGearConnectionEvent() {
    tagPublisher
      .flatMap { $0.connectedGear }
      .sink { [weak self] gear in
        guard let self = self else { return }
        guard gear != nil else {
          print("Gear not attached.")
          self.isConnectedGear = false
          return
        }
        self.isConnectedGear = true
      }.addTo(&observers)
  }

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
        repeatNMinusOne: 15,
        pattern: .hapticSymbolSineIncrease
      )
    }
  }

  static var allModels: [HapticCellModel] {
    return self.allCases.map { $0.cellModel }
  }
}

/// Configure tableView data source
extension HapticViewController {

  private func configureTableDataSource() {

    // Configure table view.
    let nib = UINib(nibName: "HapticCell", bundle: nil)
    tableView.register(nib, forCellReuseIdentifier: HapticCell.reuseIdentifier)

    diffableDataSource = UITableViewDiffableDataSource<Int, HapticCellModel>(tableView: tableView) {
      (tableView, indexPath, hapticModel) -> UITableViewCell? in
      guard
        let cell = tableView.dequeueReusableCell(
          withIdentifier: HapticCell.reuseIdentifier,
          for: indexPath
        ) as? HapticCell
      else {
        return UITableViewCell()
      }
      cell.configureCell(data: hapticModel)
      return cell
    }

    tableView.dataSource = diffableDataSource

    var snapshot = NSDiffableDataSourceSnapshot<Int, HapticCellModel>()
    snapshot.appendSections([0])
    snapshot.appendItems(SampleHapticPattern.allModels, toSection: 0)
    diffableDataSource?.apply(snapshot, animatingDifferences: false)
  }
}

/// Handle Tableview delegate methods.
extension HapticViewController: UITableViewDelegate {

  func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    if isConnectedGear {
      let selectedHaptic = SampleHapticPattern.allModels[indexPath.row]
      playHaptic(for: selectedHaptic)
    }
    tableView.deselectRow(at: indexPath, animated: true)
  }
}
