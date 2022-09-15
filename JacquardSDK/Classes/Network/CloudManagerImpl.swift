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

final class CloudManagerImpl: CloudManager {

  let session: URLSession
  let config: SDKConfig

  init(sessionConfig: URLSessionConfiguration, sdkConfig: SDKConfig) {
    self.session = URLSession(configuration: sessionConfig)
    self.config = sdkConfig
  }

  convenience init(sdkConfig: SDKConfig) {
    self.init(sessionConfig: .default, sdkConfig: sdkConfig)
  }

  func getDeviceFirmware(params: [String: Any]) -> AnyPublisher<DFUUpdateInfo, APIError> {
    let request = URLRequestBuilder.deviceFirmwareRequest(params: params, config: config)
    return execute(request: request, type: DFUUpdateInfo.self)
  }

  func downloadFirmwareImage(url: URL) -> AnyPublisher<Data, APIError> {
    let request = URLRequest(url: url)
    return downloadFile(request: request)
  }

}
