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

class TouchView: UIView {

  var touches: TouchData = TouchData.empty {
    didSet {
      setNeedsDisplay()
    }
  }

  override func draw(_ rect: CGRect) {
    guard let context = UIGraphicsGetCurrentContext() else { return }
    context.setFillColor(UIColor.white.cgColor)
    context.fill(bounds)

    context.setStrokeColor(UIColor.black.cgColor)

    // This draws lines horizontally.

    let lines = touches.linesArray
    let spacing = bounds.height / CGFloat(lines.count + 1)
    var offset = bounds.minY + spacing

    for line in touches.linesArray.reversed() {
      context.move(to: CGPoint(x: bounds.minX, y: offset))
      context.addLine(to: CGPoint(x: bounds.maxX, y: offset))

      // Stroke max touch at line width of 10.
      let lineWidth = CGFloat(line) / 128 * 10
      context.setLineWidth(lineWidth)

      context.strokePath()

      offset += spacing
    }
  }
}
