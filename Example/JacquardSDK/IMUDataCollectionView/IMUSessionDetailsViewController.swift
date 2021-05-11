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
import UIKit

final class IMUSessionDetailsViewController: UIViewController {

  struct IMUSampleCellModel: Hashable {
    let sample: IMUSample

    static func == (lhs: IMUSampleCellModel, rhs: IMUSampleCellModel) -> Bool {
      return lhs.sample.timestamp == rhs.sample.timestamp
    }

    func hash(into hasher: inout Hasher) {
      sample.timestamp.hash(into: &hasher)
    }
  }

  // Session to show the samples.
  var selectedSession: IMUSessionData!

  @IBOutlet private weak var sessionName: UILabel!
  @IBOutlet private weak var samplesTableView: UITableView!

  private var samplesDiffableDataSource: UITableViewDiffableDataSource<Int, IMUSampleCellModel>?

  private lazy var dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.timeStyle = DateFormatter.Style.medium
    formatter.dateStyle = DateFormatter.Style.medium
    formatter.timeZone = .current
    return formatter
  }()

  override func viewDidLoad() {
    super.viewDidLoad()

    if let timestamp = TimeInterval(selectedSession.metadata.sessionID) {
      let date = Date(timeIntervalSinceReferenceDate: timestamp)
      sessionName.text = dateFormatter.string(from: date)
    } else {
      sessionName.text = selectedSession.metadata.sessionID
    }
    configureSessionTableView()
    updateDataSource()
  }

  private func configureSessionTableView() {
    let nib = UINib(nibName: IMUSessionDetailTableViewCell.reuseIdentifier, bundle: nil)
    samplesTableView.register(
      nib, forCellReuseIdentifier: IMUSessionDetailTableViewCell.reuseIdentifier)

    samplesTableView.dataSource = samplesDiffableDataSource
    samplesTableView.delegate = self
    samplesTableView.rowHeight = 64.0
    samplesDiffableDataSource = UITableViewDiffableDataSource<Int, IMUSampleCellModel>(
      tableView: samplesTableView,
      cellProvider: { (tableView, indexPath, sampleModel) -> UITableViewCell? in
        let cell = tableView.dequeueReusableCell(
          withIdentifier: IMUSessionDetailTableViewCell.reuseIdentifier,
          for: indexPath
        )
        guard
          let sampleCell = cell as? IMUSessionDetailTableViewCell
        else {
          assertionFailure("Cell can not be casted to IMUSessionTableViewCell.")
          return cell
        }
        sampleCell.configureCell(model: sampleModel.sample)
        return sampleCell
      })
  }

  func updateDataSource() {
    let samples = selectedSession.samples.map { IMUSampleCellModel(sample: $0) }
    var snapshot = NSDiffableDataSourceSnapshot<Int, IMUSampleCellModel>()
    snapshot.appendSections([0])
    snapshot.appendItems(samples, toSection: 0)
    self.samplesDiffableDataSource?.apply(snapshot)
  }
}

extension IMUSessionDetailsViewController: UITableViewDelegate {

  func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
    let headerView = JacquardSectionHeader(
      frame: CGRect(x: 0.0, y: 0.0, width: samplesTableView.frame.width, height: 40.0))
    headerView.title = "DATA: (\(selectedSession.samples.count) samples)"
    return headerView
  }

  func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
    return 40.0
  }
}
