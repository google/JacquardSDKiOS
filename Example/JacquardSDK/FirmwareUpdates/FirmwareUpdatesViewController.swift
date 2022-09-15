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

class FirmwareUpdatesViewController: UIViewController {

  private enum Constants {
    static let tagDisconnectedSnackbarMessage = "Tag is disconnected."
    static let notAvailable = "Not available"
    // Distance between tag and phone in feet.
    static let tagDistanceFromPhone = 15.0
  }

  // MARK: - IBOutlets

  @IBOutlet private weak var tagVersionLabel: UILabel!
  @IBOutlet private weak var productVersionLabel: UILabel!
  @IBOutlet private weak var forceUpdateCheckSwitch: UISwitch!
  @IBOutlet private weak var autoUpdateSwitch: UISwitch!
  @IBOutlet private weak var loadableModuleUpdateSwitch: UISwitch!
  @IBOutlet private weak var checkFirmwareButton: GreyRoundCornerButton!
  @IBOutlet private var checkFirmwareButtonBottomConstraint: NSLayoutConstraint!

  // MARK: - Variables

  private var alertViewController: AlertViewController?
  private var firmwareUpdateProgressViewController: ProgressAlertViewController?
  private var bottomProgressController: BottomProgressController?
  private let loadingView = LoadingViewController.instance
  private let connectionStream: AnyPublisher<TagConnectionState, Never>?
  private var connectedTag: ConnectedTag?
  private var observers = [Cancellable]()
  private var isForegroundUpdateInProgress = false
  private var dfuUpdates: [DFUUpdateInfo] = []

  // MARK: - Initializers

  init(connectionStream: AnyPublisher<TagConnectionState, Never>?) {
    self.connectionStream = connectionStream
    super.init(nibName: "FirmwareUpdatesViewController", bundle: nil)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  // MARK: - View controller lifecycle methods

  override func viewDidLoad() {
    super.viewDidLoad()

    let defaults = UserDefaults.standard
    defaults
      .publisher(for: \.autoUpdateSwitch)
      .removeDuplicates()
      .sink { [weak self] value in
        self?.autoUpdateSwitch.isOn = value
      }.addTo(&observers)

    defaults
      .publisher(for: \.forceCheckUpdateSwitch)
      .removeDuplicates()
      .sink { [weak self] value in
        self?.forceUpdateCheckSwitch.isOn = value
      }.addTo(&observers)

    defaults
      .publisher(for: \.loadableModuleUpdateSwitch)
      .removeDuplicates()
      .sink { [weak self] value in
        self?.loadableModuleUpdateSwitch.isOn = value
      }.addTo(&observers)

    updateTagVersion()
    updateProductVersion()
    subscribeForTagConnection()
  }

  // MARK: - IBActions

  @IBAction private func checkFirmwareUpdateButtonTapped(_ sender: UIButton) {
    guard let tag = connectedTag else {
      MDCSnackbarManager.default.show(
        MDCSnackbarMessage(text: Constants.tagDisconnectedSnackbarMessage)
      )
      return
    }

    loadingView.modalPresentationStyle = .overCurrentContext
    present(loadingView, animated: true) {
      self.loadingView.startLoading(withMessage: "Checking for Updates")
    }

    checkFirmwareUpdates(tag)
  }

  @IBAction func forceCheckUpdateSwitchValueChanged(_ sender: UISwitch) {
    UserDefaults.standard.forceCheckUpdateSwitch = sender.isOn
  }

  @IBAction func autoUpdateSwitchValueChanged(_ sender: UISwitch) {
    UserDefaults.standard.autoUpdateSwitch = sender.isOn
  }

  @IBAction func loadableModuleUpdateSwitchValueChanged(_ sender: UISwitch) {
    UserDefaults.standard.loadableModuleUpdateSwitch = sender.isOn
  }
}

// MARK: Internal UI helper methods

extension FirmwareUpdatesViewController {

