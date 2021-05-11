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
import ProgressHUD
import UIKit

class RenameTagViewController: UIViewController {

  // MARK: - IBOutlets

  @IBOutlet weak var tagNameLabel: UILabel!
  @IBOutlet weak var renameButton: UIButton!
  @IBOutlet weak var rebootWarningLabel: UILabel!

  // MARK: - Private variables

  private var observers = [Cancellable]()
  private let tagPublisher: AnyPublisher<ConnectedTag, Never>

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

      self.rebootWarningLabel.isHidden = true
      self.renameButton.isEnabled = true
    }.addTo(&observers)
  }

  // MARK: - IBActions

  @IBAction func rename(_ sender: Any) {

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
      ProgressHUD.show()
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
          MDCSnackbarManager.default.show(MDCSnackbarMessage(text: "\(error)"))
          ProgressHUD.dismiss()
        } receiveValue: { (_) in
          ProgressHUD.dismiss()

          // Show warning as tag is rebooting.
          self.rebootWarningLabel.isHidden = false

          self.renameButton.isEnabled = false
        }.addTo(&self.observers)
    }
    alert.addAction(renameAction)
    alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
    present(alert, animated: true)
  }
}
