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
import UIKit

private typealias GesturesDataSource =
  UITableViewDiffableDataSource<GesturesViewController.Section, GestureModel>
private typealias GesturesSnapshot =
  NSDiffableDataSourceSnapshot<GesturesViewController.Section, GestureModel>

private class GestureCell: UITableViewCell {
  static let reuseIdentifier = "GesuterCell"
  func configure(_ gestureName: String) {
    textLabel?.text = gestureName
  }
}

private struct GestureModel: Hashable {
  let name: String
  let uuid = UUID()
}

final class GesturesViewController: UIViewController {

  fileprivate enum Section {
    case feed
  }

  private enum Constants {
    static let cellHeight: CGFloat = 30.0
    static let gesturesNibName = "GesturesViewController"
    static let infoButtonImage = UIImage(named: "info.png")
  }

  // MARK: Instance vars
  private var observers = [Cancellable]()
  private var dataSource = [GestureModel]()
  private var diffableDataSource: UITableViewDiffableDataSource<Section, GestureModel>!
  /// Convenience stream that only contains the tag.
  private var tagPublisher: AnyPublisher<ConnectedTag, Never>

  @IBOutlet weak var tableView: UITableView!

  // MARK: View life cycle

  init(tagPublisher: AnyPublisher<ConnectedTag, Never>) {
    self.tagPublisher = tagPublisher
    super.init(nibName: Constants.gesturesNibName, bundle: nil)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    tableView.register(GestureCell.self, forCellReuseIdentifier: GestureCell.reuseIdentifier)
    tagPublisher.sink { tag in
      tag.registerSubscriptions(self.createGestureSubsctiption)
    }.addTo(&observers)
    let infoButton = UIBarButtonItem(
      image: Constants.infoButtonImage, style: .plain, target: self,
      action: #selector(self.infoButtonTapped))
    navigationItem.rightBarButtonItem = infoButton
    navigationItem.rightBarButtonItem?.tintColor = .black
    configureDataSource()
  }

  @objc private func infoButtonTapped() {
    let gestureVC = GestureListViewController()
    gestureVC.modalPresentationStyle = .fullScreen
    present(gestureVC, animated: true)
  }

  // Gestures subscription could be use to get most recently executed gesture.
  private func createGestureSubsctiption(_ tag: SubscribableTag) {
    tag.subscribe(GestureNotificationSubscription())
      .sink { [weak self] notification in
        guard let self = self else { return }
        self.dataSource.insert(GestureModel(name: "\(notification.name)"), at: 0)
        self.createSnapshot(from: self.dataSource)
        self.view.showBlurView(image: notification.image, gestureName: notification.name)
      }.addTo(&observers)
  }
}

/// Handle  diffableDataSource , gesturesSnapshot, tableviewDelegate  methods.
extension GesturesViewController: UITableViewDelegate {

  private func configureDataSource() {
    diffableDataSource = GesturesDataSource(tableView: tableView) {
      (tableView, indexPath, gesture) -> UITableViewCell in
      guard
        let cell = tableView.dequeueReusableCell(
          withIdentifier: GestureCell.reuseIdentifier, for: indexPath
        ) as? GestureCell
      else {
        return UITableViewCell()
      }
      cell.textLabel?.text = "\(gesture.name) logged"
      return cell
    }
  }

  private func createSnapshot(from gesture: [GestureModel]) {
    var snapshot = GesturesSnapshot()
    snapshot.appendSections([.feed])
    snapshot.appendItems(gesture)
    diffableDataSource.apply(snapshot, animatingDifferences: false)
  }

  func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
    return Constants.cellHeight
  }
}
