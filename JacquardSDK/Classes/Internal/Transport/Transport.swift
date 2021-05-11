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
import Foundation

protocol Transport {

  typealias RequestCallback = (ResponseResult) -> Void

  typealias ResponseResult = Result<Data, Error>

  /// Publisher of any time CoreBluetooth reports didWriteValue.
  ///
  /// Currently write responses are only requested during initialization, so this is not generally
  /// useful.
  var didWriteCommandPublisher: AnyPublisher<Error?, Never> { get set }

  var notificationPublisher: AnyPublisher<Google_Jacquard_Protocol_Notification, Never> { get }

  var peripheralNamePublisher: AnyPublisher<String, Never> { get set }

  var peripheralName: String { get }

  var peripheralIdentifier: UUID { get }

  init(peripheral: Peripheral, characteristics: RequiredCharacteristics)

  func stopCachingNotifications()

  func enqueue(
    request: V2ProtocolCommandRequestIDInjectable,
    type: CharacteristicWriteType,
    retries: Int,
    callback: @escaping RequestCallback
  )
}
