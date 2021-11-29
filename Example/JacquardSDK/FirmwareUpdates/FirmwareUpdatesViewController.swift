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
    subscribeForTagConnection()
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

    updateTagVersion()
    updateProductVersion()
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
    let isTagOnlyUpdate = updates.reduce(false) { _, info in
      self.isUpdateInfoForTag(tag, updateInfo: info)
    }
    var alertDescription = ""
    if isTagOnlyUpdate {
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
    let isTagOnlyUpdate = self.dfuUpdates.reduce(false) { _, info in
      self.isUpdateInfoForTag(tag, updateInfo: info)
    }
    self.isForegroundUpdateInProgress = true
    var alertDescription = ""
    if isTagOnlyUpdate {
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

      let isTagOnlyUpdate = self.dfuUpdates.reduce(false) { _, info in
        self.isUpdateInfoForTag(tag, updateInfo: info)
      }
      let alertViewController = AlertViewController()
      let alertTitle = "Something went wrong"
      var alertDescription =
        "Make sure your Tag is attached to your product and within \(localizedDistance) of your bluetooth-enabled phone."
      if isTagOnlyUpdate {
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
    bottomProgressController.view.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(bottomProgressController.view)
    bottomProgressController.didMove(toParent: self)

    bottomProgressController.view.layer.shadowColor =
      UIColor(red: 0.235, green: 0.251, blue: 0.263, alpha: 0.15).cgColor
    bottomProgressController.view.layer.shadowOffset = CGSize(width: 5.0, height: 0.0)
    bottomProgressController.view.layer.shadowOpacity = 1
    bottomProgressController.view.layer.shadowRadius = 7

    self.bottomProgressController = bottomProgressController

    let leadingConstraint = NSLayoutConstraint(
      item: bottomProgressController.view as Any,
      attribute: .leading,
      relatedBy: .equal,
      toItem: view,
      attribute: .leading,
      multiplier: 1.0,
      constant: 0.0
    )

    let trailingConstraint = NSLayoutConstraint(
      item: bottomProgressController.view as Any,
      attribute: .trailing,
      relatedBy: .equal,
      toItem: view,
      attribute: .trailing,
      multiplier: 1.0,
      constant: 0.0
    )

    let bottomConstraint = NSLayoutConstraint(
      item: bottomProgressController.view as Any,
      attribute: .bottom,
      relatedBy: .equal,
      toItem: view,
      attribute: .bottom,
      multiplier: 1.0,
      constant: 0.0
    )

    let heightConstraint = bottomProgressController.view.heightAnchor.constraint(
      equalToConstant: 71.0 + view.safeAreaInsets.bottom
    )

    view.addConstraints(
      [leadingConstraint, trailingConstraint, bottomConstraint, heightConstraint]
    )

    checkFirmwareButtonBottomConstraint.isActive = false
    checkFirmwareButtonBottomConstraint.priority = .defaultLow

    let layoutConstraint = NSLayoutConstraint(
      item: bottomProgressController.view as Any,
      attribute: .top,
      relatedBy: .equal,
      toItem: checkFirmwareButton,
      attribute: .bottom,
      multiplier: 1.0,
      constant: 17.0
    )
    layoutConstraint.isActive = true
    layoutConstraint.priority = .required

    view.addConstraint(layoutConstraint)

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

  private func isUpdateInfoForTag(_ tag: ConnectedTag, updateInfo: DFUUpdateInfo) -> Bool {
    if tag.tagComponent.vendor.id == updateInfo.vid && tag.tagComponent.product.id == updateInfo.pid
    {
      return true
    }
    return false
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
        self.loadingView.stopLoading {
          if updates.isEmpty {
            self.showNoUpdateAvailableAlert()
          } else {
            self.showFirmwareUpdateAvailableAlert(updates, tag: tag)
          }
        }
      }.addTo(&observers)
  }

  private func applyFirmwareUpdate(_ updates: [DFUUpdateInfo]) {
    guard let tag = connectedTag else {
      MDCSnackbarManager.default.show(
        MDCSnackbarMessage(text: Constants.tagDisconnectedSnackbarMessage)
      )
      return
    }

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
            } else {
              self.firmwareUpdateProgressViewController?.progress = 100.0
              self.firmwareUpdateProgressViewController?.dismiss(animated: true) {
                self.firmwareUpdateProgressViewController = nil
                if !self.autoUpdateSwitch.isOn {
                  self.showAlmostReadyAlert()
                }
              }
            }
          case .executing:
            self.dismissAlert {
              self.loadingView.modalPresentationStyle = .overCurrentContext
              self.present(self.loadingView, animated: true) {
                self.loadingView.startLoading(withMessage: "Finishing")
              }
            }
          case .completed:
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
          }
        }.addTo(&observers)
    }
  }
}
