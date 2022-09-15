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

enum IMUSessionAction {
  case view
  case delete
  case download
  case share
}

protocol IMUSessionActionDelegate: AnyObject {
  func didSelectSession(_ cell: IMUSessionTableViewCell, for action: IMUSessionAction)
}

class IMUSessionTableViewCell: UITableViewCell {

  @IBOutlet private weak var title: UILabel!
  @IBOutlet private weak var sessionActionsView: UIView!
  @IBOutlet private weak var viewSessionButton: UIButton!
  @IBOutlet private weak var deleteSessionButton: UIButton!
  @IBOutlet private weak var downloadUploadButton: UIButton!

  static let reuseIdentifier = "IMUSessionTableViewCell"
  weak var actionDelegate: IMUSessionActionDelegate?

  private let downloadButtonTag = 1000
  private let uploadButtonTag = 2000
  // Used for past recording timestamp.
  private lazy var dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.timeStyle = DateFormatter.Style.medium
    formatter.dateStyle = DateFormatter.Style.medium
    formatter.timeZone = .current
    return formatter
  }()
  // Used for current recording timer.
  private lazy var timeFormatter: DateComponentsFormatter = {
    let formatter = DateComponentsFormatter()
    formatter.allowedUnits = [.hour, .minute, .second]
    formatter.unitsStyle = .positional
    formatter.zeroFormattingBehavior = .pad
    return formatter
  }()

  func configureCell(model: IMUSessionCellModel) {

    if let timestamp = TimeInterval(model.session.name) {
      let date = Date(timeIntervalSinceReferenceDate: timestamp)
      title.text = dateFormatter.string(from: date)
    } else {
      title.text = model.session.name
    }

    sessionActionsView.isHidden = (model.session.metadata == nil && model.session.fileURL == nil)
    deleteSessionButton.isHidden = false
    downloadUploadButton.isHidden = false
    viewSessionButton.isHidden = model.session.fileURL == nil
    if model.session.fileURL != nil {
      downloadUploadButton.setImage(UIImage(named: "ic_share_session"), for: .normal)
      downloadUploadButton.tag = uploadButtonTag
    } else {
      downloadUploadButton.setImage(UIImage(named: "ic_download_session"), for: .normal)
      downloadUploadButton.tag = downloadButtonTag
    }
  }

  func updateSessionTime(_ time: String) {
    guard let timestamp = TimeInterval(time) else {
      title.text = time
      return
    }
    let start = Date(timeIntervalSinceReferenceDate: timestamp)
    let elapsed = Date().timeIntervalSince(start)

    let timer = timeFormatter.string(from: elapsed)!

    title.text = "Recording  " + timer
  }

  @IBAction func viewSessionButtonTapped(_ sender: Any) {
    actionDelegate?.didSelectSession(self, for: .view)
  }

  @IBAction func deleteSessionButtonTapped(_ sender: Any) {
    actionDelegate?.didSelectSession(self, for: .delete)
  }

  @IBAction func downloadUploadSessionButtonTapped(_ sender: UIButton) {
    if sender.tag == downloadButtonTag {
      actionDelegate?.didSelectSession(self, for: .download)
    } else {
      actionDelegate?.didSelectSession(self, for: .share)
    }
  }

}
