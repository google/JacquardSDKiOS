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

final class DashboardCell: UICollectionViewCell {

  private enum Constants {
    static let borderWidth: CGFloat = 1.0
    static let cornerRadius: CGFloat = 4.0
  }

  @IBOutlet private weak var containerView: UIView!
  @IBOutlet private weak var itemNameLabel: UILabel!
  @IBOutlet private weak var itemDescriptionLabel: UILabel!

  override func awakeFromNib() {
    super.awakeFromNib()
    // Initialization code

    containerView.layer.cornerRadius = Constants.cornerRadius
    containerView.layer.borderWidth = Constants.borderWidth
    containerView.layer.borderColor = UIColor.border.cgColor
  }

  func configure(_ item: DashboardItem) {
    if item.enabled {
      containerView.backgroundColor = .white
      itemNameLabel.textColor = .enabledText
      itemDescriptionLabel.textColor = .enabledText
      isUserInteractionEnabled = true
    } else {
      containerView.backgroundColor = .disable
      itemNameLabel.textColor = .disabledText
      itemDescriptionLabel.textColor = .disabledText
      isUserInteractionEnabled = false
    }
    itemNameLabel.text = item.name
    itemDescriptionLabel.text = item.description
  }
}
