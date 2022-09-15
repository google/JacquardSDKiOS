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

/// Following are the possibilities of error that can come up while doing firmware upgrade.
public enum FirmwareUpdateError: Error {

  /// An error occurred within the SDK code itself.
  ///
  /// Please raise a bug if you encounter this error.
  case internalError(String)

  /// Failure occurred during api call (clientError, serverError, parsingFailed).
  case api(APIError)

  /// Tag connection error (Reason could be out of range, sleep, bluetooth communication).
  case tagDisconnected

  /// Operation failed due to low battery.
  case lowBattery

  /// Data is missing on the disk.
  case dataUnavailable

  /// When module info is not available.
  case moduleUnavailable

  /// State is incorrect during firmware update operations.
  ///
  /// e.g. When transferring of images starts, state should be idle. Or
  /// State should be transferred before calling executeUpdates() api. Otherwise api will send
  /// invalidState error.
  case invalidState(String)

  /// Error occured during transferring images to the tag/interposer.
  case transfer(Error)

  /// Error occured during flashing of image to the tag/interposer.
  case execution(Error)

  /// :nodoc:
  public var localizedDescription: String {
    switch self {
    case .internalError(let errorMessage): return errorMessage
    case .api(let error): return error.localizedDescription
    case .dataUnavailable: return "Data is missing on the disk."
    case .moduleUnavailable: return "Module info not found."
    case .invalidState(let errorMessage): return errorMessage
    case .tagDisconnected: return "Tag disconnected."
    case .lowBattery: return "Operation failed due to low battery."
    case .transfer(let error), .execution(let error): return error.localizedDescription
    }
  }
}

/// :nodoc:
public typealias DFUUpdatePublisher =
  AnyPublisher<[Result<DFUUpdateInfo, APIError>], FirmwareUpdateError>

/// Information about the current state of firmware updates.
public enum FirmwareUpdateState {

  /// When we start firmware update, this will be the initial state by default.
  case idle

  /// Firmware updates required precondition checks before start image transfer.
  case preparingForTransfer

  /// Firmware transfer is in progress.
  case transferring(Float)

  /// Transferring firmware to UJT has completed.
  case transferred

  /// Firmware execution is in progress.
  case executing

  /// Firmware execution is completed.
  case completed

  /// Firmware update errors.
  case error(FirmwareUpdateError)

  /// Firmware update stopped.
  case stopped

  var isTerminal: Bool {
    switch self {
    case .completed, .error, .stopped: return true
    default: return false
    }
  }
}

/// Provides a way to check, apply and execute firmware updates.
public protocol FirmwareUpdateManager: AnyObject {

  /// Publishes current firmware update state.
  var state: AnyPublisher<FirmwareUpdateState, Never> { get }

  /// Checks for updates and publishes the available updates info or an error.
  ///
  /// If vid/pid is provided, SDK will overwrite tag vid/pid and check updates. After success
  /// response, update info will be wrapped with tag vid/pid again to apply tag updates.
  ///
  /// - Parameters
  ///   - vendorID: VendorID, for which the update has to be checked.
  ///   - productID: ProductID, for which the update has to be checked.
  ///   - forceCheck: If `true`, api will check for update info from cloud instead of cache.
  func checkUpdates(
    vendorID: String?,
    productID: String?,
    forceCheck: Bool
  ) -> AnyPublisher<[DFUUpdateInfo], FirmwareUpdateError>

  /// Applies updates on the device. Publishes result as success/failure.
  /// - Parameters:
  ///   - updates: list of update info to be applied.
  ///   - shouldAutoExecute: 'true' if the firmware should be auto executed after transfer complete.
  func applyUpdates(
    _ updates: [DFUUpdateInfo],
    shouldAutoExecute: Bool
  ) -> AnyPublisher<FirmwareUpdateState, Never>

  /// Activates the uploaded firmware binaries and reboots the relevant hardware to run the updated
  /// code.
  func executeUpdates()

  /// Checks firmware update for loadable modules and publishes array of updates if available or an
  /// error.
  ///
  /// - Parameters:
  ///   - modules: List of `Module` for which the update has to be checked.
  ///   - forceCheck: If `true`, api will check for update info from cloud instead of cache.
  func checkModuleUpdates(_ modules: [Module], forceCheck: Bool) -> DFUUpdatePublisher

  /// Checks all loadable module updates and publish the available updates or an error.
  ///
  /// - Parameter forceCheck: If `true`, api will check for update info from cloud instead of cache.
  func checkModuleUpdates(forceCheck: Bool) -> DFUUpdatePublisher

  /// Stops the firmware transfer process.
  ///
  /// Throws an exception if updates has invalid state to stop the transfer process.
  /// States other than `preparingForTransfer`, `transferring` and `transferred`
  /// are not valid states to stop the process.
  func stopUpdates() throws
}

extension FirmwareUpdateManager {
  /// Apply module updates. Publishes result as success/failure. Auto execute should be `true` as
  /// module does not require execution part.
  ///
  /// - Parameter updates: list of module update info to be applied.
  public func applyModuleUpdates(
    _ updates: [DFUUpdateInfo]
  ) -> AnyPublisher<FirmwareUpdateState, Never> {
    applyUpdates(updates, shouldAutoExecute: true)
  }

  /// Checks for updates and publishes the available updates info or an error.
  ///
  /// - Parameter forceCheck: If `true`, api will check for update info from cloud instead of cache.
  public func checkUpdates(forceCheck: Bool) -> AnyPublisher<[DFUUpdateInfo], FirmwareUpdateError> {
    checkUpdates(vendorID: nil, productID: nil, forceCheck: forceCheck)
  }
}
