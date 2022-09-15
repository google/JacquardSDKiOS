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

class TagManagerViewController: UIViewController {

  struct TagCellModel: Hashable {
    var tag: JacquardTag
    var status = "Disconnected"
    var statusColor = UIColor.defaultDFUStatus

    static func == (lhs: TagCellModel, rhs: TagCellModel) -> Bool {
      return lhs.tag.identifier == rhs.tag.identifier
    }

    func hash(into hasher: inout Hasher) {
      tag.identifier.hash(into: &hasher)
    }
  }

  private enum DFUStatus {
    case tagNotConnected
    case checkingUpdate
    case checkUpdateError
    case noUpdates
    case uploading(Int)
    case lowBattery
    case tagDisconnected
    case uploaded
    case executing
    case completed
    case stopped

    var description: String {
      switch self {
      case .tagNotConnected: return "Not connected"
      case .checkingUpdate: return "Checking for update"
      case .checkUpdateError: return "Check update error"
      case .noUpdates: return "No updates"
      case .uploading(let progress): return "Uploading(\(progress)%)"
      case .lowBattery: return "Low Battery"
      case .tagDisconnected: return "Tag disconnected"
      case .uploaded: return "Uploaded"
      case .executing: return "Executing"
      case .completed: return "Completed"
      case .stopped: return "Stopped"
      }
    }
  }

  private enum Constants {
    static let updateAllTags = "Update all Tags"
    static let done = "Done"
    static let turnOnBluetooth = "Turn on bluetooth"
  }

  private var observations = [Cancellable]()
  private var isDFUInProgress: Bool {
    return dfuTracker != 0
  }

  private var dfuTracker: Int = 0 {
    didSet {
      updateButtonStates()
    }
  }

  @IBOutlet private weak var tagsTableView: UITableView!
  @IBOutlet private weak var updateAllTagsButton: GreyRoundCornerButton!
  @IBOutlet private weak var stopUpdateButton: RedRoundCornerButton!

  // Publishes a value every time the tag connects or disconnects.
  private var tagPublisher: AnyPublisher<ConnectedTag, Never>?
  private var currentJacquardTag: JacquardTag?
  private var observers = [AnyCancellable]()
  private var isBluetoothConnected = false

  /// Datasource model.
  private var connectedTagModels = [TagCellModel]()

