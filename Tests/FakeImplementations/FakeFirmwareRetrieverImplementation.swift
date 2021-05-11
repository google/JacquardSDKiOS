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

@testable import JacquardSDK

final class FakeFirmwareRetrieverImplementation: FirmwareUpdateRetriever {

  private let updateInfoTag = DFUUpdateInfo(
    date: "21-06-2016",
    version: "1.0.0",
    dfuStatus: .mandatory,
    vid: "11-78-30-c8",
    pid: "28-3b-e7-a0",
    downloadURL: "https://www.google.com",
    image: Data((0..<1000).map { UInt8($0 % 255) })
  )

  private let updateInfoModule = DFUUpdateInfo(
    date: "21-06-2016",
    version: "1.0.0",
    dfuStatus: .mandatory,
    vid: "11-78-30-c8",
    pid: "ef-3e-5b-88",
    downloadURL: "https://www.google.com",
    image: Data((0..<1000).map { UInt8($0 % 255) })
  )

  private let updateInfoInterposer = DFUUpdateInfo(
    date: "21-06-2016",
    version: "1.0.0",
    dfuStatus: .mandatory,
    vid: "74-a8-ce-54",
    pid: "8a-66-50-f4",
    downloadURL: "https://www.google.com",
    image: Data((0..<1000).map { UInt8($0 % 255) })
  )

  func checkUpdate(
    request: FirmwareUpdateRequest,
    forceCheck: Bool
  ) -> AnyPublisher<DFUUpdateInfo, APIError> {

    if request.module != nil {
      return Result.Publisher(updateInfoModule).eraseToAnyPublisher()
    }
    switch (request.component.vendor.id, request.component.product.id) {
    case (updateInfoTag.vid, updateInfoTag.pid):
      return Result.Publisher(updateInfoTag).eraseToAnyPublisher()
    case (updateInfoInterposer.vid, updateInfoInterposer.pid):
      return Result.Publisher(updateInfoInterposer).eraseToAnyPublisher()
    default:
      return Result.Publisher(APIError.clientError).eraseToAnyPublisher()
    }
  }
}
