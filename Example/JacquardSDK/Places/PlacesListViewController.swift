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
import CoreData
import CoreLocation
import JacquardSDK
import MapKit
import MaterialComponents
import UIKit

class PlacesListViewController: UIViewController {
  @IBOutlet private weak var locationCountLabel: UILabel!
  @IBOutlet private weak var tableView: UITableView! {
    didSet {
      tableView.rowHeight = 288
    }
  }

  private enum Contants {
    static let placeCellID = "PlacesTableViewCell"
  }
  private let tagPublisher: AnyPublisher<ConnectedTag, Never>
  private var locationPublisher = LocationPublisher()

  private var observers = [Cancellable]()

  private let placesModel = PlacesViewModel.shared

  private var diffableDataSource: PlacesDataSource?
  private var fetchedResultsController: NSFetchedResultsController<Place>?
  private var locationTimer: Timer?

  init(tagPublisher: AnyPublisher<ConnectedTag, Never>) {
    self.tagPublisher = tagPublisher
    super.init(nibName: "PlacesListViewController", bundle: nil)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func viewDidLoad() {
    super.viewDidLoad()

    // Create DiffableDataSource for the CoreData models.
    diffableDataSource = PlacesDataSource.makeDataSource(tableView: tableView, viewController: self)
    tableView.dataSource = diffableDataSource
    tableView.delegate = self

    let overflowButton = UIBarButtonItem(
      image: UIImage(named: "ic_overflow_menu"), style: .plain, target: self,
      action: #selector(showOverflowActions))
    navigationItem.rightBarButtonItem = overflowButton

    tableView.register(
      UINib(nibName: "PlaceCell", bundle: nil),
      forCellReuseIdentifier: Contants.placeCellID)

    // Configure Place fetchResults
    fetchedResultsController = placesModel.fetchResultContoller()
    fetchedResultsController?.delegate = self
  }

  override func viewWillAppear(_ animated: Bool) {
    do {
      try fetchedResultsController?.performFetch()
    } catch {
      fatalError("Failed to fetch entities: \(error)")
    }

    tagPublisher.sink { [weak self] tag in
      guard let self = self else { return }
      // The `createGestureSubscription` method below requests gesture notifications.
      tag.registerSubscriptions(self.createGestureSubscription)
    }.addTo(&observers)

    NotificationCenter.Publisher(
      center: .default,
      name: UIApplication.willEnterForegroundNotification
    )
    .sink { [weak self] _ in
      if !PlacesViewModel.shared.isLocationPermissionEnabled() {
        self?.showLocationAccessError()
      }
      self?.locationPublisher.requestAuthorization()
    }.addTo(&observers)
  }

  private func showLocationAccessError() {
    MDCSnackbarManager.default.show(
      MDCSnackbarMessage(text: "Places requires location access")
    )
  }

  override func viewWillDisappear(_ animated: Bool) {
    observers.forEach { $0.cancel() }
  }

  @objc func showOverflowActions() {
    let actionSheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)

    let assignGesture = UIAlertAction(title: "Change assigned gesture", style: .default) { _ in
      let nextVC = PlacesGestureSelectionViewController(
        tagPublisher: self.tagPublisher, hideAssignFAB: true)
      self.navigationController?.pushViewController(nextVC, animated: true)
    }

    let deleteAllAction = UIAlertAction(title: "Delete all places", style: .destructive) { _ in

      let actionSheet = UIAlertController(
        title: "Delete all locations", message: "Do you want to delete all locations?",
        preferredStyle: .actionSheet)

      let deleteAction = UIAlertAction(title: "Delete", style: .destructive) { _ in
        DispatchQueue.main.async {
          self.placesModel.deleteAllPlaces()
          try? self.fetchedResultsController?.performFetch()
        }
      }

      let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
      actionSheet.addAction(deleteAction)
      actionSheet.addAction(cancelAction)

      self.present(actionSheet, animated: true)
    }

    let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)

    actionSheet.addAction(assignGesture)
    actionSheet.addAction(deleteAllAction)
    actionSheet.addAction(cancelAction)

    present(actionSheet, animated: true)
  }

