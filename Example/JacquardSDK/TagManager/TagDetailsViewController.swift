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

class TagDetailsViewController: UIViewController {

  private enum Constants {
    // Battery status
    static let batteryChargingStatus = "Charging"
    static let batteryNotChargingStatus = "Not Charging"

    // Tag status
    static let currentTag = "Current Tag"
    static let tagDisconnectedStatus = "Tag Disconnected"

    // Tag attached status
    static let tagAttachedStatus = "Yes"
    static let tagNotAttachedStatus = "No"

    // Sanckbar message
    static let tagDisconnectedSanckbarMessage = "Disconnected"
    static let forgetTag = " Removed"
    static let tagIsNotCurrentTag =
      "All details can't be shown as the tag is not set as the current tag."

    // Notification name
    static let setCurrentTag = "setCurrentTag"
  }

  @IBOutlet private weak var serialNumberLabel: UILabel!
  @IBOutlet private weak var versionLabel: UILabel!
  @IBOutlet private weak var batteryLabel: UILabel!
  @IBOutlet private weak var attachStatusLabel: UILabel!
  @IBOutlet private weak var selectTagButton: UIButton!

  /// Selected tag from previous tag list screen.
  private var selectedTag: JacquardTag

  // Publishes a value every time the tag connects or disconnects.
  private var tagPublisher: AnyPublisher<ConnectedTag, Never>?

  /// Retains references to the Cancellable instances created by publisher subscriptions.
  private var observers = [Cancellable]()

