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

class LocationPublisher: NSObject, CLLocationManagerDelegate {
  private let locationManager = CLLocationManager()
  private let locationSubject = PassthroughSubject<Result<CLLocation, Error>, Never>()
  private let authSubject = PassthroughSubject<CLAuthorizationStatus, Never>()

  var publisher: AnyPublisher<Result<CLLocation, Error>, Never> {
    locationSubject.eraseToAnyPublisher()
  }

  var authPublisher: AnyPublisher<CLAuthorizationStatus, Never> {
    authSubject.eraseToAnyPublisher()
  }

  override init() {
    super.init()
    locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    locationManager.delegate = self
  }

  func requestAuthorization() {
    locationManager.requestWhenInUseAuthorization()
  }

  func requestLocation() {
    locationManager.requestLocation()
  }

  func locationManager(
    _ manager: CLLocationManager,
    didUpdateLocations locations: [CLLocation]
  ) {
    if let location = locations.first {
      locationSubject.send(.success(location))
    }
  }

  func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    // Errors can happen more than once, so we don't complete the publisher.
    locationSubject.send(.failure(error))
  }

  func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    if #available(iOS 14.0, *) {
      authSubject.send(locationManager.authorizationStatus)
    } else {
      // Fallback on earlier versions
      authSubject.send(CLLocationManager.authorizationStatus())
    }
  }
}
