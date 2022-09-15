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

import JacquardSDK
import MaterialComponents
import UIKit

class ScanningTableViewCell: UITableViewCell {

  static let reuseIdentifier = "tagCellIdentifier"

  @IBOutlet private weak var title: UILabel!
  @IBOutlet private weak var checkboxImageView: UIImageView!

  func configure(with model: AdvertisingTagCellModel, isSelected: Bool) {

    let tagPrefixText = NSMutableAttributedString(string: "Jacquard Tag ")
    let tagName = NSMutableAttributedString(
      string: model.tag.displayName,
      attributes: [NSAttributedString.Key.font: UIFont.system16Medium]
    )

    layer.masksToBounds = true
    layer.cornerRadius = 5
    layer.borderWidth = 1
    layer.shadowOffset = CGSize(width: -1, height: 1)
    layer.borderColor = UIColor.black.withAlphaComponent(0.3).cgColor

    if isSelected {
      contentView.backgroundColor = .black
      let attributes = [NSAttributedString.Key.foregroundColor: UIColor.white]
      tagPrefixText.addAttributes(attributes, range: NSMakeRange(0, tagPrefixText.string.count))
      tagName.addAttributes(attributes, range: NSMakeRange(0, tagName.string.count))
      checkboxImageView.image = UIImage(named: "circularCheck")
    } else {
      contentView.backgroundColor = .white
      let attributes = [NSAttributedString.Key.foregroundColor: UIColor.gray]
      tagPrefixText.addAttributes(attributes, range: NSMakeRange(0, tagPrefixText.string.count))
      tagName.addAttribute(
        NSAttributedString.Key.foregroundColor,
        value: UIColor.black,
        range: NSMakeRange(0, tagName.string.count)
      )
      checkboxImageView.image = UIImage(named: "circularUncheck")
    }

    tagPrefixText.append(tagName)
    if let advertisingTag = model.tag as? AdvertisedTag {
      let attributes = [
        NSAttributedString.Key.font: UIFont.system14Medium,
        NSAttributedString.Key.foregroundColor: UIColor.signalColor(advertisingTag.rssi),
      ]
      let rssi = NSMutableAttributedString(
        string: " (rssi: \(advertisingTag.rssi))",
        attributes: attributes
      )
      tagPrefixText.append(rssi)
    }
    title.attributedText = tagPrefixText

    let rippleTouchController = MDCRippleTouchController()
    rippleTouchController.addRipple(to: self)
  }
}