  // Observe gestures from the tag.
  private func createGestureSubscription(_ tag: SubscribableTag) {
    tag.subscribe(GestureNotificationSubscription())
      .sink { [weak self] gesture in
        guard let self = self else { return }
        // Check if gesture is same as assigned to places, can ignore other gestures.
        if self.placesModel.assignedGesture == gesture {
          self.processGesture()
        }
      }.addTo(&observers)
  }

  private func processGesture() {
    locationTimer?.invalidate()
    locationTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: false) { _ in
      let message =
        "Dropped pin will be delayed. Make sure you’re connected to Wi-Fi or mobile network."
      MDCSnackbarManager.default.show(
        MDCSnackbarMessage(text: message)
      )
    }

    locationPublisher.publisher
      .first()
      .sink { [weak self] result in
        self?.locationTimer?.invalidate()
        switch result {
        case .failure:
          self?.showLocationAccessError()
        case .success(let location):
          self?.placesModel.addLocation(location)
        }
      }.addTo(&observers)

    locationPublisher.requestLocation()
  }

}

extension PlacesListViewController: UITableViewDelegate {
  func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    tableView.deselectRow(at: indexPath, animated: true)
    guard let dataSource = diffableDataSource,
      let placeID = dataSource.itemIdentifier(for: indexPath),
      let place = placesModel.place(with: placeID)
    else {
      return
    }
    let viewControllerWithPlacesForaDate = PlacesMapViewController(selectedPlace: place)
    navigationController?.pushViewController(viewControllerWithPlacesForaDate, animated: true)
  }
}

extension PlacesListViewController: NSFetchedResultsControllerDelegate {

  func controller(
    _ controller: NSFetchedResultsController<NSFetchRequestResult>,
    didChangeContentWith snapshot: NSDiffableDataSourceSnapshotReference
  ) {

    guard let dataSource = diffableDataSource else {
      return
    }

    dataSource.apply(
      snapshot as NSDiffableDataSourceSnapshot<String, NSManagedObjectID>,
      animatingDifferences: false)

    // Update count label.
    let placesCount = snapshot.itemIdentifiers.count
    if placesCount == 0 {
      let gestureName = placesModel.assignedGesture.name.lowercased()
      locationCountLabel.text = "Use the \(gestureName) gesture to drop pins"
    } else if placesCount == 1 {
      locationCountLabel.text = "\(placesCount) Location"
    } else {
      locationCountLabel.text = "\(placesCount) Locations"
    }
  }
}

class PlacesDataSource: UITableViewDiffableDataSource<String, NSManagedObjectID> {
  override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String?
  {
    guard let place = self.itemIdentifier(for: IndexPath(item: 0, section: section)) else {
      return nil
    }
    return self.snapshot().sectionIdentifier(containingItem: place)

  }

  static func makeDataSource(tableView: UITableView, viewController: PlacesListViewController)
    -> PlacesDataSource
  {

    PlacesDataSource(tableView: tableView) { tableView, indexPath, placeID in

      let cell =
        tableView.dequeueReusableCell(withIdentifier: "PlacesTableViewCell", for: indexPath)
        as! PlaceCell

      guard let place = PlacesViewModel.shared.place(with: placeID) else {
        return cell
      }

      cell.update(with: place) {
        let actionSheet = UIAlertController(
          title: "Delete place", message: nil,
          preferredStyle: .actionSheet)

        let deleteAction = UIAlertAction(title: "Delete", style: .destructive) { _ in
          PlacesViewModel.shared.deletePlace(place)
        }

        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
        actionSheet.addAction(deleteAction)
        actionSheet.addAction(cancelAction)

        viewController.present(actionSheet, animated: true)
      }

      return cell
    }
  }
}
