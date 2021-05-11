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

final class GestureBlurEffectView: UIView {

  private var blurEffectView: UIVisualEffectView?

  override init(frame: CGRect) {
    let blurEffect = UIBlurEffect(style: .extraLight)
    let blurEffectView = UIVisualEffectView(effect: blurEffect)
    blurEffectView.alpha = 0.8
    blurEffectView.frame = frame
    blurEffectView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    self.blurEffectView = blurEffectView
    super.init(frame: frame)
    addSubview(blurEffectView)
  }

  required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  public func configureUI(image: UIImage, gestureName: String) {
    guard let blurEffectView = blurEffectView else { return }

    let imageView = UIImageView()
    imageView.image = image
    imageView.frame = CGRect(x: 0, y: 0, width: 120, height: 120)
    imageView.center = blurEffectView.contentView.center
    blurEffectView.contentView.addSubview(imageView)

    let gestureLabel = UILabel()
    gestureLabel.text = gestureName
    gestureLabel.frame = CGRect(
      x: 0, y: blurEffectView.frame.size.height / 2 + 70,
      width: blurEffectView.frame.size.width,
      height: 40)
    gestureLabel.textAlignment = .center
    blurEffectView.contentView.addSubview(gestureLabel)
    gestureLabel.layer.zPosition = 1
    self.bringSubviewToFront(gestureLabel)
  }
}

extension UIView {

  func showBlurView(image: UIImage, gestureName: String) {
    removeBlurView()
    let blurView = GestureBlurEffectView(frame: frame)
    blurView.configureUI(image: image, gestureName: gestureName)
    self.addSubview(blurView)
    DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(1)) {
      self.removeBlurView()
    }
  }

  private func removeBlurView() {
    if let blurView = subviews.first(where: { $0 is GestureBlurEffectView }) {
      blurView.removeFromSuperview()
    }
  }
}
