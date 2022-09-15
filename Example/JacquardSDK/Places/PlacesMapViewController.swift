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
import UIKit

class PlacesMapViewController: UIViewController, MKMapViewDelegate {
  private var placesForTheDay: [Place] = []
  private var selectedPlace: Place

  lazy var dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "HH:mm a"
    formatter.amSymbol = "AM"
    formatter.pmSymbol = "PM"
    return formatter
  }()

  @IBOutlet weak var mapView: MKMapView!

  // MARK: - Initializers
  init(selectedPlace: Place) {
    self.selectedPlace = selectedPlace
    super.init(nibName: "PlacesMapViewController", bundle: nil)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    fetchAllLocationsForDay()
    mapView.delegate = self
    self.navigationItem.title = "Places for the day."
    self.loadMapViewForAllPlaces()
  }

  private func fetchAllLocationsForDay() {
    if let date = selectedPlace.timestamp {
      placesForTheDay = PlacesViewModel.shared.placesForDate(date) ?? []
    }
  }

  private func addAnnotationforPlace(_ place: Place) {
    guard let location = place.placemark?.location,
      let timestamp = place.timestamp
    else {
      return
    }
    let coordinate = CLLocationCoordinate2D(
      latitude: location.coordinate.latitude,
      longitude: location.coordinate.longitude)
    let pin = MKPointAnnotation()
    pin.title = (place.placemark?.name)! + " " + dateFormatter.string(from: timestamp)
    pin.coordinate = coordinate
    mapView.addAnnotation(pin)
  }

  func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
    let annotationView = MKMarkerAnnotationView(
      annotation: annotation, reuseIdentifier: "annotationIdentifier")
    if annotation.coordinate.latitude != selectedPlace.latitude
      || annotation.coordinate.longitude != selectedPlace.longitude
    {
      annotationView.markerTintColor = .blue
    } else {
      if #available(iOS 14.0, *) {
        annotationView.zPriority = .max
      }
    }
    annotationView.displayPriority = .required
    return annotationView
  }

  private func loadMapViewForAllPlaces() {
    for place in self.placesForTheDay {
      addAnnotationforPlace(place)
    }
    mapView.showAnnotations(mapView.annotations, animated: true)
    mapView.setVisibleMapRect(
      mapView.visibleMapRect,
      edgePadding: UIEdgeInsets(top: 100, left: 100, bottom: 100, right: 100),
      animated: true)
  }
}
