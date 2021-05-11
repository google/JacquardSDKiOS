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

struct AdvertisingTagCellModel: Hashable {
  let tag: ConnectableTag

  static func == (lhs: AdvertisingTagCellModel, rhs: AdvertisingTagCellModel) -> Bool {
    return lhs.tag.identifier == rhs.tag.identifier
  }

  func hash(into hasher: inout Hasher) {
    tag.identifier.hash(into: &hasher)
  }
}

private enum TagSection: Int {
  case advertisingTags = 0
  case connectedTags

  var title: String {
    switch self {
    case .connectedTags: return "PREVIOUSLY CONNECTED TAGS"
    case .advertisingTags: return "NEARBY TAGS"
    }
  }
}

/// This viewcontroller showcases the usage of the Tag scanning api.
class ScanningViewController: UIViewController {

  private enum Constants {
    static let matchSerialNumberDescription =
      "Match the last 4 digits with the serial number on the back of your Tag."
    static let noTagsFound = "No new tags found nearby, still searching..."
    static let stopScanHeight: CGFloat = 50.0
    static let pairingTimeInterval: TimeInterval = 30.0
    static let pairingTimeOutMessage = "Tag pairing timed out."
  }

  private enum ButtonState: String {
    case scan = "Scan"
    case scanning = "Scanning..."
    case pair = "Pair"
    case pairing = "Pairing..."
    case paired = "Paired"
  }

  @IBOutlet private weak var tagsTableView: UITableView!
  @IBOutlet private weak var scanButton: GreyRoundCornerButton!
  @IBOutlet private weak var searchingLabel: UILabel!
  @IBOutlet private weak var scanDescriptionLabel: UILabel!
  @IBOutlet private weak var downArrowStackView: UIStackView!
  @IBOutlet private weak var stopScanButtonHeight: NSLayoutConstraint!

  private var buttonState = ButtonState.scan {
    didSet {
      self.scanButton.setTitle(buttonState.rawValue, for: .normal)
    }
  }

  private let loadingView = LoadingViewController.instance

  /// Array will hold tags which are already paired and available in iOS Bluetooth settings screen.
  private var preConnectedTags = [PreConnectedTag]()
  /// Array will hold the new advertsing tags.
  private var advertisedTags = [AdvertisedTag]()

  private var cancellables = [Cancellable]()
  private var scanDiffableDataSource:
    UITableViewDiffableDataSource<TagSection, AdvertisingTagCellModel>?
  private var selectedIndexPath: IndexPath?

  override func viewDidLoad() {
    super.viewDidLoad()
    title = "Scan and Pair Tag"
    // Sets up the Tableview before we start receving advertising tags from the publisher.
    configureTagsTableView()

    // Subscribe to the advertisingTags publisher.
    // A tag will be published evertyime an advertising Jacquard Tag is found.
    sharedJacquardManager.advertisingTags
      .sink { [weak self] tag in
        print("found tag: \(tag.pairingSerialNumber)\n")
        guard let self = self else { return }
        self.updateScanViewUI()
        self.advertisedTags.append(tag)
        self.updateDataSource()
      }.addTo(&cancellables)
  }

  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    // Stop scanning when not required.
    stopScanning()
  }

  @IBAction func stopScanButtonTapped(_ sender: UIButton) {
    stopScanning()
    buttonState = .scan
    stopScanButtonHeight.constant = 0
    if selectedIndexPath != nil {
      selectedIndexPath = nil
      tagsTableView.reloadData()
    }
  }

  @IBAction func scanButtonTapped(_ sender: UIButton) {

    if buttonState == ButtonState.pair {
      startPairing()
      return
    }

    // Remove all existing tags in list before scanning.
    resetTagsList()

    // After initiating scan, the advertisingTags subscription is called everytime a tag is found.
    // `startScanning()` only scans for advertising tags, it does not return Tags already connected.
    // see also `preConnectedTags()`
    do {
      try sharedJacquardManager.startScanning()
      buttonState = .scanning
      searchingLabel.text = ButtonState.scanning.rawValue
      searchingLabel.isHidden = false
      DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(3)) {
        self.searchingLabel.text = Constants.noTagsFound
      }
    } catch {
      // startScanning will throw an error, if Bluetooth is unavailable.
      buttonState = .scan
      searchingLabel.isHidden = true
      MDCSnackbarManager.default.show(
        MDCSnackbarMessage(text: "Error when scanning for tags, check if bluetooth is available"))
      print(error)
    }

    // Returns an array of `PreConnectedTag` objects.
    // Call `JacquardManager.preConnectedTags()` to retrive Tags already connected to the phone.
    preConnectedTags = sharedJacquardManager.preConnectedTags().sorted(
      by: { $0.displayName > $1.displayName })
    if preConnectedTags.count > 0 {
      updateScanViewUI()
      self.updateDataSource()
    }
  }

  func resetTagsList() {
    // Remove all existing tags in list before scanning.
    advertisedTags.removeAll()
    preConnectedTags.removeAll()
    updateDataSource()
  }

  private func updateScanViewUI() {
    scanDescriptionLabel.text = Constants.matchSerialNumberDescription
    downArrowStackView.isHidden = true
    stopScanButtonHeight.constant = Constants.stopScanHeight
  }

  private func startPairing() {
    guard let selectedIndexPath = selectedIndexPath else {
      return
    }

    buttonState = .pairing

    loadingView.modalPresentationStyle = .overCurrentContext
    present(loadingView, animated: true) {
      self.loadingView.startLoading(withMessage: "Pairing")
    }

    stopScanning()

    //TODO: This would be a simpler example if we get rid of the Pair button and simply pair in
    // the didSelect delegate method.

    guard let cellModel = scanDiffableDataSource?.itemIdentifier(for: selectedIndexPath) else {
      return
    }

    let connectionStream = sharedJacquardManager.connect(cellModel.tag)
    handleConnectStateChanges(connectionStream)
  }

  func stopScanning() {
    sharedJacquardManager.stopScanning()
  }

  func handleConnectStateChanges(_ connectionStream: AnyPublisher<TagConnectionState, Error>) {
    connectionStream
      .sink { [weak self] error in
        // Connection attempts never time out,
        // so an error will be received only when the connection cannot be recovered or retried.
        self?.loadingView.stopLoading(withError: "Connection Error")
        MDCSnackbarManager.default.show(MDCSnackbarMessage(text: "\(error)"))
      } receiveValue: { [weak self] connectionState in

        switch connectionState {
        case .preparingToConnect:
          self?.loadingView.indicatorProgress(0.0)
        case .connecting(let current, let total),
          .initializing(let current, let total),
          .configuring(let current, let total):
          self?.loadingView.indicatorProgress(Float(current / total))
        case .connected(let connectedTag):
          // Tag is successfully paired, you can now subscribe and retrieve the tag stream.
          print("connected to tag: \(connectedTag)")
          self?.buttonState = .paired
          self?.loadingView.stopLoading(withMessage: "Paired") {
            self?.connectionSuccessful(for: connectedTag)
          }
        case .disconnected(let error):
          print("Disconnected with error: \(String(describing: error))")
          self?.buttonState = .pair
          self?.loadingView.stopLoading()
          MDCSnackbarManager.default.show(MDCSnackbarMessage(text: "Disconnected"))
        }
      }
      .addTo(&cancellables)
  }

  func connectionSuccessful(for tag: ConnectedTag) {
    Preferences.addKnownTag(
      KnownTag(identifier: tag.identifier, name: tag.name)
    )
    let appDelegate = UIApplication.shared.delegate as? AppDelegate
    let navigationController = UINavigationController(rootViewController: DashboardViewController())
    appDelegate?.window?.rootViewController = navigationController
  }
}

