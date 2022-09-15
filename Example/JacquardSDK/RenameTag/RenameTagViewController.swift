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

class RenameTagViewController: UIViewController {

  // MARK: - IBOutlets

  @IBOutlet weak var tagNameLabel: UILabel!
  @IBOutlet weak var renameButton: UIButton!

  // MARK: - Private variables

  private enum Constants {
    static let tagRebootingMessage =
      "The tag is rebooting to reflect the updated name. Please wait..."
  }

  private var observers = [Cancellable]()
  private let tagPublisher: AnyPublisher<ConnectedTag, Never>

  private let loadingView = LoadingViewController.instance
  private var isTagRebooting = false
  private var renameTagTimer: Timer?
  private var renamingTagDuration = 15.0

  // MARK: - Initializers

  init(tagPublisher: AnyPublisher<ConnectedTag, Never>) {
    self.tagPublisher = tagPublisher
    super.init(nibName: nil, bundle: nil)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  // MARK: - View controller life cycle methods

  override func viewDidLoad() {
    super.viewDidLoad()

    // Observe the tag (whenever connected or reconnected) to update UI.
    tagPublisher.flatMap {
      $0.namePublisher.combineLatest(Just($0.identifier))
    }.sink { nameAndIdentifier in
      self.tagNameLabel.text = nameAndIdentifier.0
      // Keep the app preferences up to date with the current name.
      Preferences.addKnownTag(KnownTag(identifier: nameAndIdentifier.1, name: nameAndIdentifier.0))

      self.renameButton.isEnabled = true
      if self.isTagRebooting {
        self.toggleTagRebootingState()
      }
    }.addTo(&observers)
  }

  // MARK: - IBActions

  @IBAction func renameButtonTapped(_ sender: Any) {

    let alert = UIAlertController(title: "Rename your tag", message: nil, preferredStyle: .alert)
    alert.addTextField()
    let renameAction = UIAlertAction(title: "Rename", style: .default) { _ in
      guard let newTagName = alert.textFields?.first?.text,
        !newTagName.isEmpty,
        !newTagName.trimmingCharacters(in: .whitespaces).isEmpty
      else {
        print("Error: New tag name not available.")
        return
      }

      self.tagPublisher
        .prefix(1)
        .mapNeverToError()
        .flatMap { tag -> AnyPublisher<Void, Error> in
          do {
            return try tag.setName(newTagName)
          } catch (let error) {
            return Fail<Void, Error>(error: error).eraseToAnyPublisher()
          }
        }.sink { (error) in
          self.toggleTagRebootingState()
        } receiveValue: { (_) in
          self.toggleTagRebootingState()
        }.addTo(&self.observers)
    }
    alert.addAction(renameAction)
    alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
    present(alert, animated: true)
  }

  private func toggleTagRebootingState() {
    if !isTagRebooting {
      loadingView.modalPresentationStyle = .overCurrentContext
      present(loadingView, animated: true) {
        self.loadingView.startLoading(withMessage: Constants.tagRebootingMessage)
      }
      isTagRebooting = true
      renameButton.isEnabled = false

      renameTagTimer = Timer.scheduledTimer(
        withTimeInterval: renamingTagDuration,
        repeats: false
      ) { [weak self] _ in
        guard let self = self else { return }
        self.invalidateRenameTagTimer()
        self.loadingView.stopLoading()
        MDCSnackbarManager.default.show(
          MDCSnackbarMessage(text: "Issue while renaming the tag.")
        )
      }
    } else {
      loadingView.stopLoading(withMessage: "")
      invalidateRenameTagTimer()
    }
  }

  private func invalidateRenameTagTimer() {
    renameTagTimer?.invalidate()
    renameTagTimer = nil
    isTagRebooting = false
    renameButton.isEnabled = true
  }
}
