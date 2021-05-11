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
import MaterialComponents
import UIKit

class TagManagerViewController: UIViewController {

  struct TagCellModel: Hashable {
    var tag: JacquardTag

    static func == (lhs: TagCellModel, rhs: TagCellModel) -> Bool {
      return lhs.tag.identifier == rhs.tag.identifier
    }

    func hash(into hasher: inout Hasher) {
      tag.identifier.hash(into: &hasher)
    }
  }

  private var observations = [Cancellable]()

  @IBOutlet private weak var tagsTableView: UITableView!

  // Publishes a value every time the tag connects or disconnects.
  private var tagPublisher: AnyPublisher<ConnectedTag, Never>?

  /// Use to manage data and provide cells for a table view.
  private var tagsDiffableDataSource: UITableViewDiffableDataSource<Int, TagCellModel>?

  /// Datasource model.
  private var connectedTagModels = [TagCellModel]()

  init(tagPublisher: AnyPublisher<ConnectedTag, Never>?) {
    self.tagPublisher = tagPublisher
    super.init(nibName: "TagManagerViewController", bundle: nil)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func viewDidLoad() {
    super.viewDidLoad()

    let addBarButtonItem = UIBarButtonItem(
      barButtonSystemItem: .add,
      target: self,
      action: #selector(addNewTag)
    )
    navigationItem.rightBarButtonItem = addBarButtonItem

    // Configure table view.
    let nib = UINib(nibName: String(describing: ConnectedTagTableViewCell.self), bundle: nil)
    tagsTableView.register(
      nib,
      forCellReuseIdentifier: ConnectedTagTableViewCell.reuseIdentifier
    )

    tagsDiffableDataSource = UITableViewDiffableDataSource<Int, TagCellModel>(
      tableView: tagsTableView,
      cellProvider: { (tagsTableView, indexPath, connectedTagCellModel) -> UITableViewCell? in
        guard
          let cell = tagsTableView.dequeueReusableCell(
            withIdentifier: ConnectedTagTableViewCell.reuseIdentifier,
            for: indexPath
          ) as? ConnectedTagTableViewCell
        else {
          return UITableViewCell()
        }
        cell.configure(with: connectedTagCellModel)
        return cell
      })

    tagsTableView.dataSource = tagsDiffableDataSource
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    configureTableDataSource()
  }

  override func viewDidDisappear(_ animated: Bool) {
    super.viewDidDisappear(animated)
    observations.removeAll()
  }
}

// Extension contains only UI logic not related to Jacquard SDK API's
extension TagManagerViewController {

  func configureTableDataSource() {
    // We need to track the currently connected tag so that the details screen can show more
    // info and disconnect if desired. The prepend(nil) is because we want the table to populate
    // even when there are no connected tags (would be better if tagPublisher propagated nil values)

    tagPublisher?
      .map { tag -> ConnectedTag? in tag }
      .prepend(nil)
      .sink(receiveValue: { [weak self] connectedTag in
        guard let self = self else { return }
        self.configureTableDataSource(currentConnectedTag: connectedTag)
      }).addTo(&observations)
  }

  private func configureTableDataSource(currentConnectedTag: ConnectedTag?) {

    //TODO: Perhaps should put connected cell into its own section with a header, that would
    // be more clear.

    tagsTableView.isHidden = Preferences.knownTags.isEmpty
    connectedTagModels =
      Preferences.knownTags
      .map {
        // Swap in the currently connected tag so that the details screen can show more
        // info and disconnect if desired.
        if let currentConnectedTag = currentConnectedTag,
          $0.identifier == currentConnectedTag.identifier
        {
          return TagCellModel(tag: currentConnectedTag)
        } else {
          return TagCellModel(tag: $0)
        }
      }
    var snapshot = NSDiffableDataSourceSnapshot<Int, TagCellModel>()
    snapshot.appendSections([0])
    snapshot.appendItems(connectedTagModels, toSection: 0)
    tagsDiffableDataSource?.apply(snapshot, animatingDifferences: false)

    if Preferences.knownTags.count > 0 {
      let indexPath = IndexPath(row: 0, section: 0)
      tagsTableView.selectRow(at: indexPath, animated: true, scrollPosition: .top)
    }
  }

  /// Initiate scanning on add new tag.
  @objc func addNewTag() {
    let appDelegate = UIApplication.shared.delegate as? AppDelegate
    appDelegate?.window?.rootViewController =
      UINavigationController(rootViewController: ScanningViewController())
  }
}

/// Handle Tableview delegate methods.
extension TagManagerViewController: UITableViewDelegate {

  func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    guard let model = tagsDiffableDataSource?.itemIdentifier(for: indexPath) else {
      return
    }

    let tagDetailsVC = TagDetailsViewController(tagPublisher: tagPublisher, tag: model.tag)
    navigationController?.pushViewController(tagDetailsVC, animated: true)
  }
}
