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
import UIKit

class MusicalThreadsViewController: UIViewController {
  @IBOutlet weak var threadViews: UIView!
  private let noteHelper = NoteHelper()
  private var lineViews = [UIView]()
  private let tagPublisher: AnyPublisher<ConnectedTag, Never>
  private var observers = [Cancellable]()
  private enum Constants {
    static let threadsLineHeight: CGFloat = 20.0
    // Thread visualizer thread line spacing.
    static let visualizerLineSpace: CGFloat = 25.0
  }
  // MARK: - Initializers
  init(tagPublisher: AnyPublisher<ConnectedTag, Never>) {
    self.tagPublisher = tagPublisher
    super.init(nibName: "MusicalThreads", bundle: nil)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  // MARK: - View controller lifecycle methods
  override func viewDidLoad() {
    super.viewDidLoad()
    initMusicalThreadsView()

    NotificationCenter.default.addObserver(
      forName: UIApplication.willResignActiveNotification, object: nil, queue: .main
    ) { [weak self] _ in
      guard let self = self else { return }
      self.threadViews.subviews.forEach { $0.removeFromSuperview() }
      self.observers.removeAll()
    }

    NotificationCenter.default.addObserver(
      forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main
    ) { [weak self] _ in
      guard let self = self else { return }
      self.initMusicalThreadsView()
      self.registerTagSubscription()
    }

    registerTagSubscription()
  }

  private func registerTagSubscription() {
    // Subscription for the capacitance values for the threads.
    tagPublisher.sink { [weak self] tag in
      guard let self = self else { return }
      tag.registerSubscriptions(self.createSubscriptions)
    }.addTo(&observers)
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    // Enable the touch mode.
    registerTagSubscription()
    subscribeGearConnectionEvent()
    setTouchMode(.continuous)
  }

  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    // Disable the touch mode by setting the default gesture mode.
    setTouchMode(.gesture)
  }

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
        #if DEBUG
          print("Touch Data: \(touchData.linesArray)")
        #endif
        self.processData(lineData: touchData.linesArray)
      }.addTo(&observers)
  }

  private func initMusicalThreadsView() {
    view.layoutIfNeeded()
    threadViews.frame.size.height = 290.0
    let lineSpace = Constants.visualizerLineSpace
    lineViews = stride(
      from: threadViews.frame.size.height,
      to: 0.0,
      by: -lineSpace
    ).map {
      UIView(
        frame: CGRect(
          x: 0.0, y: $0, width: self.threadViews.bounds.size.width,
          height: Constants.threadsLineHeight))
    }
    for line in lineViews {
      line.backgroundColor = UIColor.black
      threadViews.addSubview(line)
      line.bounds.size = CGSize(width: line.bounds.width, height: heightFromLineData(0))
    }
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
        print("Error in enabling continuous touch mode.")
      } receiveValue: { (_) in
        print("Continuous touch mode enabled.")
      }.addTo(&observers)
  }

  private func heightFromLineData(_ lineData: UInt8) -> CGFloat {
    let height = Constants.threadsLineHeight * CGFloat(lineData) / 100.0
    let newHeight = height < CGFloat(5) ? CGFloat(1) : height
    return newHeight
  }

  /// Processes the received capacitance data and updates the bar chart to reflect it.
  private func processData(lineData: [UInt8]) {
    DispatchQueue.main.async {
      self.play(lineData, self.lineViews)
    }
  }

  private func play(_ lineData: [UInt8], _ lineViews: [UIView]) {
    #if DEBUG
      print(lineData)
    #endif
    var count = 0
    for (line, data) in zip(lineViews, lineData) {
      line.bounds.size.height = heightFromLineData(data)
      noteHelper.playLine(count, lineData[count])
      count = count + 1
    }
  }
}
