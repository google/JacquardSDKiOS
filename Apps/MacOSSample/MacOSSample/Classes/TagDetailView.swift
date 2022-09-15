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
import JacquardSDK
import SwiftUI

struct TagDetailView: View {

  @EnvironmentObject
  private var appState: AppState

  private var tagID: UUID

  var connectionState: TagConnectionState? {
    appState.connectionStates.first { $0.id == tagID }?.state
  }

  init(_ tagID: UUID) {
    self.tagID = tagID
  }

  var body: some View {
    if let connectionState = connectionState {
      switch connectionState {
      case .preparingToConnect:
        Text("Preparing to connect…")
      case .connecting(let step, let ofSteps):
        Text("Connecting \(step) / \(ofSteps)…")
      case .initializing(let step, let ofSteps):
        Text("Intializing \(step) / \(ofSteps)…")
      case .configuring(let step, let ofSteps):
        Text("Configuring \(step) / \(ofSteps)…")
      case .connected(let connectedTag):
        ConnectedTagDetailView(Tag(connectedTag))
          .background(Color.white)
      case .disconnected(let error):
        if let error = error {
          Text("Disconnected: \(error.localizedDescription)")
        } else {
          Text("Disconnected")
        }
      }
    } else {
      Text("Connection not found")
    }
  }
}

struct IdentifiableGesture: Identifiable {
  var gesture: JacquardSDK.Gesture
  var id = UUID()
}

struct ConnectedTagDetailView: View {

  @State
  private var observedGestures = [IdentifiableGesture]()

  var gearImageName: String {
    tag.connectedGear?.product.image ?? "Gear_Not_Attached"
  }

  var gearName: String {
    tag.connectedGear?.product.name ?? "Gear not attached"
  }

  var batteryStatus: String {
    if let status = tag.batteryStatus {
      return "Battery: \(status.batteryLevel)%, \(status.chargingState.text)"
    } else {
      return "Battery: ---"
    }
  }

  @ObservedObject
  private var tag: Tag

  init(_ tag: Tag) {
    self.tag = tag
  }

  var body: some View {
    VStack {
      HStack(alignment: .top) {
        VStack(alignment: .leading, spacing: 8) {
          Text(tag.name)
          Text("RSSI: \(tag.rssi)")
            .foregroundColor(.signalColor(tag.rssi))
          Text(gearName)
          Text(batteryStatus)
        }
        Spacer()
        Image(gearImageName, bundle: nil)
      }.padding()
      List {
        Text("Observed Gestures:")
          .bold()
        ForEach(observedGestures) {
          Text($0.gesture.name)
        }
      }
    }.onReceive(tag.gesturePublisher) { gesture in
      observedGestures.append(IdentifiableGesture(gesture: gesture))
    }
  }
}

extension BatteryStatus.ChargingState {
  var text: String {
    switch self {
    case .charging: return "Charging"
    case .notCharging: return "Not Charging"
    }
  }
}

extension Color {
  static let goodSignalRSSI = Color(red: 0.117, green: 0.557, blue: 0.243)
  static let fairSignalRSSI = Color(red: 0.95, green: 0.6, blue: 0.0)
  static let weakSignalRSSI = Color(red: 0.850, green: 0.188, blue: 0.145)

  /// Provides signal color depending upon the range value.
  static func signalColor(_ signalValue: Float) -> Color {
    if signalValue >= -65.0 {
      return .goodSignalRSSI
    } else if signalValue <= -66.0 && signalValue >= -80.0 {
      return .fairSignalRSSI
    } else {
      return .weakSignalRSSI
    }
  }
}
