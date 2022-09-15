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
    static let tagDisconnectedSnackbarActionText = "HELP"
    static let tagDisconnectedAlertTitle = "Tag is disconnected"
    static let tagDisconnectedAlertDescription = """
      Tag is disconnected because of any of the reason below -\n
      """
    static let tagDisconnectedReason = "Out of range\nBattery drained\nSleep mode\nBluetooth is OFF"
    static let alertAcceptButtonText = "Got It"
    static let inaccessibleFeatureSnackbarMessage =
      "This feature will not work because firmware update is in progress"
    static let selectedAsCurrentTag = "Selected As Current Tag"
    static let unknownBatteryStatus = "Battery: --"
  }

  // MARK: IBOutlets

  @IBOutlet private weak var connectionStatusView: UIView!
  @IBOutlet private weak var tagNameLabel: UILabel!
  @IBOutlet private weak var gearNameLabel: UILabel!
  @IBOutlet private weak var gearImageView: UIImageView!
  @IBOutlet private weak var batteryStatusLabel: UILabel!
  @IBOutlet private weak var rssiLabel: UILabel!
  @IBOutlet private weak var dashboardCollectionView: UICollectionView!
  @IBOutlet private weak var dashboardCollectionViewBottomConstraint: NSLayoutConstraint!

  // MARK: Instance vars

  private var diffableDataSource: UICollectionViewDiffableDataSource<Section, DashboardItem>!
  /// Responsible for connecting to a Jacquard Tag.
  private var connectionStream: AnyPublisher<TagConnectionState, Never>?
  /// Publisher that delivers events from a connected Jacquard Tag.
  private var tagPublisher: AnyPublisher<ConnectedTag, Never>?
  /// Collection of subscribers.
  private var observers = [AnyCancellable]()
  private var notificationCancellable: Cancellable?
  private var remainingTagConnectCancellable: Cancellable?
  private var isGearConnected = false
  private var isTagConnected = false
  /// Currently selected Jacquard Tag identifier.
  private var selectedTagIdentifier: UUID?
  private var timerPublisher: Timer.TimerPublisher?
  private var bottomProgressController: BottomProgressController?
  private var connectedTag: ConnectedTag?

  // MARK: View life cycle

  override func viewDidLoad() {
    super.viewDidLoad()
    setupCollectionView()
    configureCollectionDataSource()
    updateDataSource()
    updateUI()
    initiateConnectionForKnownTags()
    subscribeSelectCurrentTagEvents()
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    navigationController?.isNavigationBarHidden = true
  }

  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    navigationController?.isNavigationBarHidden = false
  }

  /// To update dashboard after setting the current tag on tag details screen.
  private func subscribeSelectCurrentTagEvents() {
    let publisher = NotificationCenter.default.publisher(for: Notification.Name("setCurrentTag"))
    // Holding `NotificationCenter` cancellable separately so that it will not remove when we remove
    // all observers for previously selected tag.
    notificationCancellable = publisher
      .receive(on: DispatchQueue.main)
      .sink { [weak self] _ in
        guard let self = self else { return }

        if let selectedTagName = Preferences.knownTags.first?.displayName {
          MDCSnackbarManager.default.show(
            MDCSnackbarMessage(text: "\(selectedTagName) \(Constants.selectedAsCurrentTag)"))
        }

        self.updateUI()
        self.updateDataSource()
      }
  }

  private func updateUI() {
    guard let currentTag = Preferences.knownTags.first else {
      assertionFailure("We should always have a known tag before landing on this screen.")
      return
    }

    tagNameLabel.text = Preferences.knownTags.first?.displayName ?? "Unknown"
    batteryStatusLabel.text = Constants.unknownBatteryStatus

    if currentTag.identifier == selectedTagIdentifier {
      // SelectedTagIdentifier has not changed, no need for re-connection.
      // As we are cancelling all subscriptions on viewDidDisappear, subscribe to tag events again.
      observerTagPublisher()
      print("(\(currentTag.displayName)) SelectedTagIdentifier has not changed skip reconnection")
    } else {
      // Remove all existing observers for previous tag.
      observers.removeAll()
      // Initiate tag connection if
      // `selectedTagIdentifier == nil`, means this is first launch, or
      // The selected tag has changed, so connect to the newly selected tag.
      selectedTagIdentifier = currentTag.identifier
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
          self.batteryStatusLabel.text = Constants.unknownBatteryStatus
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
        if case .disconnected(let error) = state {
          if case .peerRemovedPairingInfo = error as? TagConnectionError {
            self.displaySnackbar(
              "Pairing info is not present on the tag. Please forget the tag from device BT settings and pair again."
            )
          }
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

    tagOrNilPublisher?
      .sink { [weak self] optionalTag in
        guard let self = self else { return }
        if optionalTag != nil {
          self.isTagConnected = true
          if optionalTag?.identifier == self.selectedTagIdentifier {
            self.updateGearState(nil, isTagDisconnected: false)
          }
        } else {
          self.isTagConnected = false
          self.updateGearState(nil)
        }
        if self.connectedTag != nil && optionalTag == nil {
          self.showTagDisconnectedSnackbar()
        }
        self.connectedTag = optionalTag
        self.updateDataSource()
      }.addTo(&observers)

    tagPublisher = tagOrNilPublisher?.compactMap { $0 }.eraseToAnyPublisher()

    // Step 3.
    // Subscribe to the tag publisher, to fetch details about the current state and other events.
    self.observerTagPublisher()
    self.subscribeForFirmwareStates()
  }

  // Silently connect previously known tags to support multi-tag functionalities.
  private func initiateConnectionForKnownTags() {
    remainingTagConnectCancellable = sharedJacquardManager.centralState
      .sink { state in
        switch state {
        case .poweredOn:
          // Current tag connection is already handled. So, initiating connection only for the
          // remaining known tags.
          let remainingTags = Preferences.knownTags.dropFirst()
          remainingTags.forEach { knownTag in
            let _ = sharedJacquardManager.connect(knownTag.identifier)
          }
        default:
          break
        }
      }
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
        if gear == nil {
          MDCSnackbarManager.default.show(
            MDCSnackbarMessage(text: Constants.tagNotAttachedSnackbarMessage))
        }
        self.updateDataSource()
      }.addTo(&observers)

    // Register for tag notifications. e.g. Battery status.
    tagPublisher.sink { tag in
      tag.registerSubscriptions(self.createSubscriptions)
    }.addTo(&observers)

    // Read signal strength for tag.
    tagPublisher.sink { [weak self] tag in
      guard let self = self else { return }
      self.timerPublisher = Timer.publish(every: 1.0, on: .main, in: .common)
      self.timerPublisher?.autoconnect().sink { _ in
        tag.readRSSI()
      }.addTo(&self.observers)

      tag.rssiPublisher
        .sink { [weak self] rssiValue in
          guard let self = self, tag.identifier == self.selectedTagIdentifier else { return }
          self.rssiLabel.text = "RSSI: \(rssiValue)"
          self.rssiLabel.textColor = UIColor.signalColor(rssiValue)
        }.addTo(&self.observers)
    }.addTo(&observers)
  }

  /// Subscribe to tag notifications.
  private func createSubscriptions(_ tag: SubscribableTag) {
    // Battery notification subscription is needed to get charging state and battery percentages.
    let subscription = BatteryStatusNotificationSubscription()
    tag.subscribe(subscription)
      .receive(on: DispatchQueue.main)
      .sink { [weak self] response in
        guard let self = self else { return }
        self.updateBatteryStatus(response)
      }.addTo(&observers)
  }

  private func subscribeForFirmwareStates() {
    guard let tagPublisher = tagPublisher else {
      print(
        "Tag Publisher unavailable, cannot subscribe for events. This should ideally never happen")
      return
    }

    tagPublisher
      .flatMap { $0.firmwareUpdateManager.state }
      .sink { [weak self] state in
        guard let self = self else { return }
        switch state {
        case .idle: break
        case .preparingForTransfer:
          self.showBottomProgressView()
        case .transferring(let progress):
          if let bottomProgressController = self.bottomProgressController {
            bottomProgressController.progress = progress
          }
        case .transferred:
          if let bottomProgressController = self.bottomProgressController {
            bottomProgressController.progress = 100.0
            self.hideBottomProgressView()

            if !UserDefaults.standard.autoUpdateSwitch {
              let action = MDCSnackbarMessageAction()
              let actionHandler = { [weak self] () in
                guard let self = self else { return }
                let firmwareUpdatesView =
                  FirmwareUpdatesViewController(connectionStream: self.connectionStream)
                DispatchQueue.main.async {
                  self.navigationController?.pushViewController(
                    firmwareUpdatesView, animated: true)
                }
              }
              action.handler = actionHandler
              action.title = "CONTINUE"
              self.displaySnackbar("Firmware update is almost ready.", action: action)
            }
          }
        case .executing:
          self.displaySnackbar(
            "Jacquard Tag will reboot. You might not be able to use the product for a few seconds.")
        case .completed:
          if let bottomProgressController = self.bottomProgressController {
            bottomProgressController.progress = 100.0
            self.hideBottomProgressView()
          }
          self.displaySnackbar("Firmware update is completed.")
        case .error(.lowBattery):
          self.hideBottomProgressView()
          self.displaySnackbar(
            """
            Tag battery level is too low. Charge your tag until LED is white, then you can continue.
            """)
        case .error(let error):
          print("Something went wrong with firmware update - \(error.localizedDescription)")
          self.hideBottomProgressView()
          self.displaySnackbar(error.localizedDescription)
        case .stopped:
          self.hideBottomProgressView()
        }
      }.addTo(&observers)
  }

  private func showBottomProgressView() {
    guard bottomProgressController == nil else {
      print("Firmware update progress view already been presented.")
      return
    }
    let bottomProgressController = BottomProgressController()
    addChild(bottomProgressController)
    view.addSubview(bottomProgressController.view)
    bottomProgressController.didMove(toParent: self)
    self.bottomProgressController = bottomProgressController

    let bottomProgressView: UIView = bottomProgressController.view
    let bottomProgressViewHeight = 71 + view.safeAreaInsets.bottom
    NSLayoutConstraint.activate([
      bottomProgressView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      bottomProgressView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      bottomProgressView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
      bottomProgressView.heightAnchor.constraint(equalToConstant: bottomProgressViewHeight),
    ])

    dashboardCollectionViewBottomConstraint.constant = bottomProgressViewHeight
    view.layoutIfNeeded()
  }

  private func hideBottomProgressView() {
    bottomProgressController?.view.removeFromSuperview()
    bottomProgressController?.removeFromParent()
    bottomProgressController = nil
    dashboardCollectionViewBottomConstraint.constant = 0
    view.layoutIfNeeded()
  }

  private func displaySnackbar(_ message: String, action: MDCSnackbarMessageAction? = nil) {
    guard let navigationController = self.navigationController,
      !(navigationController.children.contains(where: { $0 is FirmwareUpdatesViewController }))
    else {
      print("No need to show snackbar on `FirmwareUpdatesViewController` screen.")
      return
    }
    let snackbarMessage = MDCSnackbarMessage(text: message)
    if let snackbarAction = action {
      snackbarMessage.action = snackbarAction
      MDCSnackbarManager.default.setButtonTitleColor(.white, for: .normal)
    }
    DispatchQueue.main.async {
      MDCSnackbarManager.default.show(snackbarMessage)
    }
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
    var nextViewController: UIViewController?
    switch selectedItem?.feature {
    case .gestures:
      nextViewController = UIHostingController(
        rootView: GestureObserveView(tagPublisher: tagPublisher!))
    case .haptics:
      nextViewController = UIHostingController(rootView: HapticView(tagPublisher: tagPublisher!))
    case .led:
      nextViewController = UIHostingController(rootView: LEDView(tagPublisher: tagPublisher!))
    case .capVisualizer:
      nextViewController = CapacitiveVisualizerViewController(tagPublisher: tagPublisher!)
    case .rename:
      navigate(RenameTagViewController(tagPublisher: tagPublisher!))
    case .tagManager:
      navigate(TagManagerViewController(tagPublisher: tagPublisher))
    case .firmwareUpdates:
      nextViewController = FirmwareUpdatesViewController(connectionStream: connectionStream)
    case .musicalThread:
      nextViewController = MusicalThreadsViewController(tagPublisher: tagPublisher!)
    case .imu:
      navigate(IMUViewController(tagPublisher: tagPublisher!))
    case .imuStreaming:
      navigate(IMUStreamingViewController(tagPublisher: tagPublisher!))

    case .places:
      if PlacesViewModel.shared.assignedGesture == .noInference
        || !PlacesViewModel.shared.isLocationPermissionEnabled()
      {
        nextViewController = PlacesGestureSelectionViewController(
          tagPublisher: tagPublisher!,
          hideAssignFAB: false
        )
      } else {
        nextViewController = PlacesListViewController(tagPublisher: tagPublisher!)
      }
    default:
      MDCSnackbarManager.default.show(MDCSnackbarMessage(text: "Feature coming soon..."))
    }
    if let viewController = nextViewController {
      navigationController?.pushViewController(viewController, animated: true)
    }
  }

  private var isFirmwareUpdateInProgress: AnyPublisher<Bool, Never> {
    guard isTagConnected, let tagPublisher = tagPublisher else {
      return Just<Bool>(false).eraseToAnyPublisher()
    }

    return
      tagPublisher
      .flatMap { tag -> AnyPublisher<Bool, Never> in
        return tag.firmwareUpdateManager.state
          .flatMap { state -> AnyPublisher<Bool, Never> in
            switch state {
            case .idle, .completed, .error:
              return Just<Bool>(false).eraseToAnyPublisher()
            default:
              return Just<Bool>(true).eraseToAnyPublisher()
            }
          }.eraseToAnyPublisher()
      }.eraseToAnyPublisher()
  }

  private func navigate(_ viewController: UIViewController) {
    isFirmwareUpdateInProgress
      .prefix(1)
      .sink { [weak self] updateInProgress in
        guard let self = self else { return }
        DispatchQueue.main.async {
          if updateInProgress {
            MDCSnackbarManager.default.show(
              MDCSnackbarMessage(text: Constants.inaccessibleFeatureSnackbarMessage)
            )
          } else {
            self.navigationController?.pushViewController(viewController, animated: true)
          }
        }
      }.addTo(&observers)
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
      name: "Capacitive Sense Visualizer",
      description: "View capacitive values of touch sensor lines",
      enabled: isGearConnected,
      feature: .capVisualizer
    )
    let musicalThreads = DashboardItem(
      name: "Musical Threads",
      description: "",
      enabled: isGearConnected,
      feature: .musicalThread
    )
    let firmwareUpdate = DashboardItem(
      name: "Firmware Updates",
      description: "Install the latest updates",
      enabled: isTagConnected,
      feature: .firmwareUpdates
    )
    let placesSample = DashboardItem(
      name: "Places",
      description: "",
      enabled: isGearConnected,
      feature: .places
    )

    let imuDataCollection = DashboardItem(
      name: "Motion Capture",
      description: "Record IMU motion sensor data",
      enabled: isTagConnected,
      feature: .imu
    )

    let imuStreaming = DashboardItem(
      name: "IMU Streaming",
      description: "See IMU motion sensor data streaming",
      enabled: isTagConnected,
      feature: .imuStreaming
    )

    let apiItems = [
      gesture,
      haptics,
      leds,
      capacitiveVisualizer,
      renameTag,
      tagManager,
      firmwareUpdate,
      imuDataCollection,
      imuStreaming,
    ]
    let sampleUseCaseItems = [musicalThreads, placesSample]

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
      if isTagDisconnected {
        gearNameLabel.text = "Disconnected"
        rssiLabel.text = ""
        timerPublisher?.connect().cancel()
      } else {
        gearNameLabel.text = "Not Attached"
      }
      connectionStatusView.backgroundColor = .gearDisconnected
      gearNameLabel.textColor = .disabledText
      isGearConnected = false
    }
  }

  private func showTagDisconnectedSnackbar() {
    let action = MDCSnackbarMessageAction()
    let actionHandler = { [weak self] () in
      guard let self = self else { return }
      self.showTagDisconnectedHelpAlert()
    }
    action.handler = actionHandler
    action.title = Constants.tagDisconnectedSnackbarActionText
    let message = MDCSnackbarMessage(text: Constants.tagDisconnectedSnackbarMessage)
    message.action = action
    MDCSnackbarManager.default.setButtonTitleColor(.white, for: .normal)
    MDCSnackbarManager.default.show(message)
  }

  private func showTagDisconnectedHelpAlert() {
    let alertViewController = AlertViewController()
    let paragraphStyle = NSMutableParagraphStyle()
    paragraphStyle.lineHeightMultiple = 1.28

    let attributedDescription = NSMutableAttributedString(
      string: Constants.tagDisconnectedAlertDescription + Constants.tagDisconnectedReason,
      attributes: [
        NSAttributedString.Key.kern: 0.25,
        NSAttributedString.Key.paragraphStyle: paragraphStyle,
      ]
    )
    let range = NSString(
      string: attributedDescription.string
    ).range(of: Constants.tagDisconnectedReason)
    attributedDescription.addAttributes(
      [
        NSAttributedString.Key.foregroundColor: UIColor.alertDescription,
        NSAttributedString.Key.font: UIFont.systemFont(ofSize: 16, weight: .medium) as Any,
      ],
      range: range
    )

    alertViewController.configureAlertView(
      attibutedTitle: NSAttributedString(string: Constants.tagDisconnectedAlertTitle),
      attibutedDescription: attributedDescription,
      acceptButtonTitle: Constants.alertAcceptButtonText,
      acceptAction: nil,
      cancelAction: nil
    )
    alertViewController.modalPresentationStyle = .custom
    alertViewController.modalTransitionStyle = .crossDissolve
    AppDelegate.topViewController?.present(alertViewController, animated: true)
  }
}
