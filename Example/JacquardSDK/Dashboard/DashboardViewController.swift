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

final class DashboardViewController: UIViewController {

  private enum Section: Int {
    case apis = 0
    case sampleUseCases = 1

    var title: String {
      switch self {
      case .apis: return "APIs"
      case .sampleUseCases: return "Samples"
      }
    }
  }

  private enum Constants {
    static let reuseIdentifier = "DashboardCell"
    static let headerReuseIdentifier = "DashboardHeaderView"
    // Section padding from left/right edge.
    static let sectionEdgeInsetMargin: CGFloat = 24
    static let minimumInteritemSpacing: CGFloat = 16
    static let minimumLineSpacing: CGFloat = 16
    static let cellsPerRow = 2
    static let itemHeight: CGFloat = 100.0
    static let tagDisconnectedSnackbarMessage = "Tag is disconnected."
    static let tagNotAttachedSnackbarMessage = "Tag is detached from the gear."
  }

  // MARK: IBOutlets

  @IBOutlet private weak var connectionStatusView: UIView!
  @IBOutlet private weak var tagNameLabel: UILabel!
  @IBOutlet private weak var gearNameLabel: UILabel!
  @IBOutlet private weak var gearImageView: UIImageView!
  @IBOutlet private weak var batteryStatusLabel: UILabel!
  @IBOutlet private weak var dashboardCollectionView: UICollectionView!

  // MARK: Instance vars

  private var diffableDataSource: UICollectionViewDiffableDataSource<Section, DashboardItem>!
  /// Responsible for connecting to a Jacquard Tag.
  private var connectionStream: AnyPublisher<TagConnectionState, Never>?
  /// Publisher that delivers events from a connected Jacquard Tag.
  private var tagPublisher: AnyPublisher<ConnectedTag, Never>?
  /// Collection of subscribers.
  private var observers = [AnyCancellable]()

  private var isGearConnected = false
  private var isTagConnected = false
  /// Currently selected Jacquard Tag identifier.
  private var selectedTagIdentifier: UUID?

  // MARK: View life cycle

  override func viewDidLoad() {
    super.viewDidLoad()
    updateUI()
    subscribeSelectCurrentTagEvents()
  }

  /// To update dashboard after setting the current tag on tag details screen.
  private func subscribeSelectCurrentTagEvents() {
    let publisher = NotificationCenter.default.publisher(for: Notification.Name("setCurrentTag"))
    publisher.sink { [weak self] _ in
      guard let self = self else { return }
      self.updateUI()
    }.addTo(&observers)
  }

  private func updateUI() {
    guard let currentTag = Preferences.knownTags.first else {
      assertionFailure("We should always have a known tag before landing on this screen.")
      return
    }

    if let sharedJacquardManager = sharedJacquardManager as? JacquardManagerImplementation {
      sharedJacquardManager.shouldRestoreConnection = { $0 == currentTag.identifier }
    }
    tagNameLabel.text = Preferences.knownTags.first?.displayName ?? "Unknown"
    updateGearState(nil)
    setupCollectionView()
    configureCollectionDataSource()

    updateDataSource()

    if currentTag.identifier == selectedTagIdentifier {
      // SelectedTagIdentifier has not changed, no need for re-connection.
      // As we are cancelling all subscriptions on viewDidDisappear, subscribe to tag events again.
      observerTagPublisher()
      print("SelectedTagIdentifier has not changed skip reconnection")
    } else {
      // Initiate tag connection if
      // `selectedTagIdentifier == nil`, means this is first launch, or
      // The selected tag has changed, so connect to the newly selected tag.
      self.selectedTagIdentifier = currentTag.identifier
      initateConnectionForTag(identifier: currentTag.identifier)
    }
  }

  // MARK: Jacquard Tag Connection

  /// Check if bluetooth is available.
  private func initateConnectionForTag(identifier: UUID) {
    // It is required to wait before the state of CBCentralManager changes to poweredOn.
    sharedJacquardManager.centralState
      .sink { state in
        switch state {
        case .poweredOn:
          self.connectToTag(identifier: identifier)
        case .poweredOff, .unknown, .resetting, .unsupported, .unauthorized:
          self.isTagConnected = false
          self.updateGearState(nil)
          self.updateDataSource()
        @unknown default:
          break
        }
      }.addTo(&observers)
  }

