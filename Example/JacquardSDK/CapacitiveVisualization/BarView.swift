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

/// Represents a bar in a bar chart to reflect the received capacitance data based on the user's
/// interaction with the threads on the garment.
final class BarView: UIView {

  private enum Constants {
    static let referenceBarColor = UIColor(
      red: 240.0 / 255.0, green: 237.0 / 255.0, blue: 2470.0 / 255.0, alpha: 1.0)
    static let capacitanceBarColor = UIColor(
      red: 66.0 / 255.0, green: 66.0 / 255.0, blue: 1.0, alpha: 1.0)
  }

  /// Represents the maximum bar height in a bar chart.
  private let maximumCapacitanceDataValue: CGFloat = 255
  /// Represents the top constraint for the bar indicating the capacitance value in a bar chart.
  private var barViewTopConstraint: NSLayoutConstraint!
  /// Represents the bar in a bar chart indicating the capacitance value.
  private var capacitanceBar: UIView?
  /// Represents the border radius for the bar view.
  private let borderRadius = 2.0
  /// Represents the capacitance bar height.
  private var capacitanceBarHeight: CGFloat = 0.0

  required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
    self.backgroundColor = Constants.referenceBarColor
    self.capacitanceBarHeight = frame.size.height
    addCapacitanceBar()
  }

  override init(frame: CGRect) {
    super.init(frame: frame)
    self.backgroundColor = Constants.referenceBarColor
    self.capacitanceBarHeight = frame.size.height
    addCapacitanceBar()
  }

  override func layoutSubviews() {
    super.layoutSubviews()

    // Update the corners of the bar view in a bar chart.
    let path = UIBezierPath(
      roundedRect: bounds, byRoundingCorners: [.topLeft, .topRight],
      cornerRadii: CGSize(width: borderRadius, height: borderRadius))
    let mask = CAShapeLayer()
    mask.path = path.cgPath
    layer.mask = mask
    if let capacitanceBar = capacitanceBar {
      let path = UIBezierPath(
        roundedRect: capacitanceBar.bounds, byRoundingCorners: [.topLeft, .topRight],
        cornerRadii: CGSize(width: borderRadius, height: borderRadius))
      let mask = CAShapeLayer()
      mask.path = path.cgPath
      capacitanceBar.layer.mask = mask
    }
  }

  /// Adds the bar view reflecting the capacitance value in a bar chart.
  private func addCapacitanceBar() {
    let barView = UIView()
    self.addSubview(barView)
    barView.translatesAutoresizingMaskIntoConstraints = false
    barViewTopConstraint = barView.topAnchor.constraint(equalTo: self.topAnchor, constant: 0)
    var constraints = [NSLayoutConstraint]()
    constraints.append(barView.leftAnchor.constraint(equalTo: self.leftAnchor, constant: 0))
    constraints.append(barView.rightAnchor.constraint(equalTo: self.rightAnchor, constant: 0))
    constraints.append(barView.bottomAnchor.constraint(equalTo: self.bottomAnchor, constant: 0))
    constraints.append(barViewTopConstraint)
    NSLayoutConstraint.activate(constraints)
    capacitanceBar = barView
  }

  /// Processes the received capacitance data and uses it to adjust the height of a bar in a bar
  /// chart.
  func processData(lineData: UInt8) {
    capacitanceBar?.backgroundColor = Constants.capacitanceBarColor.withAlphaComponent(
      CGFloat(lineData) / maximumCapacitanceDataValue)
    let updatedHeight = (capacitanceBarHeight * CGFloat(lineData)) / maximumCapacitanceDataValue
    barViewTopConstraint.constant = CGFloat(capacitanceBarHeight - updatedHeight)
  }
}
