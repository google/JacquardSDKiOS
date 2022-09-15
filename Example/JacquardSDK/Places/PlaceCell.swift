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

import MapKit
import UIKit

class PlaceCell: UITableViewCell, MKMapViewDelegate {

  @IBOutlet private weak var mapView: MKMapView!
  @IBOutlet private weak var placemarkName: UILabel!
  @IBOutlet private weak var placemarkAddress: UILabel!
  @IBOutlet private weak var timeStamp: UILabel!
  @IBOutlet private weak var deleteButton: UIButton!

  lazy var dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "HH:mm a"
    formatter.amSymbol = "AM"
    formatter.pmSymbol = "PM"
    return formatter
  }()

  // For deletion of this row's place.
  var deletePlaceButtonAction: (() -> (Void))?

  override func awakeFromNib() {
    super.awakeFromNib()
    self.deleteButton.addTarget(
      self, action: #selector(deleteButtonSelected(_:)), for: .touchUpInside)
  }

  @IBAction func deleteButtonSelected(_ sender: UIButton) {
    deletePlaceButtonAction?()
  }

  func update(with place: Place, deleteAction: @escaping () -> Void) {
    let location = CLLocation(latitude: place.latitude, longitude: place.longitude)
    if let placemark = place.placemark {
      placemarkName.text = placemark.name
      placemarkAddress.text = placemark.completeAddress
    } else {
      // Show lat,long if placemark could not be retrieved.
      placemarkName.text = String(format: "%.5f,%.5f", place.latitude, place.longitude)
      placemarkAddress.text = "Address not available"
    }
    // Safe to unwrap timestamp as Place will always be saved along with timestamp.
    timeStamp.text = dateFormatter.string(from: place.timestamp!)
    renderMapCell(location: location)
    deletePlaceButtonAction = deleteAction
  }

  // Draws one coordinate and has one annotation.
  private func renderMapCell(location: CLLocation) {
    let coordinate = CLLocationCoordinate2D(
      latitude: location.coordinate.latitude,
      longitude: location.coordinate.longitude)

    let span = MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
    let region = MKCoordinateRegion(center: coordinate, span: span)
    mapView.isZoomEnabled = false
    mapView.isScrollEnabled = false
    mapView.isUserInteractionEnabled = false
    mapView.setRegion(region, animated: true)

    // Add an annotation.
    let pin = MKPointAnnotation()
    pin.coordinate = coordinate
    let annotations = mapView.annotations
    mapView.removeAnnotations(annotations)
    mapView.addAnnotation(pin)
  }
}