  private func updateTagVersion() {
    if isViewLoaded {
      guard let tag = connectedTag else {
        tagVersionLabel.text = Constants.notAvailable
        productVersionLabel.text = Constants.notAvailable
        return
      }
      tagVersionLabel.text = tag.tagComponent.version?.description
    }
  }

  private func updateProductVersion() {
    if isViewLoaded {
      guard let gearComponent = connectedTag?.gearComponent else {
        self.productVersionLabel.text = Constants.notAvailable
        return
      }
      self.productVersionLabel.text = gearComponent.version?.description
    }
  }

  private func enableUIControl(_ enable: Bool) {
    autoUpdateSwitch.isEnabled = enable
    forceUpdateCheckSwitch.isEnabled = enable
    checkFirmwareButton.isEnabled = enable
  }

  private func showFirmwareUpdateAvailableAlert(_ updates: [DFUUpdateInfo], tag: ConnectedTag) {
    let alertViewController = AlertViewController()
    let alertTitle = "New Jacquard update available"

    var isTagOnlyUpdate = false
    let isModuleOnlyUpdate = updates.allSatisfy { $0.mid != nil }
    if !isModuleOnlyUpdate {
      let tagComponent = tag.tagComponent
      isTagOnlyUpdate =
        updates
        .filter { $0.mid == nil }
        .allSatisfy { tagComponent.vendor.id == $0.vid && tagComponent.product.id == $0.pid }
    }

    var alertDescription = ""
    if isModuleOnlyUpdate || isTagOnlyUpdate {
      alertDescription = "There are firmware updates available for tag."
    } else {
      alertDescription = "There are firmware updates available for tag & product."
    }
    let mandateUpdate = updates.contains { $0.dfuStatus == .mandatory }

    let acceptHandler: () -> Void = { [weak self] in
      self?.applyFirmwareUpdate(updates)
    }

    alertViewController.configureAlertView(
      title: alertTitle,
      description: alertDescription,
      acceptButtonTitle: "Update",
      cancelButtonTitle: mandateUpdate == false ? "Cancel" : nil,
      acceptAction: acceptHandler,
      cancelAction: nil
    )

    alertViewController.modalPresentationStyle = .custom
    alertViewController.modalTransitionStyle = .crossDissolve
    present(alertViewController, animated: true)
  }

  private func showUpdateProgressAlert(_ tag: ConnectedTag) {
    firmwareUpdateProgressViewController = ProgressAlertViewController()
    guard let firmwareUpdateProgressViewController = firmwareUpdateProgressViewController else {
      return
    }

    var isTagOnlyUpdate = false
    let isModuleOnlyUpdate = dfuUpdates.allSatisfy { $0.mid != nil }
    if !isModuleOnlyUpdate {
      let tagComponent = tag.tagComponent
      isTagOnlyUpdate =
        dfuUpdates
        .filter { $0.mid == nil }
        .allSatisfy { tagComponent.vendor.id == $0.vid && tagComponent.product.id == $0.pid }
    }

    self.isForegroundUpdateInProgress = true
    var alertDescription = ""
    if isModuleOnlyUpdate || isTagOnlyUpdate {
      alertDescription =
        "Ensure your tag is in range. We’ll notify you when the update is completed."
    } else {
      alertDescription =
        "Keep your Tag plugged in to your product while updating. We’ll notify you when the update is completed."
    }
    let actionHandler = { [weak self] in
      guard let self = self else { return }
      self.firmwareUpdateProgressViewController = nil
      self.isForegroundUpdateInProgress = false
      self.showBottomProgressView()
    }

    firmwareUpdateProgressViewController.configureView(
      title: "Update in progress...",
      description: alertDescription,
      progressTitle: "Downloading...",
      actionTitle: "Ok",
      actionHandler: actionHandler
    )
    firmwareUpdateProgressViewController.modalPresentationStyle = .custom
    firmwareUpdateProgressViewController.modalTransitionStyle = .crossDissolve
    present(firmwareUpdateProgressViewController, animated: true)
  }

