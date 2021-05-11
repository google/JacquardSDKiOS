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

import CoreLocation

extension CLPlacemark {
  var completeAddress: String {
    return [subThoroughfare, thoroughfare, locality, administrativeArea, postalCode, country]
      .compactMap { $0 }
      .joined(separator: " ")
  }
}

@objc(JQPlacemarkTransformer)
final class PlacemarkTransformer: NSSecureUnarchiveFromDataTransformer {
  static let name = NSValueTransformerName(String(describing: self))

  override class var allowedTopLevelClasses: [AnyClass] {
    [CLPlacemark.self]
  }
  public static func register() {
    ValueTransformer.setValueTransformer(self.init(), forName: name)
  }
}
