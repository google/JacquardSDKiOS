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

class FirmwareUpdateRetrieverImplementation: FirmwareUpdateRetriever {

  private enum Constants {
    static let dfuInfoKey = "dfuInfo"
    static let imageDataKey = "imageData"
    static let dfuInfoLastFetchedTimeKey = "dfuInfoLastFetchedTime"
  }
  private var observers = [Cancellable]()
  private let userPublishQueue: DispatchQueue
  private let cloudManager: CloudManager
  private let cacheManager: CacheManager

  init(
    publishQueue: DispatchQueue = .main,
    cloudManager: CloudManager,
    cacheManager: CacheManager
  ) {
    userPublishQueue = publishQueue
    self.cloudManager = cloudManager
    self.cacheManager = cacheManager
  }

  convenience init(config: SDKConfig) {
    self.init(cloudManager: CloudManagerImpl(sdkConfig: config), cacheManager: CacheManagerImpl())
  }

  func checkUpdate(
    request: FirmwareUpdateRequest,
    forceCheck: Bool
  ) -> AnyPublisher<DFUUpdateInfo, APIError> {
    if !forceCheck,
      let cachedInfo = retrieveFirmwareInfo(
        vendorID: request.requestedVendorID,
        productID: request.requestedProductID,
        moduleID: request.module?.moduleID.hexString(),
        uuid: request.component.uuid
      )
    {
      if cachedInfo.version == request.componentVersion || cachedInfo.dfuStatus == .none {
        return Empty<DFUUpdateInfo, APIError>(completeImmediately: true).eraseToAnyPublisher()
      }
      // Return cached info.
      return Just<DFUUpdateInfo>(cachedInfo)
        .setFailureType(to: APIError.self)
        .eraseToAnyPublisher()
    } else {
      // if cached info is not available, fetch from remote server.
      return cloudManager.getDeviceFirmware(params: request.parameters)
        .filter { [weak self] info in
          if info.dfuStatus == .none {
            // There is no image to download, hence saving update info here.
            self?.saveFirmwareInfo(info: info, uuid: request.component.uuid)
            return false
          }
          return true
        }
        .flatMap { [weak self] info -> AnyPublisher<DFUUpdateInfo, APIError> in
          guard let self = self else {
            return Fail<DFUUpdateInfo, APIError>(error: .undefined).eraseToAnyPublisher()
          }

          if let cachedInfo = self.retrieveFirmwareInfo(
            vendorID: info.vid,
            productID: info.pid,
            moduleID: request.module?.moduleID.hexString(),
            uuid: request.component.uuid
          ), cachedInfo == info {
            return Just<DFUUpdateInfo>(cachedInfo)
              .setFailureType(to: APIError.self)
              .eraseToAnyPublisher()
          }
          return self.downloadFirmware(dfuInfo: info, uuid: request.component.uuid)
        }
        .prefix(1)
        .receive(on: userPublishQueue)
        .eraseToAnyPublisher()
    }
  }

  private func downloadFirmware(
    dfuInfo: DFUUpdateInfo,
    uuid: String?
  ) -> AnyPublisher<DFUUpdateInfo, APIError> {
    guard let downloadURL = dfuInfo.downloadURL, let url = URL(string: downloadURL) else {
      return Fail<DFUUpdateInfo, APIError>(error: .invalidURL).eraseToAnyPublisher()
    }
    return
      cloudManager.downloadFirmwareImage(url: url)
      .map { data in
        var firmwareInfo = dfuInfo
        firmwareInfo.image = data
        // Save the firmware info to cache.
        self.saveFirmwareInfo(info: firmwareInfo, uuid: uuid)
        return firmwareInfo
      }
      .prefix(1)
      .receive(on: userPublishQueue)
      .eraseToAnyPublisher()
  }

  private func cacheKey(
    prefix: String, vendorID: String, productID: String, moduleID: String?, uuid: String? = nil
  ) -> String {
    var combined = "\(prefix)_\(vendorID)_\(productID)"
    if let moduleID = moduleID {
      combined.append("_\(moduleID)")
    }
    if let uuid = uuid, !uuid.isEmpty {
      combined.append("_\(uuid)")
    }
    return combined.md5Hash()
  }

  /// Saves the firmware info to cache.
  private func saveFirmwareInfo(
    info: DFUUpdateInfo,
    uuid: String?
  ) {
    let dfuKey = cacheKey(
      prefix: Constants.dfuInfoKey,
      vendorID: info.vid,
      productID: info.pid,
      moduleID: info.mid,
      uuid: uuid
    )
    cacheManager.cache(info, for: dfuKey)
    let imageKey = cacheKey(
      prefix: Constants.imageDataKey, vendorID: info.vid, productID: info.pid, moduleID: info.mid)
    cacheManager.cacheImage(info.image, for: imageKey)

    let dfuInfoLastFetchedKey = cacheKey(
      prefix: Constants.dfuInfoLastFetchedTimeKey,
      vendorID: info.vid,
      productID: info.pid,
      moduleID: info.mid,
      uuid: uuid
    )
    cacheManager.cache(Date(), for: dfuInfoLastFetchedKey)
  }

  /// Returns `DFUUpdateInfo` combining firmware info and Image data from cache.
  private func retrieveFirmwareInfo(
    vendorID: String,
    productID: String,
    moduleID: String?,
    uuid: String?
  ) -> DFUUpdateInfo? {

    let dfuInfoLastFetchedKey = cacheKey(
      prefix: Constants.dfuInfoLastFetchedTimeKey,
      vendorID: vendorID,
      productID: productID,
      moduleID: moduleID,
      uuid: uuid
    )
    guard
      let lastFetchedTime: Date = cacheManager.retrieve(for: dfuInfoLastFetchedKey),
      abs(Date().timeIntervalSince(lastFetchedTime)) <= CacheManagerImpl.Constants.cacheTimeInterval
    else {
      return nil
    }

    let key = cacheKey(
      prefix: Constants.dfuInfoKey,
      vendorID: vendorID,
      productID: productID,
      moduleID: moduleID,
      uuid: uuid
    )
    var dfuInfo: DFUUpdateInfo? = cacheManager.retrieve(for: key)
    if dfuInfo?.dfuStatus == DFUUpdateInfoStatus.none {
      return dfuInfo
    }

    guard
      let imageData = retrieveImageInfo(
        vendorID: vendorID, productID: productID, moduleID: moduleID
      )
    else {
      // As imageData not available return nil.
      return nil
    }
    dfuInfo?.image = imageData
    return dfuInfo
  }

  /// Returns Image data from cache.
  private func retrieveImageInfo(
    vendorID: String, productID: String, moduleID: String?
  ) -> Data? {
    let key = cacheKey(
      prefix: Constants.imageDataKey,
      vendorID: vendorID,
      productID: productID,
      moduleID: moduleID
    )
    return cacheManager.retrieveImage(for: key)
  }

}
