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

import Cocoa
import JacquardSDK
import SwiftUI

private var sharedAppState = AppState()

@main
struct MacOSSampleApp: App {
  var body: some Scene {
    WindowGroup {
      MainView()
        .frame(
          minWidth: 500,
          maxWidth: .infinity,
          minHeight: 400,
          maxHeight: .infinity,
          alignment: .center
        )
        .environmentObject(sharedAppState)
    }
    .commands {
      // Remove unnecessary menu items.
      CommandGroup(replacing: .appSettings, addition: {})
      CommandGroup(replacing: .newItem, addition: {})
      CommandGroup(replacing: .saveItem, addition: {})
      CommandGroup(replacing: .toolbar, addition: {})
    }
  }
}
