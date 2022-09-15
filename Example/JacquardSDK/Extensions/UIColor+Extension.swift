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

import UIKit

extension UIColor {
  static let border = UIColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.3)
  static let disable = UIColor(red: 0.965, green: 0.965, blue: 0.965, alpha: 1.0)
  static let enabledText = UIColor(white: 0.0, alpha: 0.8)
  static let disabledText = UIColor(white: 0.0, alpha: 0.5)
  static let gearConnected = UIColor(red: 0.2, green: 0.659, blue: 0.322, alpha: 1.0)
  static let gearDisconnected = UIColor(red: 0.918, green: 0.263, blue: 0.208, alpha: 1.0)
  static let goodSignalRSSI = UIColor(red: 0.117, green: 0.557, blue: 0.243, alpha: 1.0)
  static let fairSignalRSSI = UIColor(red: 0.95, green: 0.6, blue: 0.0, alpha: 1.0)
  static let weakSignalRSSI = UIColor(red: 0.850, green: 0.188, blue: 0.145, alpha: 1.0)
  static let tableViewSectionBackground = UIColor(red: 0.98, green: 0.98, blue: 0.98, alpha: 1.0)
  static let tableViewSectionTitle = UIColor(red: 0.39, green: 0.39, blue: 0.39, alpha: 1.0)
  static let alertDescription = UIColor(red: 0.25, green: 0.25, blue: 0.25, alpha: 1.0)
  static let bottomProgressViewShadow = UIColor(red: 0.235, green: 0.251, blue: 0.263, alpha: 0.15)
  static let grayBorder = UIColor(red: 0.7, green: 0.7, blue: 0.7, alpha: 1)
  static let defaultDFUStatus = UIColor(red: 0.078, green: 0.42, blue: 0.18, alpha: 1.0)
  static let errorStatus = UIColor(red: 0.70, green: 0.15, blue: 0.12, alpha: 1.0)
}

extension UIColor {
  // Provides signal color depending upon the range value.
  static func signalColor(_ signalValue: Float) -> UIColor {
    if signalValue >= -65.0 {
      return .goodSignalRSSI
    } else if signalValue <= -66.0 && signalValue >= -80.0 {
      return .fairSignalRSSI
    } else {
      return .weakSignalRSSI
    }
  }
}