  private func showNoUpdateAvailableAlert() {
    let alertViewController = AlertViewController()
    alertViewController.configureAlertView(
      title: "No update available",
      description: "",
      acceptButtonTitle: "Got It",
      cancelButtonTitle: nil,
      acceptAction: nil,
      cancelAction: nil
    )

    alertViewController.modalPresentationStyle = .custom
    alertViewController.modalTransitionStyle = .crossDissolve
    present(alertViewController, animated: true)
  }

  private func showAlmostReadyAlert() {
    let viewController = AlertViewController()
    let alertTitle = "Almost Ready"
    let alertDescription =
      """
      Update is ready, We need to reboot your Jacquard Tag to finalize the update. You may not be \
      able to use your product for a few seconds.
      """
    alertViewController = viewController
    let acceptHandler: () -> Void = { [weak self] in
      self?.executeUpdates()
    }

    viewController.configureAlertView(
      title: alertTitle,
      description: alertDescription,
      acceptButtonTitle: "Continue",
      cancelButtonTitle: nil,
      acceptAction: acceptHandler,
      cancelAction: nil
    )
    viewController.modalPresentationStyle = .custom
    viewController.modalTransitionStyle = .crossDissolve
    present(viewController, animated: true)
  }

  private func showUpdateCompleteAlert() {
    let alertViewController = AlertViewController()
    alertViewController.configureAlertView(
      title: "Update complete!",
      description: "You’re now using the latest Jacquard technology.",
      acceptButtonTitle: "Got It",
      cancelButtonTitle: nil,
      acceptAction: nil,
      cancelAction: nil
    )

    alertViewController.modalPresentationStyle = .custom
    alertViewController.modalTransitionStyle = .crossDissolve
    present(alertViewController, animated: true)
  }

  private func showLowTagBatteryAlert() {
    let alertViewController = AlertViewController()
    alertViewController.configureAlertView(
      title: "Tag battery level is too low",
      description: "Charge your Tag until the LED is white, then you can continue.",
      acceptButtonTitle: "OK",
      cancelButtonTitle: nil,
      acceptAction: nil,
      cancelAction: nil
    )
    alertViewController.modalPresentationStyle = .custom
    alertViewController.modalTransitionStyle = .crossDissolve
    present(alertViewController, animated: true)
  }

  private func showSomethingWentWrongAlert(_ tag: ConnectedTag) {
    dismissAlert {

      let measurement = Measurement(value: Constants.tagDistanceFromPhone, unit: UnitLength.feet)
      let measurementFormatter = MeasurementFormatter()
      measurementFormatter.unitStyle = .long
      measurementFormatter.unitOptions = .naturalScale
      measurementFormatter.locale = .current
      let localizedDistance = measurementFormatter.string(from: measurement)

      var isTagOnlyUpdate = false
      let isModuleOnlyUpdate = self.dfuUpdates.allSatisfy { $0.mid != nil }
      if !isModuleOnlyUpdate {
        let tagComponent = tag.tagComponent
        isTagOnlyUpdate =
          self.dfuUpdates
          .filter { $0.mid == nil }
          .allSatisfy { tagComponent.vendor.id == $0.vid && tagComponent.product.id == $0.pid }
      }

      let alertViewController = AlertViewController()
      let alertTitle = "Something went wrong"
      var alertDescription =
        "Make sure your Tag is attached to your product and within \(localizedDistance) of your bluetooth-enabled phone."
      if isModuleOnlyUpdate || isTagOnlyUpdate {
        alertDescription =
          "Make sure your Tag is within \(localizedDistance) of your bluetooth-enabled phone."
      }
      alertViewController.configureAlertView(
        title: alertTitle,
        description: alertDescription,
        acceptButtonTitle: "OK",
        cancelButtonTitle: nil,
        acceptAction: nil,
        cancelAction: nil
      )
      alertViewController.modalPresentationStyle = .custom
      alertViewController.modalTransitionStyle = .crossDissolve
      self.present(alertViewController, animated: true)
    }
  }

