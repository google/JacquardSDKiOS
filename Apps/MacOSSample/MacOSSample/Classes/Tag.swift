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
import CoreBluetooth
import JacquardSDK
import SwiftUI

/// Wraps a Jacquard `ConnectedTag` in a SwiftUI-friendly way.
class Tag: ObservableBase {
  private var underlyingTag: ConnectedTag
  private var updateTimer =
    Timer
    .publish(every: 1, on: .main, in: .common)
    .autoconnect()

  private(set) var name: String
  private(set) var connectedGear: Component?
  private(set) var rssi: Float = 0
  private(set) var batteryStatus: BatteryStatus?

  private(set) var gesturePublisher = Just<JacquardSDK.Gesture>(.brushIn)
    .eraseToAnyPublisher()

  init(_ tag: ConnectedTag) {
    self.underlyingTag = tag
    self.name = tag.name

    super.init()

    bind(tag.namePublisher) { [weak self] in self?.name = $0 }
    bind(tag.connectedGear) { [weak self] in self?.connectedGear = $0 }
    bind(tag.rssiPublisher) { [weak self] in self?.rssi = $0 }

    // Ensure we get an initial battery status.
    bind(tag.enqueue(BatteryStatusCommand())) { [weak self] in self?.batteryStatus = $0 }

    // Request updates to rssi status every second.
    // In a real app you will usually want to do this more judiciously.
    updateTimer
      .sink { [weak self] _ in
        self?.underlyingTag.readRSSI()
      }.addTo(&observations)

    // Observe periodic battery and gesture notifications.
    underlyingTag.registerSubscriptions { [weak self] subscribableTag in
      guard let self = self else { return }

      bind(subscribableTag.subscribe(BatteryStatusNotificationSubscription())) { [weak self] in
        self?.batteryStatus = $0
      }

      self.gesturePublisher =
        subscribableTag
        .subscribe(GestureNotificationSubscription())
    }
  }
}
