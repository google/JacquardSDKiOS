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

extension ConnectionState {
  fileprivate var cellLabel: String {
    switch state {
    case .preparingToConnect: return "Preparing…"
    case .connecting: return "Connecting…"
    case .initializing: return "Initializing…"
    case .configuring: return "Configuring…"
    case .connected(let tag): return tag.displayName
    case .disconnected: return "Disconnected!"
    }
  }
}

struct TagListView: View {

  @EnvironmentObject
  private var appState: AppState

  @State
  private var selectedTagID: UUID?

  var body: some View {
    List {
      if appState.isScanning {
        Section("Advertising Tags") {
          ForEach(appState.advertisingTags, id: \.identifier) { tag in
            HStack {
              Text(tag.displayName)
              Button("Connect") {
                appState.connect(tag)
                // If no tag yet selected, select this one.
                if selectedTagID == nil {
                  selectedTagID = tag.identifier
                }
              }
            }
          }
        }
      }

      Section("Active Tags") {
        ForEach(appState.connectionStates) { state in
          HStack {
            NavigationLink(state.cellLabel, tag: state.id, selection: $selectedTagID) {
              TagDetailView(state.id)
            }
            Spacer()
            Button(
              action: {
                Preferences.removeKnownTag(state.id)
                appState.disconnect(state.id)
              },
              label: {
                Image(systemName: "xmark.circle.fill")
              }
            ).buttonStyle(.plain)
          }
        }
      }
    }
    .listStyle(.sidebar)
  }
}
