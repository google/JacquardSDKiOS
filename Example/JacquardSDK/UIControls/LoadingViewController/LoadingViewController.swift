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

/// An Overlayed ViewController that covers the entire window, used as an ActivityIndicator.
final class LoadingViewController: UIViewController {

  private enum Constants {
    static let animationDuration = 0.5
    static let pairingAnimationDuration = 3.0
  }

  @IBOutlet private weak var indicator: MDCActivityIndicator!
  @IBOutlet private weak var indicatorImage: UIImageView!
  @IBOutlet private weak var indicatorLabel: UILabel!
  @IBOutlet private weak var transparentView: UIView!

  static let instance = LoadingViewController(nibName: "LoadingViewController", bundle: nil)

  func indicatorProgress(_ progress: Float) {
    if let indicator = indicator {
      indicator.progress = progress
    }
  }

  func startLoading(withMessage text: String) {
    if let indicator = indicator {
      indicator.startAnimating()
      indicatorImage.isHidden = true
      indicatorLabel.text = text
      UIView.animate(withDuration: Constants.animationDuration) { self.transparentView.alpha = 1.0 }
    }
  }

  func stopLoading(withMessage text: String, completion: (() -> Void)? = nil) {
    if let indicator = indicator {
      indicator.stopAnimating()
      indicatorImage.isHidden = false
      indicatorLabel.text = text
      DispatchQueue.main.asyncAfter(
        deadline: DispatchTime.now() + Constants.pairingAnimationDuration
      ) {
        self.indicatorImage.isHidden = true
        self.dismiss(animated: false, completion: completion)
      }
    }
  }

  func stopLoading(
    message: String = "",
    timeout: TimeInterval = 0.0,
    animated: Bool = true,
    completion: (() -> Void)? = nil
  ) {
    indicator.stopAnimating()
    indicatorImage.isHidden = true
    indicatorLabel.text = message
    DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + timeout) {
      self.dismiss(animated: animated, completion: completion)
    }
  }
}