  private func showBottomProgressView() {
    guard bottomProgressController == nil else {
      return
    }
    enableUIControl(false)

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
      bottomProgressView.topAnchor.constraint(
        equalTo: checkFirmwareButton.bottomAnchor, constant: 17.0),
    ])

    checkFirmwareButtonBottomConstraint.isActive = false
    checkFirmwareButtonBottomConstraint.priority = .defaultLow

    view.layoutIfNeeded()
  }

  private func hideBottomProgressView() {
    enableUIControl(true)
    bottomProgressController?.view.removeFromSuperview()
    bottomProgressController?.removeFromParent()
    bottomProgressController = nil

    checkFirmwareButtonBottomConstraint.isActive = true
    checkFirmwareButtonBottomConstraint.priority = .required

    view.layoutIfNeeded()
  }
}

// MARK: Internal helper methods

extension FirmwareUpdatesViewController {

  private func dismissAlert(_ completion: @escaping () -> Void) {
    if let progressViewController = firmwareUpdateProgressViewController {
      progressViewController.dismiss(animated: true) {
        self.firmwareUpdateProgressViewController = nil
        completion()
      }
    } else if let viewController = alertViewController {
      viewController.dismiss(animated: true) {
        self.alertViewController = nil
        completion()
      }
    } else {
      completion()
    }
  }

  private func subscribeForTagConnection() {
    connectionStream?
      .map { state -> ConnectedTag? in
        if case .connected(let tag) = state {
          return tag
        }
        return nil
      }
      .removeDuplicates { previousState, currentState in
        // Coalesce duplicate sequence of nil values.
        if previousState == nil && currentState == nil {
          return true
        }
        return false
      }
      .sink { [weak self] optionalTag in
        guard let self = self else { return }
        self.connectedTag = optionalTag
        self.updateTagVersion()
        self.subscribeForFirmwareStates()
        self.subscribeGearConnection()
      }.addTo(&observers)
  }

  private func subscribeGearConnection() {
    connectedTag?.connectedGear.sink { [weak self] gearComponent in
      guard let self = self else { return }

      self.updateProductVersion()
    }.addTo(&self.observers)
  }

  private func checkFirmwareUpdates(_ tag: ConnectedTag) {
    tag.firmwareUpdateManager.checkUpdates(forceCheck: forceUpdateCheckSwitch.isOn)
      .sink { [weak self] completion in
        guard let self = self else { return }

        if case .failure(let error) = completion {
          self.loadingView.stopLoading()
          MDCSnackbarManager.default.show(MDCSnackbarMessage(text: error.localizedDescription))
        }
      } receiveValue: { [weak self] updates in
        guard let self = self else { return }
        self.dfuUpdates = updates
        if self.loadableModuleUpdateSwitch.isOn {
          self.checkFirmwareUpdateForModules(tag)
        } else {
          self.handleApplyUpdates(self.dfuUpdates, tag: tag)
        }
      }.addTo(&observers)
  }

  private func checkFirmwareUpdateForModules(_ tag: ConnectedTag) {
    tag.firmwareUpdateManager.checkModuleUpdates(forceCheck: forceUpdateCheckSwitch.isOn)
      .prefix(1)
      .sink { [weak self] completion in
        guard let self = self else { return }
        // Continue applying updates for tag and interposer component, if any.
        // Ignore check module updates failure, if any.

        if case .failure(let error) = completion {
          print("Received error in checking module updates: \(error)")
        }
        self.handleApplyUpdates(self.dfuUpdates, tag: tag)
      } receiveValue: { [weak self] in
        guard let self = self else { return }

        let dfuUpdates = $0.compactMap { result -> DFUUpdateInfo? in
          if case .success(let info) = result {
            return info
          }
          return nil
        }

        self.dfuUpdates.append(contentsOf: dfuUpdates)
      }.addTo(&observers)
  }