// Extension contains only UI Logic not related to Jacquard SDK API's
extension ScanningViewController {

  var sortedAdvertisedTags: [AdvertisedTag] {
    return
      advertisedTags
      .sorted(by: { $0.displayName < $1.displayName })
  }

  func updateDataSource() {
    tagsTableView.isHidden = advertisedTags.isEmpty && preConnectedTags.isEmpty

    let advertisedModels =
      sortedAdvertisedTags
      .map { AdvertisingTagCellModel(tag: $0) }

    let preConnectedModels =
      preConnectedTags
      .map { AdvertisingTagCellModel(tag: $0) }

    var snapshot = NSDiffableDataSourceSnapshot<TagSection, AdvertisingTagCellModel>()

    snapshot.appendSections([.advertisingTags])
    snapshot.appendItems(advertisedModels, toSection: .advertisingTags)

    snapshot.appendSections([.connectedTags])
    snapshot.appendItems(preConnectedModels, toSection: .connectedTags)

    self.scanDiffableDataSource?.apply(snapshot)
  }

  func configureTagsTableView() {

    let nib = UINib(nibName: "ScanningTableViewCell", bundle: nil)
    tagsTableView.register(nib, forCellReuseIdentifier: ScanningTableViewCell.reuseIdentifier)

    tagsTableView.dataSource = scanDiffableDataSource
    tagsTableView.delegate = self

    scanDiffableDataSource = UITableViewDiffableDataSource<TagSection, AdvertisingTagCellModel>(
      tableView: tagsTableView,
      cellProvider: { (tagsTableView, indexPath, advTagCellModel) -> UITableViewCell? in
        guard
          let cell = tagsTableView.dequeueReusableCell(
            withIdentifier: ScanningTableViewCell.reuseIdentifier,
            for: indexPath
          ) as? ScanningTableViewCell
        else {
          assertionFailure("TagCell could not be created")
          return nil
        }
        cell.configure(with: advTagCellModel, isSelected: self.selectedIndexPath == indexPath)
        return cell
      })
  }
}

/// Handle Tableview delegate methods
extension ScanningViewController: UITableViewDelegate {

  func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
    return 45.0
  }

  func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
    let headerView = UIView(
      frame: CGRect(x: 0, y: 0, width: tableView.bounds.size.width, height: 40))
    let label = UILabel(frame: headerView.bounds)
    label.text = TagSection(rawValue: section)?.title
    headerView.addSubview(label)
    return headerView
  }

  func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    tableView.deselectRow(at: indexPath, animated: true)
    selectedIndexPath = indexPath
    tableView.reloadData()

    buttonState = .pair
    scanButton.isHidden = false
  }
}
