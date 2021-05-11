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

public class ColorScheme {

  public class func disabledBackgroundColor() -> UIColor {
    return .gray
  }

  public class func disabledTitleColor() -> UIColor {
    return .black
  }

  public class func colorScheme() -> MDCSemanticColorScheme {
    return MDCSemanticColorScheme(defaults: .material201804)
  }

  public class func colorFromRGB(_ colorValue: UInt32) -> UIColor {
    return UIColor(
      red: (CGFloat)(Double(((colorValue >> 16) & 0xFF)) / 255.0),
      green: (CGFloat)(Double(((colorValue >> 8) & 0xFF)) / 255.0),
      blue: (CGFloat)(Double((colorValue & 0xFF)) / 255.0),
      alpha: 1.0)
  }
}

public class GreyColorScheme: ColorScheme {

  override public class func disabledBackgroundColor() -> UIColor {
    return colorFromRGB(0xF2F2F2)
  }

  override public class func disabledTitleColor() -> UIColor {
    return colorFromRGB(0x888888)
  }

  override public class func colorScheme() -> MDCSemanticColorScheme {
    let scheme = MDCSemanticColorScheme(defaults: .material201804)
    scheme.primaryColor = colorFromRGB(0x3A3A3A)
    scheme.primaryColorVariant = colorFromRGB(0x3700B3)
    scheme.secondaryColor = colorFromRGB(0xFFFFFF)
    scheme.errorColor = colorFromRGB(0xB00020)
    scheme.surfaceColor = colorFromRGB(0xFFFFFF)
    scheme.backgroundColor = colorFromRGB(0xFFFFFF)
    scheme.onPrimaryColor = colorFromRGB(0xFFFFFF)
    scheme.onSecondaryColor = colorFromRGB(0xFFFFFF)
    scheme.onSurfaceColor = colorFromRGB(0x000000)
    scheme.onBackgroundColor = colorFromRGB(0xFFFFFF)
    return scheme
  }
}
