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

import JacquardSDK
import UIKit

class IMUSessionDetailTableViewCell: UITableViewCell {

  @IBOutlet private weak var title: UILabel!

  static let reuseIdentifier = "IMUSessionDetailTableViewCell"

  func configureCell(model: IMUSample) {
    let accelation = model.acceleration
    let gyro = model.gyro
    let accString = "Accx: \(accelation.x), AccY: \(accelation.y), AccZ: \(accelation.x), "
    let gyroString = "GyroRoll: \(gyro.x), GyroPitch: \(gyro.y), GyroYaw: \(gyro.x)"
    title.text = accString + gyroString
  }
}
