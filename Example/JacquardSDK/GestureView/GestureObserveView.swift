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

struct GestureObserveView: View {

  private var tagPublisher: AnyPublisher<ConnectedTag, Never>

  @State private var observers = [Cancellable]()

  @State private var observedGestures = [GestureModel]()

  @State private var showGestureBlur = false

  @State private var showGestureList = false

  init(tagPublisher: AnyPublisher<ConnectedTag, Never>) {
    self.tagPublisher = tagPublisher
  }

  fileprivate struct GestureModel: Identifiable {
    var gesture: JacquardSDK.Gesture
    var id = UUID()
  }

  var body: some View {

    ZStack(alignment: .center) {
      VStack(alignment: .leading) {
        Text("Gestures")
          .font(.system(size: 30.0, weight: .medium))
          .padding(.top, 20)
          .padding(.leading, 20)
        Text("FEED")
          .font(.system(size: 12.0))
          .foregroundColor(Color(red: 0.392, green: 0.392, blue: 0.392))
          .padding(.top, 20)
          .padding(.leading, 20)
        List {
          ForEach(observedGestures) {
            Text("\($0.gesture.name) logged")
              .font(.system(size: 14.0, weight: .medium))
          }
        }
        .onAppear {
          tagPublisher
            .sink { tag in
              tag.registerSubscriptions(self.createGestureSubscription)
            }.addTo(&observers)
        }
      }.navigationBarItems(
        trailing: Button(
          action: {
            showGestureList = true
          },
          label: {
            Image("info")
          }
        )
        .buttonStyle(PlainButtonStyle())
        .frame(width: 30, height: 30)
      )
      .sheet(isPresented: $showGestureList) {
        GestureListRepresentable()
      }
      if showGestureBlur {
        if let gesture = observedGestures.last?.gesture {
          GuestureBlurModalView(gestureName: gesture.name, imageName: "\(gesture.self)")
            .onAppear {
              DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                showGestureBlur = false
              }
            }
        }
      }
    }
  }

  // Gestures subscription is used to get most recently executed gesture.
  private func createGestureSubscription(_ tag: SubscribableTag) {

    tag.subscribe(GestureNotificationSubscription())
      .sink { gesture in
        showGestureBlur = true
        let gestureModel = GestureModel(gesture: gesture)
        observedGestures.append(gestureModel)
      }.addTo(&observers)
  }

}

// A blur view that shows the guesture performed.
struct GuestureBlurModalView: View {

  var gestureName: String
  var imageName: String
  var body: some View {
    ZStack {
      Color.white.opacity(0.8).blur(radius: 10.0)
      VStack {
        Spacer()
        Image(imageName)
          .resizable()
          .frame(width: 120.0, height: 120.0)
        Text(gestureName)
        Spacer()
      }
    }
  }
}
