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

final class BottomProgressController: UIViewController {

  @IBOutlet private weak var progressView: UIProgressView!
  @IBOutlet private weak var percentLabel: UILabel!

  var progress: Float = 0.0 {
    didSet {
      DispatchQueue.main.async {
        self.progressView.setProgress(self.progress / 100, animated: false)
        self.percentLabel.text = "\(Int(self.progress))%"
      }
    }
  }

  init() {
    super.init(nibName: "BottomProgressController", bundle: nil)

    view.translatesAutoresizingMaskIntoConstraints = false
    view.layer.shadowColor = UIColor.bottomProgressViewShadow.cgColor
    view.layer.shadowOffset = CGSize(width: 5.0, height: 0.0)
    view.layer.shadowOpacity = 1
    view.layer.shadowRadius = 7
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}
