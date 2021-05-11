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

import MaterialComponents

@IBDesignable public class RoundButton: MDCButton {

  let buttonScheme = MDCContainerScheme()
  var shapeScheme = MDCShapeScheme()
  var disabledBackgroundColor: UIColor?
  var disabledTitleColor: UIColor?

  override init(frame: CGRect) {
    super.init(frame: frame)
    configureSchemes()
  }

  required public init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
    configureSchemes()
  }

  private func configureSchemes() {
    configureShapeScheme()
    configureColorScheme()
    configureTypographyScheme()
    self.applyContainedTheme(withScheme: buttonScheme)
    setBackgroundColor(disabledBackgroundColor, for: .disabled)
    setTitleColor(disabledTitleColor, for: .disabled)
  }

  private func configureShapeScheme() {
    shapeScheme.smallComponentShape = MDCShapeCategory(
      cornersWith: .rounded,
      andSize: self.frame.size.height / 2
    )
    buttonScheme.shapeScheme = shapeScheme
  }

  func configureColorScheme() {
    // Not Required
    // Will be overridden by subclasses
  }

  func configureTypographyScheme() {
    // Not Required
    // Will be overridden by subclasses
  }
}

public class GreyRoundCornerButton: RoundButton {

  public override init(frame: CGRect) {
    super.init(frame: frame)
  }

  required public init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
  }

  override public func configureColorScheme() {
    disabledBackgroundColor = GreyColorScheme.disabledBackgroundColor()
    disabledTitleColor = GreyColorScheme.disabledTitleColor()
    buttonScheme.colorScheme = GreyColorScheme.colorScheme()
    isUppercaseTitle = false
    setShadowColor(.clear, for: .normal)
  }

  public override func setTitleColor(_ color: UIColor?, for state: UIControl.State) {
    super.setTitleColor(.white, for: state)
  }
}