  init(tagPublisher: AnyPublisher<ConnectedTag, Never>?) {
    self.tagPublisher = tagPublisher
    super.init(nibName: "TagManagerViewController", bundle: nil)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func viewDidLoad() {
    super.viewDidLoad()

    let addBarButtonItem = UIBarButtonItem(
      barButtonSystemItem: .add,
      target: self,
      action: #selector(addNewTag)
    )
    navigationItem.rightBarButtonItem = addBarButtonItem

    let backButton = UIBarButtonItem(
      image: UIImage(named: "back"), style: .plain, target: self,
      action: #selector(self.backButtonTapped))
    navigationItem.leftBarButtonItem = backButton
    navigationItem.leftBarButtonItem?.tintColor = .black

    // Configure table view.
    let nib = UINib(nibName: String(describing: ConnectedTagTableViewCell.self), bundle: nil)
    tagsTableView.register(
      nib,
      forCellReuseIdentifier: ConnectedTagTableViewCell.reuseIdentifier
    )
    updateAllTagsButton.setTitle(Constants.updateAllTags, for: .normal)

    sharedJacquardManager.centralState
      .sink { state in
        switch state {
        case .poweredOn:
          self.isBluetoothConnected = true
        case .poweredOff, .unknown, .resetting, .unsupported, .unauthorized:
          self.isBluetoothConnected = false
          MDCSnackbarManager.default.show(MDCSnackbarMessage(text: Constants.turnOnBluetooth))
        default:
          break
        }
      }.addTo(&observers)
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    configureTableDataSource()
  }

  override func viewDidDisappear(_ animated: Bool) {
    super.viewDidDisappear(animated)
    observations.removeAll()
  }

  @objc private func backButtonTapped() {
    if isDFUInProgress {
      MDCSnackbarManager.default.show(
        MDCSnackbarMessage(text: "You need to stop the update to leave the page")
      )
    } else {
      navigationController?.popViewController(animated: true)
    }
  }

  @IBAction func updateAllTagsButtonTapped(_ sender: Any) {
    guard isBluetoothConnected else {
      MDCSnackbarManager.default.show(MDCSnackbarMessage(text: Constants.turnOnBluetooth))
      return
    }
    if updateAllTagsButton.title(for: .normal) == Constants.updateAllTags {
      let alertDescription =
        """
        Please do not disconnect tags while the update is in progress.
        Update may include Tag, Interposer and Loadable modules.
        """
      let acceptHandler: () -> Void = { [weak self] in
        self?.performUpdateForAllConnectedTags()
      }
      showAlert(
        title: "Info",
        description: alertDescription,
        acceptTitle: "Got It",
        cancelTitle: "Cancel",
        acceptHandler: acceptHandler
      )
    } else {
      updateAllTagsButton.setTitle(Constants.updateAllTags, for: .normal)
      dfuTracker = 0
    }
  }

  @IBAction func stopUpdateButtonTapped(_ sender: Any) {
    guard isBluetoothConnected else {
      MDCSnackbarManager.default.show(MDCSnackbarMessage(text: Constants.turnOnBluetooth))
      return
    }
    let acceptHandler: () -> Void = { [weak self] in
      guard let self = self else { return }
      self.stopUpdatesForAllConnectedTags()
    }
    showAlert(
      title: "Stop update",
      description: "Are you sure you want to stop update for all the Tags?",
      acceptTitle: "Stop update",
      cancelTitle: "Cancel",
      acceptHandler: acceptHandler
    )
  }

  private func showAlert(
    title: String,
    description: String,
    acceptTitle: String,
    cancelTitle: String,
    acceptHandler: AcceptActionHandler?
  ) {
    let alertViewController = AlertViewController()
    alertViewController.configureAlertView(
      title: title,
      description: description,
      acceptButtonTitle: acceptTitle,
      cancelButtonTitle: cancelTitle,
      acceptAction: acceptHandler,
      cancelAction: nil
    )
    alertViewController.modalPresentationStyle = .custom
    alertViewController.modalTransitionStyle = .crossDissolve
    present(alertViewController, animated: true)
  }

  private func performUpdateForAllConnectedTags() {
    for knownTag in Preferences.knownTags {
      sharedJacquardManager.getConnectedTag(for: knownTag.identifier)
        .prefix(1)
        .sink { [weak self] tag in
          if let tag = tag {
            // Tag connected, perform DFU.
            self?.dfuTracker += 1
            print("Checking updates for \(tag.identifier)")
            self?.updateDFUStatusForTag(tag.identifier, status: .checkingUpdate)
            self?.checkAndApplyUpdates(for: tag)
          } else {
            print("Connected tag: \(knownTag.identifier) not available.")
            self?.updateDFUStatusForTag(knownTag.identifier, status: .tagNotConnected)
          }
        }.addTo(&observations)
    }
  }

  private func checkAndApplyUpdates(for tag: ConnectedTag) {

    var updateList: [DFUUpdateInfo] = []

    tag.firmwareUpdateManager.checkUpdates(forceCheck: true)
      .sink { [weak self] completion in
        guard let self = self else { return }
        if case .failure(let error) = completion {
          print(
            "Check update error \(error.localizedDescription) for tag \(tag.identifier)")
          self.updateDFUStatusForTag(tag.identifier, status: .checkUpdateError)
          self.dfuTracker -= 1
          let errorMessage = "Error: `\(error.localizedDescription)` for tag `\(tag.displayName)`."
          MDCSnackbarManager.default.show(MDCSnackbarMessage(text: errorMessage))
        }
      } receiveValue: { [weak self] updates in
        guard let self = self else { return }
        updateList.append(contentsOf: updates)

        tag.firmwareUpdateManager.checkModuleUpdates(forceCheck: true)
          .prefix(1)
          .sink { [weak self] completion in
            guard let self = self else { return }
            // Continue applying updates for tag and interposer component, if any.
            // Ignore check module updates failure, if any.

            if case .failure(let error) = completion {
              print(
                "Check module updates error \(error.localizedDescription) for tag \(tag.identifier)"
              )
            }
            self.handleApplyUpdates(updateList, tag: tag)
          } receiveValue: {
            let moduleUpdates = $0.compactMap { result -> DFUUpdateInfo? in
              if case .success(let info) = result {
                return info
              }
              return nil
            }
            updateList.append(contentsOf: moduleUpdates)
          }.addTo(&self.observations)
      }.addTo(&self.observations)
  }

  private func handleApplyUpdates(_ updates: [DFUUpdateInfo], tag: ConnectedTag) {
    if updates.isEmpty {
      print("No updates available for tag: \(tag.identifier)")
      self.updateDFUStatusForTag(tag.identifier, status: .noUpdates)
      self.dfuTracker -= 1
    } else {
      self.applyUpdates(updates, tag: tag)
    }
  }

  private func applyUpdates(_ updates: [DFUUpdateInfo], tag: ConnectedTag) {

    tag.firmwareUpdateManager.applyUpdates(updates, shouldAutoExecute: true)
      .sink { [weak self] state in
        guard let self = self else { return }
        switch state {
        case .transferring(let progress):
          print("Uploading: \(progress) for \(tag.identifier)")
          self.updateDFUStatusForTag(
            tag.identifier, status: .uploading(Int(progress)))
        case .transferred:
          print("Transferred image for \(tag.identifier)")
          self.updateDFUStatusForTag(tag.identifier, status: .uploaded)
        case .executing:
          print("Executing image for \(tag.identifier)")
          self.updateDFUStatusForTag(tag.identifier, status: .executing)
        case .error(.lowBattery):
          print("Low battery error for \(tag.identifier)")
          self.updateDFUStatusForTag(tag.identifier, status: .lowBattery)
          self.dfuTracker -= 1
        case .error(let error):
          print("Update error \(error) for \(tag.identifier)")
          self.updateDFUStatusForTag(tag.identifier, status: .tagDisconnected)
          self.dfuTracker -= 1
        case .completed:
          print("Update completed for \(tag.identifier)")
          self.updateDFUStatusForTag(tag.identifier, status: .completed)
          self.dfuTracker -= 1
        case .stopped:
          self.updateDFUStatusForTag(tag.identifier, status: .stopped)
          self.showProcessCompleteAlert()
        default: break
        }
      }.addTo(&self.observations)
  }

  private func showProcessCompleteAlert() {
    let description =
      """
      Process is completed.
      You can check the latest status against Tag on Tag manager page.
      """
    let acceptHandler: () -> Void = { [weak self] in
      guard let self = self else { return }
      self.updateAllTagsButton.setTitle(Constants.done, for: .normal)
      self.updateAllTagsButton.isEnabled = true
      self.stopUpdateButton.isEnabled = false
      self.stopUpdateButton.isHidden = true
    }
    showAlert(
      title: "Process completed",
      description: description,
      acceptTitle: "Got it",
      cancelTitle: "",
      acceptHandler: acceptHandler
    )
  }

  private func updateDFUStatusForTag(_ identifier: UUID, status: DFUStatus) {
    guard var itemToBeModified = (connectedTagModels.first { $0.tag.identifier == identifier }),
      let selectedRow = connectedTagModels.lastIndex(of: itemToBeModified)
    else {
      print("Tag model for \(identifier) not available.")
      return
    }
    itemToBeModified.status = status.description
    switch status {
    case .tagNotConnected, .tagDisconnected, .checkUpdateError, .lowBattery:
      itemToBeModified.statusColor = UIColor.errorStatus
    default:
      itemToBeModified.statusColor = UIColor.defaultDFUStatus
    }
    connectedTagModels[selectedRow] = itemToBeModified

    tagsTableView.reloadData()
  }

  private func updateButtonStates() {
    if dfuTracker == 0 {
      updateAllTagsButton.isEnabled = true
      stopUpdateButton.isEnabled = false
      stopUpdateButton.isHidden = true
      navigationController?.navigationBar.isHidden = false
      navigationItem.rightBarButtonItem?.isEnabled = true
      tagsTableView.isUserInteractionEnabled = true
      // Set curent tag cell as selected after DFU is done.
      tagsTableView.reloadData()

      guard
        let currentTagCellModel =
          (connectedTagModels.first { $0.tag.identifier == currentJacquardTag?.identifier }),
        let rowToBeSelected = connectedTagModels.firstIndex(of: currentTagCellModel)
      else {
        print("Tag is not available: \(String(describing: currentJacquardTag?.displayName)).")
        configureTableDataSource()
        return
      }
      let indexPath = IndexPath(row: rowToBeSelected, section: 0)
      tagsTableView.selectRow(at: indexPath, animated: true, scrollPosition: .top)
    } else {
      updateAllTagsButton.isEnabled = false
      tagsTableView.isUserInteractionEnabled = false
      stopUpdateButton.isEnabled = true
      stopUpdateButton.isHidden = false
      navigationItem.rightBarButtonItem?.isEnabled = false
    }
  }

  private func stopUpdatesForAllConnectedTags() {
    for knownTag in Preferences.knownTags {
      sharedJacquardManager.connect(knownTag.identifier)
        .filter { state in
          if case .connected = state {
            return true
          }
          return false
        }
        .prefix(1)
        .sink { completion in
          switch completion {
          case .failure(let error):
            print("Connection error \(error.localizedDescription) for tag \(knownTag.identifier), ")
          case .finished: break
          }
        } receiveValue: { state in
          if case .connected(let tag) = state {
            do {
              try tag.firmwareUpdateManager.stopUpdates()
            } catch {
              print("Failed to stop updates.")
            }
          }
        }.addTo(&observations)
    }
  }
}

// Extension contains only UI logic not related to Jacquard SDK API's
extension TagManagerViewController {

  func configureTableDataSource() {
    // We need to track the currently connected tag so that the details screen can show more
    // info and disconnect if desired. The prepend(nil) is because we want the table to populate
    // even when there are no connected tags (would be better if tagPublisher propagated nil values)
    guard let tagPublisher = tagPublisher else {
      configureTableDataSource(currentConnectedTag: nil)
      return
    }
    tagPublisher
      .map { tag -> ConnectedTag? in tag }
      .prepend(nil)
      .sink(receiveValue: { [weak self] connectedTag in
        guard let self = self else { return }
        self.configureTableDataSource(currentConnectedTag: connectedTag)
      }).addTo(&observations)
  }

  private func configureTableDataSource(currentConnectedTag: ConnectedTag?) {
    currentJacquardTag = currentConnectedTag
    connectedTagModels =
      Preferences.knownTags
      .map {
        // Swap in the currently connected tag so that the details screen can show more
        // info and disconnect if desired.
        if let currentConnectedTag = currentConnectedTag,
          $0.identifier == currentConnectedTag.identifier
        {
          return TagCellModel(tag: currentConnectedTag)
        } else {
          return TagCellModel(tag: $0)
        }
      }

    tagsTableView.reloadData()
    if !connectedTagModels.isEmpty {
      let indexPath = IndexPath(row: 0, section: 0)
      tagsTableView.selectRow(at: indexPath, animated: true, scrollPosition: .top)
    }
    tagsTableView.isHidden = connectedTagModels.isEmpty
  }

  /// Initiate scanning on add new tag.
  @objc func addNewTag() {
    guard isBluetoothConnected else {
      MDCSnackbarManager.default.show(MDCSnackbarMessage(text: Constants.turnOnBluetooth))
      return
    }
    let scanningVC = ScanningViewController()
    scanningVC.shouldShowCloseButton = true
    let navigationController = UINavigationController(rootViewController: scanningVC)
    navigationController.modalPresentationStyle = .fullScreen
    present(navigationController, animated: true)
  }

  private func updateCurrentTag(_ tag: JacquardTag) {
    // Set selected tag as first tag.
    guard let index = Preferences.knownTags.firstIndex(where: { $0.identifier == tag.identifier })
    else {
      return
    }
    currentJacquardTag = tag
    let tag = Preferences.knownTags[index]
    Preferences.knownTags.remove(at: index)
    Preferences.knownTags.insert(tag, at: 0)
    NotificationCenter.default.post(name: Notification.Name("setCurrentTag"), object: nil)
    navigationController?.popViewController(animated: true)
  }
}

/// Handle Tableview delegate methods.
extension TagManagerViewController: UITableViewDelegate {

  func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    let model = connectedTagModels[indexPath.row]
    let tagDetailsVC = TagDetailsViewController(tagPublisher: tagPublisher, tag: model.tag)
    navigationController?.pushViewController(tagDetailsVC, animated: true)
  }
}

extension TagManagerViewController: UITableViewDataSource {

  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    connectedTagModels.count
  }

  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    guard
      let cell = tagsTableView.dequeueReusableCell(
        withIdentifier: ConnectedTagTableViewCell.reuseIdentifier,
        for: indexPath
      ) as? ConnectedTagTableViewCell
    else {
      return UITableViewCell()
    }
    let connectedTagCellModel = connectedTagModels[indexPath.row]
    cell.configure(with: connectedTagCellModel, dfuInProgress: isDFUInProgress)
    cell.checkboxTapped = { [weak self] in
      guard let self = self else { return }
      self.updateCurrentTag(connectedTagCellModel.tag)
    }
    return cell
  }
}
