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

import MaterialComponents
import UIKit

typealias AcceptActionHandler = () -> Void
typealias CancelActionHandler = () -> Void

final class AlertViewController: UIViewController {

  // MARK: IBOutlets

  @IBOutlet private weak var alertTitleLabel: UILabel! {
    didSet {
      alertTitleLabel.attributedText = alertTitle
    }
  }
  @IBOutlet private weak var alertDescriptionLabel: UILabel! {
    didSet {
      alertDescriptionLabel.attributedText = alertDescription
    }
  }
  @IBOutlet private weak var alertDoneButton: MDCButton! {
    didSet {
      alertDoneButton.setTitle(alertAcceptButtonTitle, for: .normal)
    }
  }
  @IBOutlet private weak var alertCancelButton: UIButton! {
    didSet {
      if let cancelButtonTitle = alertCancelButtonTitle, !cancelButtonTitle.isEmpty {
        alertCancelButton.setTitle(cancelButtonTitle, for: .normal)
      }
    }
  }

  // MARK: Variables

  private var acceptCompletion: AcceptActionHandler?
  private var cancelCompletion: CancelActionHandler?

  private var alertTitle: NSAttributedString?
  private var alertDescription: NSAttributedString?
  private var alertAcceptButtonTitle = ""
  private var alertCancelButtonTitle: String?

  init() {
    super.init(nibName: "AlertViewController", bundle: nil)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  // MARK: - View controller lifecycle methods

  override func viewDidLoad() {
    super.viewDidLoad()

    // Do any additional setup after loading the view.
    alertDoneButton.isUppercaseTitle = false
    alertDoneButton.layer.cornerRadius = 4.0
  }

  // MARK: IBActions

  @IBAction private func doneButtonTapped(_ sender: UIButton) {
    // Cehck if controller is presented or added as a subview.
    if let _ = presentingViewController {
      dismiss(animated: true) { self.acceptCompletion?() }
    } else {
      acceptCompletion?()
    }
  }

  @IBAction private func cancelButtonTapped(_ sender: UIButton) {
    // Cehck if controller is presented or added as a subview.
    if let _ = presentingViewController {
      dismiss(animated: true) { self.cancelCompletion?() }
    } else {
      cancelCompletion?()
    }
  }
}

// MARK: External methods

extension AlertViewController {

  func configureAlertView(
    title: String,
    description: String,
    acceptButtonTitle: String,
    cancelButtonTitle: String? = nil,
    acceptAction: AcceptActionHandler? = nil,
    cancelAction: CancelActionHandler? = nil
  ) {
    configureAlertView(
      attibutedTitle: NSAttributedString(string: title),
      attibutedDescription: NSAttributedString(string: description),
      acceptButtonTitle: acceptButtonTitle,
      cancelButtonTitle: cancelButtonTitle,
      acceptAction: acceptAction,
      cancelAction: cancelAction
    )
  }

  func configureAlertView(
    attibutedTitle: NSAttributedString,
    attibutedDescription: NSAttributedString,
    acceptButtonTitle: String,
    cancelButtonTitle: String? = nil,
    acceptAction: AcceptActionHandler? = nil,
    cancelAction: CancelActionHandler? = nil
  ) {
    alertTitle = attibutedTitle
    alertDescription = attibutedDescription
    alertAcceptButtonTitle = acceptButtonTitle
    alertCancelButtonTitle = cancelButtonTitle
    acceptCompletion = acceptAction
    cancelCompletion = cancelAction
  }
}