  private func handleApplyUpdates(_ updates: [DFUUpdateInfo], tag: ConnectedTag) {
    self.loadingView.stopLoading {
      if self.dfuUpdates.isEmpty {
        self.showNoUpdateAvailableAlert()
      } else {
        self.showFirmwareUpdateAvailableAlert(self.dfuUpdates, tag: tag)
      }
    }
  }

  private func applyFirmwareUpdate(_ updates: [DFUUpdateInfo]) {
    guard let tag = connectedTag else {
      MDCSnackbarManager.default.show(
        MDCSnackbarMessage(text: Constants.tagDisconnectedSnackbarMessage)
      )
      return
    }

    /// There is one more api to update loadable modules specifically. Whenever there is loadable
    /// module updates, SDK deactivates activated module to prevent corruption of tag. App needs to
    /// activate that module again to make that module work.
    ///
    /// see also: `applyModuleUpdates(updates)`
    let _ =
      tag.firmwareUpdateManager.applyUpdates(updates, shouldAutoExecute: autoUpdateSwitch.isOn)
  }

  private func executeUpdates() {
    guard let tag = connectedTag else {
      MDCSnackbarManager.default.show(
        MDCSnackbarMessage(text: Constants.tagDisconnectedSnackbarMessage)
      )
      return
    }
    tag.firmwareUpdateManager.executeUpdates()
  }

  private func subscribeForFirmwareStates() {
    if let tag = connectedTag {
      tag.firmwareUpdateManager.state
        .sink { [weak self] state in
          guard let self = self else { return }

          switch state {
          case .idle: break
          case .preparingForTransfer:
            self.showUpdateProgressAlert(tag)
            self.firmwareUpdateProgressViewController?.progress = 0.0
          case .transferring(let progress):
            if !self.isForegroundUpdateInProgress {
              self.showBottomProgressView()
            }
            if let bottomProgressController = self.bottomProgressController {
              bottomProgressController.progress = progress
            } else {
              self.firmwareUpdateProgressViewController?.progress = progress
            }
          case .transferred:
            if let bottomProgressController = self.bottomProgressController {
              bottomProgressController.progress = 100.0
              self.hideBottomProgressView()
              if !self.autoUpdateSwitch.isOn {
                self.showAlmostReadyAlert()
              }
            } else if let firmwareUpdateProgressController =
              self.firmwareUpdateProgressViewController
            {
              firmwareUpdateProgressController.progress = 100.0
              firmwareUpdateProgressController.dismiss(animated: true) {
                self.firmwareUpdateProgressViewController = nil
                if !self.autoUpdateSwitch.isOn {
                  self.showAlmostReadyAlert()
                }
              }
            } else {
              if !self.autoUpdateSwitch.isOn {
                self.showAlmostReadyAlert()
              }
            }
          case .executing:
            self.hideBottomProgressView()
            self.dismissAlert {
              self.loadingView.modalPresentationStyle = .overCurrentContext
              self.present(self.loadingView, animated: true) {
                self.loadingView.startLoading(withMessage: "Finishing")
              }
            }
          case .completed:
            // If there is only module updates, state will be marked completed after transferring.
            // Hence, cleaning UI.
            if let bottomProgressController = self.bottomProgressController {
              bottomProgressController.progress = 100.0
              self.hideBottomProgressView()
            } else if let progressController = self.firmwareUpdateProgressViewController {
              progressController.progress = 100.0
              progressController.dismiss(animated: true) {
                self.firmwareUpdateProgressViewController = nil
              }
            }
            self.loadingView.stopLoading {
              self.showUpdateCompleteAlert()
            }
          case .error(.lowBattery):
            self.hideBottomProgressView()
            self.showLowTagBatteryAlert()
          case .error(_):
            self.hideBottomProgressView()
            self.loadingView.stopLoading {
              self.showSomethingWentWrongAlert(tag)
            }
          case .stopped:
            self.hideBottomProgressView()
          }
        }.addTo(&observers)
    }
  }
}
