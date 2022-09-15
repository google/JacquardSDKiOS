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

import Combine
import JacquardSDK
import SwiftUI
import UIKit

struct GestureCellModel: Hashable {
  var title: String
  var subTitle: String
  var icon: UIImage
}

final class GestureListViewController: UIViewController {

  @IBOutlet private weak var tableView: UITableView!

  @IBAction func closeButtonTapped(_ sender: Any) {
    dismiss(animated: true)
  }

  // Use to manage data and provide cells for a table view.
  private var diffableDataSource: UITableViewDiffableDataSource<Int, GestureCellModel>?

  private let gestureModels: [GestureCellModel] = [
    GestureCellModel(
      title: "Brush In/Up",
      subTitle: "Brush inwards or upwards",
      icon: Gesture.brushIn.image),
    GestureCellModel(
      title: "Brush Out/Down",
      subTitle: "Brush outwards or downwards",
      icon: Gesture.brushOut.image),
    GestureCellModel(
      title: "Double Tap",
      subTitle: "Tap twice on the touch area",
      icon: Gesture.doubleTap.image),
    GestureCellModel(
      title: "Cover",
      subTitle: "Cover the touch area",
      icon: Gesture.shortCover.image),
  ]

  override func viewDidLoad() {
    super.viewDidLoad()
    configureTableDataSource()
  }
}

/// Configure tableView data source
extension GestureListViewController {

  private func configureTableDataSource() {

    // Configure table view.
    let nib = UINib(nibName: String(describing: GestureTableViewCell.self), bundle: nil)
    tableView.register(nib, forCellReuseIdentifier: GestureTableViewCell.reuseIdentifier)

    diffableDataSource =
      UITableViewDiffableDataSource<Int, GestureCellModel>(tableView: tableView) {
        (tableView, indexPath, gestureModel) -> UITableViewCell? in
        guard
          let cell = tableView.dequeueReusableCell(
            withIdentifier: GestureTableViewCell.reuseIdentifier,
            for: indexPath
          ) as? GestureTableViewCell
        else {
          return UITableViewCell()
        }
        cell.configureCell(data: gestureModel)
        return cell
      }

    tableView.dataSource = diffableDataSource

    var snapshot = NSDiffableDataSourceSnapshot<Int, GestureCellModel>()
    snapshot.appendSections([0])
    snapshot.appendItems(gestureModels, toSection: 0)
    diffableDataSource?.apply(snapshot)
  }
}

struct GestureListRepresentable: UIViewControllerRepresentable {

  func makeUIViewController(context: Context) -> GestureListViewController {
    return GestureListViewController()
  }

  func updateUIViewController(_ uiViewController: GestureListViewController, context: Context) {}
}
