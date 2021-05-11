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

import CoreData
import CoreLocation
import JacquardSDK
import MaterialComponents
import UIKit

extension Place {
  @objc
  var groupByDay: String {
    guard let timestamp = timestamp else { return "" }

    let formatter = DateFormatter()
    formatter.timeStyle = .none
    formatter.dateStyle = .long
    formatter.doesRelativeDateFormatting = true

    return formatter.string(from: timestamp)
  }
}

class PlacesViewModel {

  static let shared = PlacesViewModel()

  private enum Constants {
    static let placesGestureKey = "PlacesAssignedGestureInference"
  }
  // Hold the Core locationManager.
  private let locationManager = CLLocationManager()
  // Hold coreData Helper
  private let coreDataManager = CoreDataStackManager()
  // Returns the gesture assigned to places feature.
  var assignedGesture: Gesture {
    let gestureInference = UserDefaults.standard.integer(forKey: Constants.placesGestureKey)
    return Gesture(rawValue: gestureInference) ?? .noInference
  }

  // Assign gesture to places feature.
  func assignGesture(_ gesture: Gesture) {
    UserDefaults.standard.setValue(gesture.rawValue, forKey: Constants.placesGestureKey)
  }

  // Save the location in a persistent store.
  func addLocation(_ location: CLLocation) {
    DispatchQueue.main.async {
      self.storeLocationInternal(location)
    }
  }

  // Retrieve placemark and add location.
  private func storeLocationInternal(_ location: CLLocation) {

    CLGeocoder().reverseGeocodeLocation(
      location,
      completionHandler: { (placemarks, error) in
        // The geocoder executes this handler regardless of whether the request was successful
        // or unsuccessful, So it safe to create entity here.
        guard let newPlace = self.coreDataManager.create(entity: "Place") as? Place else {
          assertionFailure("Could not create a place entity")
          return
        }
        newPlace.latitude = location.coordinate.latitude
        newPlace.longitude = location.coordinate.longitude
        newPlace.timestamp = Date()

        if let placemark = placemarks?.first {
          newPlace.placemark = placemark
        }

        self.coreDataManager.save()
        self.coreDataManager.context.refresh(newPlace, mergeChanges: true)
      })
  }

  // Returns place with given id if available.
  func place(with placeID: NSManagedObjectID) -> Place? {
    if let place = try? coreDataManager.context.existingObject(with: placeID) as? Place {
      return place
    }
    return nil
  }

  // Returns all places with a specific date.
  func placesForDate(_ date: Date) -> [Place]? {

    var calendar = Calendar.current
    calendar.timeZone = NSTimeZone.local
    let dateFrom = calendar.startOfDay(for: date)
    guard let dateTo = calendar.date(byAdding: .day, value: 1, to: dateFrom) else {
      return nil
    }

    let fromPredicate = NSPredicate(
      format: "%K >= %@", argumentArray: [#keyPath(Place.timestamp), dateFrom])
    let toPredicate = NSPredicate(
      format: "%K < %@", argumentArray: [#keyPath(Place.timestamp), dateTo])
    let datePredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
      fromPredicate, toPredicate,
    ])

    let fetchRequest: NSFetchRequest<Place> = Place.fetchRequest()
    fetchRequest.predicate = datePredicate

    let dateSort = NSSortDescriptor(key: #keyPath(Place.timestamp), ascending: false)
    fetchRequest.sortDescriptors = [dateSort]

    if let places = try? coreDataManager.context.fetch(fetchRequest) {
      return places
    }

    return nil
  }

  // Deletes the place from persistent store.
  func deletePlace(_ place: Place) {
    coreDataManager.context.delete(place)
    coreDataManager.save()
  }

  // Deletes all places from persistent store.
  func deleteAllPlaces() {
    let request: NSFetchRequest<NSFetchRequestResult> = Place.fetchRequest()
    let deleteRequest = NSBatchDeleteRequest(fetchRequest: request)
    do {
      try coreDataManager.context.execute(deleteRequest)
    } catch {
      assertionFailure("Unable to delete all places: \(error)")
    }
    // Batch delete won't update contexts, so need to refresh the FRC.
    coreDataManager.context.refreshAllObjects()
  }

  // Returns a fetchResultContoller containing places sorted by date.
  func fetchResultContoller() -> NSFetchedResultsController<Place> {

    let fetchRequest: NSFetchRequest<Place> = Place.fetchRequest()
    fetchRequest.sortDescriptors = [
      NSSortDescriptor(key: "timestamp", ascending: false)
    ]

    let fetchedResultsController = NSFetchedResultsController(
      fetchRequest: fetchRequest, managedObjectContext: coreDataManager.context,
      sectionNameKeyPath: #keyPath(Place.groupByDay), cacheName: nil
    )

    return fetchedResultsController
  }

  func isLocationPermissionEnabled() -> Bool {
    if CLLocationManager.locationServicesEnabled() {
      switch CLLocationManager.authorizationStatus() {
      case .notDetermined, .restricted, .denied:
        return false
      case .authorizedAlways, .authorizedWhenInUse:
        return true
      @unknown default: return false
      }
    }
    return false
  }
}
