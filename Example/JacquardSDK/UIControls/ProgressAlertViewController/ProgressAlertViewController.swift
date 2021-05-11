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

import UIKit

final class ProgressAlertViewController: UIViewController {

  typealias ActionHandler = () -> Void

  // MARK: - IBOutlets

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
  @IBOutlet private weak var percentLabel: UILabel!
  @IBOutlet private weak var progressLabel: UILabel! {
    didSet {
      progressLabel.text = alertProgressTitle
    }
  }
  @IBOutlet private weak var progressView: UIProgressView!
  @IBOutlet private weak var actionButton: UIButton! {
    didSet {
      actionButton.isHidden = actionHandler == nil
      if let title = alertActionButtonTitle {
        actionButton.setTitle(title, for: .normal)
      }
    }
  }

  var actionHandler: ActionHandler?

  // MARK: - Variables
  private var alertTitle: NSAttributedString?
  private var alertDescription: NSAttributedString?
  private var alertProgressTitle = ""
  private var alertActionButtonTitle: String?

  var progress: Float = 0.0 {
    didSet {
      DispatchQueue.main.async {
        self.progressView.setProgress(self.progress / 100, animated: false)
        self.percentLabel.text = "\(Int(self.progress))%"
      }
    }
  }

  init() {
    super.init(nibName: "ProgressAlertViewController", bundle: nil)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  // MARK: - IBActions

  @IBAction func actionButtonTapped(_ sender: Any) {
    if let _ = presentingViewController {
      dismiss(animated: true) { self.actionHandler?() }
    } else {
      actionHandler?()
    }
  }
}

// MARK: External methods

extension ProgressAlertViewController {

  func configureView(
    title: String,
    description: String,
    progressTitle: String,
    actionTitle: String? = nil,
    actionHandler: ActionHandler? = nil
  ) {
    alertTitle = NSAttributedString(string: title)
    alertDescription = NSAttributedString(string: description)
    alertProgressTitle = progressTitle
    alertActionButtonTitle = actionTitle
    self.actionHandler = actionHandler
  }
}