  /// Connect to a given peripheral UUID.
  private func connectToTag(identifier: UUID) {
    // Step 1.
    // The sharedJacquardManager.connect will try to retrieve the known tag(peripheral) from central
    // and initiate a connection on the peripheral.
    connectionStream =
      sharedJacquardManager
      .connect(identifier)
      .catch { error -> AnyPublisher<TagConnectionState, Never> in
        // The only error that can happen here is TagConnectionError.bluetoothDeviceNotFound
        switch error as? TagConnectionError {
        case .bluetoothDeviceNotFound:
          assertionFailure("CoreBluetooth couldn't find known tag for identifier \(identifier).")
          return Just<TagConnectionState>(.disconnected(error)).eraseToAnyPublisher()
        default:
          preconditionFailure("Unexpected error: \(error)")
        }
      }.eraseToAnyPublisher()

    // Step 2.
    // Subscribe to the connection publisher to observe Tag connection states
    let tagOrNilPublisher = connectionStream?
      .map { state -> ConnectedTag? in
        if case .connected(let tag) = state {
          return tag
        }
        return nil
      }
      // A closure to evaluate whether two states are equivalent.
      // Return `true` indicate that the previous and current state is a same.
      // Return `false` indicate that the previous and current state is a different and
      // subsciber get triggered.
      .removeDuplicates { previousState, currentState in
        // Coalesce duplicate sequence of nil values.
        if previousState == nil && currentState == nil {
          return true
        }
        return false
      }

    // If optionalTag is nil means it's state is other than connected.
    // 'dropFirst()' to ignore first nil value, when previous and current state having only one value.
    tagOrNilPublisher?.dropFirst()
      .sink { [weak self] optionalTag in
        guard let self = self else { return }
        if optionalTag != nil {
          self.isTagConnected = true
          self.updateGearState(nil, isTagDisconnected: false)
        } else {
          self.isTagConnected = false
          self.updateGearState(nil)
        }
        self.updateDataSource()
      }.addTo(&observers)

    tagPublisher = tagOrNilPublisher?.compactMap { $0 }.eraseToAnyPublisher()

    // Step 3.
    // Subscribe to the tag publisher, to fetch details about the current state and other events.
    self.observerTagPublisher()
  }

  /// Subscribe to Tag events.
  private func observerTagPublisher() {

    guard let tagPublisher = tagPublisher else {
      assertionFailure(
        "Tag Publisher unavailable, cannot subscribe for events. This should ideally never happen")
      return
    }

    // Subscribe to tag name changes.
    tagPublisher.flatMap {
      $0.namePublisher.combineLatest(Just($0.identifier))
    }.sink { [weak self] nameAndIdentifier in
      guard let self = self else { return }
      self.tagNameLabel.text = nameAndIdentifier.0
    }.addTo(&observers)

    // Subscribe to gear connection events.
    tagPublisher
      .flatMap { $0.connectedGear }
      .sink { [weak self] gear in
        guard let self = self else { return }
        self.updateGearState(gear, isTagDisconnected: false)
        self.updateDataSource()
      }.addTo(&observers)

    // Register for tag notifications. e.g. Battery status.
    tagPublisher.sink { tag in
      tag.registerSubscriptions(self.createSubscriptions)
    }.addTo(&observers)
  }

  /// Subscribe to tag notifications.
  private func createSubscriptions(_ tag: SubscribableTag) {
    // Battery notification subscription is needed to get charging state and battery percentages.
    let subscription = BatteryStatusNotificationSubscription()
    tag.subscribe(subscription)
      .sink { [weak self] response in
        guard let self = self else { return }
        self.updateBatteryStatus(response)
      }.addTo(&observers)
  }
}

// MARK: UICollectionViewDelegateFlowLayout

extension DashboardViewController: UICollectionViewDelegateFlowLayout {

  func collectionView(
    _ collectionView: UICollectionView,
    layout collectionViewLayout: UICollectionViewLayout,
    insetForSectionAt section: Int
  ) -> UIEdgeInsets {
    return UIEdgeInsets(
      top: 0,
      left: Constants.sectionEdgeInsetMargin,
      bottom: Constants.sectionEdgeInsetMargin,
      right: Constants.sectionEdgeInsetMargin
    )
  }

