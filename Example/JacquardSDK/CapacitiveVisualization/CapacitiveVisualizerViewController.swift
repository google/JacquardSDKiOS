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

/// Showcases capacitive visualization for user's interaction with the threads on the garment using
/// the bar chart.
final class CapacitiveVisualizerViewController: UIViewController {

  // MARK: - IBOutlets

  @IBOutlet weak var barChartView: UIView!
  @IBOutlet weak var barValuesView: UIView!

  // MARK: - Private variables

  /// Represents bars in the bar chart.
  private var barViews = [BarView]()
  /// Represents values for the bars in the bar chart.
  private var barValueLabels = [UILabel]()
  private var resetBarViewsAndValuesTimer: Timer?
  /// Represents the connected tag.
  private let tagPublisher: AnyPublisher<ConnectedTag, Never>
  private var observers = [Cancellable]()

  private enum Constants {
    static let barSpacing: CGFloat = 6.0
    static let barWidth: CGFloat = 24.0
    static let numberOfBars: CGFloat = 12.0
    public static let barValueColor = UIColor(
      red: 87.0 / 255.0, green: 87.0 / 255.0, blue: 87.0 / 255.0, alpha: 1.0)
    static let resetBarValuesDuration: TimeInterval = 0.1
    static let defaultBarValue = "0"
  }

  // MARK: - Initializers

  init(tagPublisher: AnyPublisher<ConnectedTag, Never>) {
    self.tagPublisher = tagPublisher
    super.init(nibName: nil, bundle: nil)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  // MARK: - View controller lifecycle methods

  override func viewDidLoad() {
    super.viewDidLoad()
    // Subscription for the capacitance values for the threads.
    tagPublisher.sink { [weak self] tag in
      guard let self = self else { return }
      tag.registerSubscriptions(self.createSubscriptions)
    }.addTo(&observers)

    subscribeGearConnectionEvent()
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    initializeBarViews()
    initializeBarValueLabels()
    // Enable the touch mode.
    setTouchMode(.continuous)
  }

  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    // Disable the touch mode by setting the default gesture mode.
    setTouchMode(.gesture)
  }

  // MARK: - Private functions

  /// Subscribe to gear connection events.
  private func subscribeGearConnectionEvent() {
    tagPublisher
      .flatMap { $0.connectedGear }
      .sink { [weak self] gear in
        guard let self = self else { return }
        guard gear != nil else {
          print("Gear not attached.")
          return
        }
        self.setTouchMode(.continuous)
      }.addTo(&observers)
  }

  private func createSubscriptions(_ tag: SubscribableTag) {
    // Observe capacitance values for the threads. These will not be delivered when in gesture mode.
    tag.subscribe(ContinuousTouchNotificationSubscription())
      .sink { [weak self] touchData in
        guard let self = self else { return }
        print("Touch Data: \(touchData.linesArray)")
        self.processData(lineData: touchData.linesArray)
      }.addTo(&observers)
  }

  private func setTouchMode(_ touchMode: TouchMode) {
    tagPublisher
      .flatMap {
        // Make a stream that is a tuple of tag and latest connected gear.
        Just($0).combineLatest($0.connectedGear.compactMap({ gear in gear }))
      }
      .prefix(1)
      .mapNeverToError()
      .flatMap { (tag, gear) -> AnyPublisher<Void, Error> in
        return tag.setTouchMode(touchMode, for: gear)
      }.sink { (error) in
        MDCSnackbarManager.default.show(MDCSnackbarMessage(text: "\(error)"))
      } receiveValue: { (_) in
        print("Continuous touch mode enabled.")
      }.addTo(&observers)
  }

  /// Processes the received capacitance data and updates the bar chart to reflect it.
  private func processData(lineData: [UInt8]) {
    resetBarViewsAndValuesTimer?.invalidate()
    // Reset bar chart after user's interaction with threads ends.
    resetBarViewsAndValuesTimer = Timer.scheduledTimer(
      withTimeInterval: Constants.resetBarValuesDuration, repeats: false,
      block: { _ in
        self.resetBarViewsAndValues()
      })
    DispatchQueue.main.async {
      for (barView, data) in zip(self.barViews, lineData) {
        barView.processData(lineData: data)
      }
      for (barLabel, data) in zip(self.barValueLabels, lineData) {
        barLabel.text = "\(data)"
      }
    }
  }
}

extension CapacitiveVisualizerViewController {

  private func initializeBarViews() {
    view.layoutIfNeeded()
    let totalBarSpace =
      ((self.barChartView.bounds.size.width) / Constants.numberOfBars)
    barViews = stride(
      from: 0.0,
      to: barChartView.frame.size.width,
      by: totalBarSpace
    ).map {
      BarView(
        frame: CGRect(
          x: $0, y: 0.0, width: totalBarSpace, height: self.barChartView.bounds.size.height))
    }
    let barWidth =
      (totalBarSpace - Constants.barWidth) > 0
      ? Constants.barWidth : (totalBarSpace - Constants.barSpacing)
    barViews.forEach {
      barChartView.addSubview($0)
      $0.bounds.size = CGSize(
        width: barWidth, height: self.barChartView.bounds.height)
    }
  }

  private func initializeBarValueLabels() {
    view.layoutIfNeeded()
    let totalBarSpace =
      ((self.barValuesView.bounds.size.width) / Constants.numberOfBars)
    barValueLabels = stride(
      from: 0.0,
      to: barValuesView.frame.size.width,
      by: totalBarSpace
    ).map {
      UILabel(
        frame: CGRect(
          x: $0, y: 0.0, width: totalBarSpace, height: self.barValuesView.bounds.size.height))
    }
    let barLabelWidth =
      (totalBarSpace - Constants.barWidth) > 0
      ? Constants.barWidth : (totalBarSpace - Constants.barSpacing)
    barValueLabels.forEach {
      barValuesView.addSubview($0)
      $0.text = Constants.defaultBarValue
      $0.textAlignment = .center
      $0.font = UIFont.systemFont(ofSize: 12)
      $0.textColor = Constants.barValueColor
      $0.bounds.size = CGSize(
        width: barLabelWidth, height: self.barValuesView.bounds.height)
      $0.isAccessibilityElement = false
    }
  }

  private func resetBarViewsAndValues() {
    barValueLabels.forEach {
      $0.text = Constants.defaultBarValue
    }
    barViews.forEach {
      $0.processData(lineData: 0)
    }
  }

}
