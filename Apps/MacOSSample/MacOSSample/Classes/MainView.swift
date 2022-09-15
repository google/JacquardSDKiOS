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
import CombineExt
import CoreBluetooth
import JacquardSDK
import SwiftUI

/// Class providing a hook to get access to the `NSWindow` (via an `NSView`).
struct WindowSetup: NSViewRepresentable {
  func makeNSView(context: Context) -> NSView {
    let view = NSView()
    DispatchQueue.main.async {
      // Disable window close button.
      view.window?.standardWindowButton(NSWindow.ButtonType.closeButton)?.isHidden = true
    }
    return view
  }

  func updateNSView(_ nsView: NSView, context: Context) {}
}

extension CBManagerState {
  var isBuletoothReady: Bool {
    switch self {
    case .poweredOn:
      return true
    case .unknown, .resetting, .unsupported, .unauthorized, .poweredOff:
      return false
    @unknown default:
      return false
    }
  }
}

struct MainView: View {

  @EnvironmentObject
  private var appState: AppState

  var body: some View {
    VStack {
      if appState.centralState.isBuletoothReady {
        NavigationView {
          VStack {
            ScanningStartStopView()
            TagListView()
          }
        }
      } else {
        Text("Waiting for Bluetooth...")
      }
    }
    .background(WindowSetup())
  }
}
