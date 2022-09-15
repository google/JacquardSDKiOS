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

class FakeCloudManager: CloudManager {

  var session = URLSession(configuration: .default)
  var dfuInfo: DFUUpdateInfo?
  var error: APIError?
  var fileData: Data?

  public func getDeviceFirmware(params: [String: Any]) -> AnyPublisher<DFUUpdateInfo, APIError> {

    if let dfuInfo = dfuInfo {
      return Just(dfuInfo).setFailureType(to: APIError.self).eraseToAnyPublisher()
    }
    if let error = error {
      return Fail(error: error).eraseToAnyPublisher()
    }
    preconditionFailure("Should not reach this line")
  }

  public func downloadFirmwareImage(url: URL) -> AnyPublisher<Data, APIError> {

    if let fileData = fileData {
      return Just(fileData).setFailureType(to: APIError.self).eraseToAnyPublisher()
    }
    if let error = error {
      return Fail(error: error).eraseToAnyPublisher()
    }
    preconditionFailure("Should not reach this line")
  }

}
