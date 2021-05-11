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
import CoreLocation
import JacquardSDK
import UIKit

extension Gesture {
  fileprivate static var placesAlternatives: [Gesture] = [
    .brushIn,
    .brushOut,
    .doubleTap,
  ]
}

class PlacesGestureSelectionViewController: UIViewController {

  @IBOutlet private weak var tableView: UITableView! {
    didSet {
      tableView.tableFooterView = UIView(frame: .zero)
      tableView.dataSource = self
      tableView.delegate = self
    }
  }
  @IBOutlet private weak var assignButton: GreyRoundCornerButton!
  let locationPublisher = LocationPublisher()
  private var alertViewController: AlertViewController?
  private var observers = [Cancellable]()

  @Published private var isGestureSelected = false
  private var subscribers: [AnyCancellable] = []

  private enum Contants {
    static let gestureCellID = "GestureCell"
  }

  private let tagPublisher: AnyPublisher<ConnectedTag, Never>

  private var currentGesture = PlacesViewModel.shared.assignedGesture
  private var hideAssignFAB: Bool

  init(tagPublisher: AnyPublisher<ConnectedTag, Never>, hideAssignFAB: Bool = false) {
    self.tagPublisher = tagPublisher
    self.hideAssignFAB = hideAssignFAB
    super.init(nibName: "PlacesGestureSelectionViewController", bundle: nil)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    tableView.register(UITableViewCell.self, forCellReuseIdentifier: Contants.gestureCellID)
    assignButton.isHidden = hideAssignFAB
    $isGestureSelected
      .receive(on: DispatchQueue.main)
      .assign(to: \.isEnabled, on: assignButton)
      .store(in: &subscribers)
    if currentGesture == .noInference {
      isGestureSelected = false
    } else {
      isGestureSelected = true
      assignButton.isEnabled = true
    }
    NotificationCenter.Publisher(
      center: .default,
      name: UIApplication.willEnterForegroundNotification
    )
    .sink { [weak self] _ in
      self?.locationPublisher.requestAuthorization()
    }.addTo(&observers)
  }

  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    PlacesViewModel.shared.assignGesture(currentGesture)
  }

  @IBAction func assignButtonPressed(_ sender: UIButton) {
    checkLocationPermission()
  }

  private func checkLocationPermission() {
    if CLLocationManager.locationServicesEnabled() {
      switch CLLocationManager.authorizationStatus() {
      case .restricted, .denied:
        showPermissionAlert()
      case .authorizedAlways, .authorizedWhenInUse:
        PlacesViewModel.shared.assignGesture(currentGesture)
        switchScreens()
      case .notDetermined:
        locationPublisher.requestAuthorization()
      @unknown default: showPermissionAlert()
      }
    } else {
      showPermissionAlert()
    }

    locationPublisher.authPublisher.sink { [weak self] authStatus in
      if authStatus == .authorizedAlways || authStatus == .authorizedWhenInUse {
        PlacesViewModel.shared.assignGesture(self!.currentGesture)
        self?.switchScreens()
      } else {
        self?.locationPublisher.requestAuthorization()
      }
    }.addTo(&observers)
  }

  private func showPermissionAlert() {
    alertViewController = AlertViewController()
    guard let alertViewController = alertViewController else {
      assertionFailure("alertViewController is not instantiated.")
      return
    }
    let acceptHandler: () -> Void = {
      UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
    }
    alertViewController.configureAlertView(
      title: "Change access settings",
      description: "Jacquard requires location access in order to use places.",
      acceptButtonTitle: "Change settings",
      cancelButtonTitle: "Cancel",
      acceptAction: acceptHandler,
      cancelAction: nil
    )
    alertViewController.modalPresentationStyle = .custom
    alertViewController.modalTransitionStyle = .crossDissolve
    present(alertViewController, animated: true)
  }

  private func switchScreens() {
    observers.forEach { $0.cancel() }
    guard var viewControllers = navigationController?.viewControllers else { return }
    // Popped ViewController not used.
    _ = viewControllers.popLast()
    let replacingVC = PlacesListViewController(tagPublisher: tagPublisher)
    // Push targetViewController.
    viewControllers.append(replacingVC)
    navigationController?.setViewControllers(viewControllers, animated: true)
  }

}

extension PlacesGestureSelectionViewController: UITableViewDataSource, UITableViewDelegate {

  // MARK: TableView Datasource.
  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    JacquardSDK.Gesture.placesAlternatives.count
  }

  func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
    return UITableView.automaticDimension
  }

  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell = tableView.dequeueReusableCell(withIdentifier: Contants.gestureCellID, for: indexPath)

    let gesture = JacquardSDK.Gesture.placesAlternatives[indexPath.row]
    cell.textLabel?.text = gesture.name
    cell.accessoryType = gesture == currentGesture ? .checkmark : .none
    return cell
  }

  // MARK: TableView Delegate.
  func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    currentGesture = Gesture.placesAlternatives[indexPath.row]
    tableView.reloadData()
    isGestureSelected = true
  }
}