  func collectionView(
    _ collectionView: UICollectionView,
    layout collectionViewLayout: UICollectionViewLayout,
    minimumInteritemSpacingForSectionAt section: Int
  ) -> CGFloat {
    return Constants.minimumInteritemSpacing
  }

  func collectionView(
    _ collectionView: UICollectionView,
    layout collectionViewLayout: UICollectionViewLayout,
    sizeForItemAt indexPath: IndexPath
  ) -> CGSize {
    let marginsAndInsets =
      (Constants.sectionEdgeInsetMargin * 2)
      + collectionView.safeAreaInsets.left
      + collectionView.safeAreaInsets.right
      + (Constants.minimumInteritemSpacing * CGFloat(Constants.cellsPerRow - 1))

    let itemWidth =
      ((UIScreen.main.bounds.width - marginsAndInsets) / CGFloat(Constants.cellsPerRow))
      .rounded(.down)

    return CGSize(width: itemWidth, height: Constants.itemHeight)
  }

  func collectionView(
    _ collectionView: UICollectionView,
    layout collectionViewLayout: UICollectionViewLayout,
    minimumLineSpacingForSectionAt section: Int
  ) -> CGFloat {
    return Constants.minimumLineSpacing
  }
}

// MARK: UICollectionViewDelegate

extension DashboardViewController: UICollectionViewDelegate {

  func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
    collectionView.deselectItem(at: indexPath, animated: true)

    let selectedItem = diffableDataSource.itemIdentifier(for: indexPath)
    switch selectedItem?.feature {
    case .gestures:
      showGesturesScreen()
    case .haptics:
      showHapticScreen()
    case .led:
      showLEDScreen()
    case .capVisualizer:
      showCapacitiveVisualization()
    case .rename:
      showRenameTagScreen()
    case .tagManager:
      showTagManagerScreen()
    case .musicalThread:
      showMusicalThreadsScreen()
    default:
      MDCSnackbarManager.default.show(MDCSnackbarMessage(text: "Feature coming soon..."))
    }
  }

  private func showGesturesScreen() {
    let gesturesVC = GesturesViewController(tagPublisher: tagPublisher!)
    navigationController?.pushViewController(gesturesVC, animated: true)
  }

  private func showHapticScreen() {
    let hapticVC = HapticViewController(tagPublisher: tagPublisher!)
    navigationController?.pushViewController(hapticVC, animated: true)
  }

  private func showLEDScreen() {
    let ledVC = LEDViewController(tagPublisher: tagPublisher!)
    navigationController?.pushViewController(ledVC, animated: true)
  }

  private func showCapacitiveVisualization() {
    let nextVC = CapacitiveVisualizerViewController(tagPublisher: tagPublisher!)
    self.navigationController?.pushViewController(nextVC, animated: true)
  }

  private func showRenameTagScreen() {
    let renameTagVC = RenameTagViewController(tagPublisher: tagPublisher!)
    navigationController?.pushViewController(renameTagVC, animated: true)
  }

  private func showTagManagerScreen() {
    let tagManagerVC = TagManagerViewController(tagPublisher: tagPublisher)
    navigationController?.pushViewController(tagManagerVC, animated: true)
  }

  private func showMusicalThreadsScreen() {
    let nextVC = MusicalThreadsViewController(tagPublisher: tagPublisher!)
    navigationController?.pushViewController(nextVC, animated: true)
  }
}

// MARK: Collection view set up

extension DashboardViewController {

  private func setupCollectionView() {
    dashboardCollectionView.contentInsetAdjustmentBehavior = .always

    // Register collection cell class.
    dashboardCollectionView.register(
      UINib(nibName: String(describing: DashboardCell.self), bundle: nil),
      forCellWithReuseIdentifier: Constants.reuseIdentifier
    )

    // Register header view class.
    dashboardCollectionView.register(
      UINib(nibName: String(describing: DashboardHeaderView.self), bundle: nil),
      forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
      withReuseIdentifier: Constants.headerReuseIdentifier
    )
  }
}

// MARK: Collection view data source.

extension DashboardViewController {