  init(tagPublisher: AnyPublisher<ConnectedTag, Never>?, tag: JacquardTag) {
    self.selectedTag = tag
    self.tagPublisher = tagPublisher
    super.init(nibName: "TagDetailsViewController", bundle: nil)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func viewDidLoad() {
    super.viewDidLoad()

    // Update screen title.
    title = "Tag \(selectedTag.displayName)"

    updateUI(nil)
    // Subscribe to already connected tag.
    if selectedTag.identifier == Preferences.knownTags.first?.identifier {
      updateTagStatus()
      tagPublisher?.sink { [weak self] tag in
        guard let self = self else { return }
        // if selected tag is already connected then subscribe events.
        if self.selectedTag.identifier == tag.identifier {
          tag.registerSubscriptions(self.createSubscriptions)
          self.subscribeGearConnection(tag)
        } else {
          // if selected tag is not connected then connect it.
          self.connectToTag()
        }
      }.addTo(&observers)
    } else {
      MDCSnackbarManager.default.show(MDCSnackbarMessage(text: Constants.tagIsNotCurrentTag))
    }
    if let tag = selectedTag as? ConnectedTag {
      versionLabel.text = tag.tagComponent.version?.description ?? "--"
    }
  }

  /// Disconnect command call to disconnect the connected tag.
  private func disconnectTag() {

    guard let tag = selectedTag as? ConnectedTag else {
      // If it's not current Tag then remove it from Preferences.
      removeTagFromKnownTags()
      return
    }

    // It returns a connectionState Publisher.
    // Subscribe to this publisher to track the state changes of the connection.
    let connectionStream = sharedJacquardManager.disconnect(tag)
    connectionStream
      .sink { error in
        MDCSnackbarManager.default.show(MDCSnackbarMessage(text: "\(error)"))
      } receiveValue: { [weak self] connectionState in
        guard let self = self else { return }
        switch connectionState {
        case .disconnected:
          // Tag is successfully disconnected.
          self.removeTagFromKnownTags()
        default:
          break
        }
      }.addTo(&observers)
  }

  /// Removes tag from list of known tags.
  private func removeTagFromKnownTags() {
    Preferences.knownTags.removeAll(where: { $0.identifier == selectedTag.identifier })
    if !Preferences.knownTags.isEmpty {
      navigationController?.popViewController(animated: true)
      NotificationCenter.default.post(name: Notification.Name(Constants.setCurrentTag), object: nil)
    } else {
      let appDelegate = UIApplication.shared.delegate as? AppDelegate
      appDelegate?.window?.rootViewController =
        UINavigationController(rootViewController: ScanningViewController())
    }
    MDCSnackbarManager.default.show(
      MDCSnackbarMessage(text: "\(selectedTag.displayName) \(Constants.forgetTag)"))
  }

  /// Subscribe to gear connection events.
  private func subscribeGearConnection(_ tag: ConnectedTag) {
    tag.connectedGear
      .sink { [weak self] gear in
        guard let self = self else { return }
        self.updateUI(gear)
      }.addTo(&observers)
  }

  /// Subscribe to tag battery notifications.
  private func createSubscriptions(_ tag: SubscribableTag) {
    // Battery notification subscription is needed to get charging state and battery percentages.
    let subscription = BatteryStatusNotificationSubscription()
    tag.subscribe(subscription)
      .sink { [weak self] response in
        guard let self = self else { return }
        self.updateBatteryStatus(response)
      }.addTo(&observers)
  }

  /// Connect command call to connect selected tag.
  private func connectToTag() {
    // It returns a connectionState Publisher.
    // Subscribe to this publisher, to track the state changes of the connection.
    let connectionStream = sharedJacquardManager.connect(selectedTag.identifier)
    connectionStream
      .sink { error in
        // Connection attempts never time out,
        // so an error will be received only when the connection cannot be recovered or retried.
        MDCSnackbarManager.default.show(MDCSnackbarMessage(text: "\(error)"))
      } receiveValue: { [weak self] connectionState in
        guard let self = self else { return }
        switch connectionState {
        case .connecting(_, _), .initializing(_, _), .configuring(_, _), .preparingToConnect:
          break
        case .connected(let connectedTag):
          // Tag is successfully paired, you can now subscribe and retrieve the tag stream.
          print("connected to tag: \(connectedTag)")
          self.performOperationsOnTagConnect(tag: connectedTag)
        case .disconnected(let error):
          print("Disconnected with error: \(String(describing: error))")
          self.updateUIForTagDisconnect()
        default:
          print("Ignoring \(connectionState) changes")
        }
      }.addTo(&observers)
  }

  /// Perform operations after successfully setting a current tag.
  private func performOperationsOnTagConnect(tag: ConnectedTag) {
    // Subscibe gear connection and battery status events.
    subscribeGearConnection(tag)
    tag.registerSubscriptions(createSubscriptions)
    // Update tag status to `Current tag`.
    updateTagStatus()
    // Update tag firmware version.
    versionLabel.text = tag.tagComponent.version?.description ?? "--"
  }

  @IBAction func setCurrentTag(_ sender: Any) {
    // Set connected tag as first tag.
    guard
      let index = Preferences.knownTags.firstIndex(
        where: { $0.identifier == selectedTag.identifier })
    else {
      return
    }
    let tag = Preferences.knownTags[index]
    Preferences.knownTags.remove(at: index)
    Preferences.knownTags.insert(tag, at: 0)
    navigationController?.popToRootViewController(animated: true)
    NotificationCenter.default.post(name: Notification.Name(Constants.setCurrentTag), object: nil)
  }

  @IBAction func forgetTag(_ sender: Any) {
    disconnectTag()
  }
}

// Extension contains only UI logic.
extension TagDetailsViewController {

  /// Update UI for battery status.
  private func updateBatteryStatus(_ response: BatteryStatus) {
    let chargingStatus =
      response.chargingState == .charging
      ? Constants.batteryChargingStatus
      : Constants.batteryNotChargingStatus
    batteryLabel.text = "\(response.batteryLevel)%, \(chargingStatus)"
  }

  /// Update UI for serial number and gear attach status.
  private func updateUI(_ gear: Component?) {
    serialNumberLabel.text = selectedTag.identifier.uuidString
    if let gear = gear {
      let product = gear.product
      attachStatusLabel.text = "\(Constants.tagAttachedStatus), \(product.name)"
    } else {
      attachStatusLabel.text = Constants.tagNotAttachedStatus
    }
  }

  /// Update tag status to current tag.
  private func updateTagStatus() {
    selectTagButton.setTitle(Constants.currentTag, for: .normal)
    selectTagButton.setTitleColor(.black, for: .normal)
    selectTagButton.isEnabled = false
  }

  /// Update UI on tag disconnect.
  private func updateUIForTagDisconnect() {
    selectTagButton.setTitle(Constants.tagDisconnectedStatus, for: .normal)
    selectTagButton.setTitleColor(.gray, for: .normal)
    selectTagButton.isEnabled = false
    MDCSnackbarManager.default.show(
      MDCSnackbarMessage(text: Constants.tagDisconnectedSanckbarMessage))
  }
}
