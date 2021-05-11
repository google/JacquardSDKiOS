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

class ConnectedTagTableViewCell: UITableViewCell {

  enum Constants {
    static let circularCheckImageName = "circularCheck"
    static let circularUncheckImageName = "circularUncheck"
    static let tagNamePrefixText = "Jacquard Tag "
    static let fontSize: CGFloat = 16.0
  }

  static let reuseIdentifier = "connectedTagCellIdentifier"

  @IBOutlet private weak var title: UILabel!
  @IBOutlet private weak var checkboxImageView: UIImageView!

  override func setSelected(_ selected: Bool, animated: Bool) {
    super.setSelected(selected, animated: animated)
    if selected {
      contentView.backgroundColor = .black
      title.textColor = .white
      checkboxImageView.image = UIImage(named: Constants.circularCheckImageName)
    } else {
      contentView.backgroundColor = .white
      title.textColor = .black
      checkboxImageView.image = UIImage(named: Constants.circularUncheckImageName)
    }
  }

  func configure(with model: TagManagerViewController.TagCellModel) {

    let attributedString = NSMutableAttributedString(string: Constants.tagNamePrefixText)
    let attributes =
      [NSAttributedString.Key.font: UIFont.boldSystemFont(ofSize: Constants.fontSize)]
    let tagName = NSMutableAttributedString(string: model.tag.displayName, attributes: attributes)
    attributedString.append(tagName)
    title.attributedText = attributedString

    layer.masksToBounds = true
    layer.cornerRadius = 5
    layer.borderWidth = 1
    layer.shadowOffset = CGSize(width: -1, height: 1)
    layer.borderColor = UIColor.black.withAlphaComponent(0.3).cgColor

    let rippleTouchController = MDCRippleTouchController()
    rippleTouchController.addRipple(to: self)
  }
}