  private func configureCollectionDataSource() {

    diffableDataSource = UICollectionViewDiffableDataSource<Section, DashboardItem>(
      collectionView: dashboardCollectionView
    ) {
      (collectionView, indexPath, item) -> UICollectionViewCell? in
      let cell = collectionView.dequeueReusableCell(
        withReuseIdentifier: Constants.reuseIdentifier,
        for: indexPath
      )
      guard let dashboardCell = cell as? DashboardCell else { return cell }
      dashboardCell.configure(item)
      return cell
    }

    diffableDataSource.supplementaryViewProvider = {
      (
        collectionView: UICollectionView,
        kind: String,
        indexPath: IndexPath
      ) -> UICollectionReusableView? in

      let headerView =
        collectionView.dequeueReusableSupplementaryView(
          ofKind: kind,
          withReuseIdentifier: Constants.headerReuseIdentifier,
          for: indexPath
        ) as? DashboardHeaderView

      headerView?.configure(headerText: Section(rawValue: indexPath.section)?.title ?? "")
      return headerView
    }

    dashboardCollectionView.dataSource = diffableDataSource
  }
}

// MARK: UIHelper methods

extension DashboardViewController {

  private func updateDataSource() {
    let gesture = DashboardItem(
      name: "Gestures",
      description: "Learn how to perform gestures with your product",
      enabled: isGearConnected,
      feature: .gestures
    )
    let haptics = DashboardItem(
      name: "Haptics",
      description: "Choose individual vibrations or create patterns",
      enabled: isGearConnected,
      feature: .haptics
    )
    let leds = DashboardItem(
      name: "LED",
      description: "Select different colors or create patterns",
      enabled: isTagConnected || isGearConnected,
      feature: .led
    )
    let renameTag = DashboardItem(
      name: "Rename Tag",
      description: "Give the current active tag a custom name",
      enabled: isTagConnected || isGearConnected,
      feature: .rename
    )
    let tagManager = DashboardItem(
      name: "Tag Manager",
      description: "Add, remove, or manage your Jacquard tags",
      enabled: true,
      feature: .tagManager
    )
    let capacitiveVisualizer = DashboardItem(
      name: "Cap. Visualizer",
      description: "View capacitive values of touch sensor lines ",
      enabled: isGearConnected,
      feature: .capVisualizer
    )
    let musicalThreads = DashboardItem(
      name: "Musical Threads",
      description: "",
      enabled: isGearConnected,
      feature: .musicalThread
    )

    let apiItems = [gesture, haptics, leds, capacitiveVisualizer, renameTag, tagManager]
    let sampleUseCaseItems = [musicalThreads]

    var snapshot = NSDiffableDataSourceSnapshot<Section, DashboardItem>()
    snapshot.appendSections([.apis, .sampleUseCases])
    snapshot.appendItems(apiItems, toSection: .apis)
    snapshot.appendItems(sampleUseCaseItems, toSection: .sampleUseCases)
    self.diffableDataSource.apply(snapshot)
  }

  private func updateBatteryStatus(_ response: BatteryStatus) {
    let chargingStatus = response.chargingState == .charging ? "Charging" : "Not Charging"
    batteryStatusLabel.text = "Battery: \(response.batteryLevel)%, \(chargingStatus)"
  }

  private func updateGearState(_ gear: Component?, isTagDisconnected: Bool = true) {
    if let gear = gear {
      let product = gear.product
      gearImageView.image = UIImage(named: "\(product.image)")
      gearNameLabel.text = product.name
      connectionStatusView.backgroundColor = .gearConnected
      gearNameLabel.textColor = .enabledText
      isGearConnected = true
      MDCSnackbarManager.default.dismissAndCallCompletionBlocks(withCategory: nil)
    } else {
      gearImageView.image = UIImage(named: "Gear_Not_Attached")
      var errorMessage = ""
      if isTagDisconnected {
        errorMessage = Constants.tagDisconnectedSnackbarMessage
        gearNameLabel.text = "Disconnected"
      } else {
        errorMessage = Constants.tagNotAttachedSnackbarMessage
        gearNameLabel.text = "Not Attached"
      }
      connectionStatusView.backgroundColor = .gearDisconnected
      gearNameLabel.textColor = .disabledText
      isGearConnected = false
      MDCSnackbarManager.default.show(MDCSnackbarMessage(text: errorMessage))
    }
  }
}
