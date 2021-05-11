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

import Foundation

/// Errors that can be encountered while sending module commands.
public enum ModuleError: Error {
  /// Module was not loaded in the device.
  case moduleUnavailable

  /// Failed to load module on the device and activate it.
  case failedToLoadModule

  /// Failed to activate the module.
  case failedToActivateModule

  /// Failed to deactivate the module.
  case failedToDeactivateModule

  /// Invalid response received.
  case invalidResponse

  /// The provided parameter is not valid or not within the supported range.
  case invalidParameter

  /// Request timed out.
  case timedOut

  /// File Manager error.
  case directoryUnavailable

  /// Error when there is already a download in progress.
  case downloadInProgress

  /// Error when empty data is recieved from the tag.
  case emptyDataReceived
}

/// An object that holds information of a loadable module.
public struct Module {
  /// The module name.
  let name: String

  /// The module identifier.
  let moduleID: Identifier

  /// The vendor identifier.
  let vendorID: Identifier

  /// The product identifier.
  let productID: Identifier

  /// The version of this module.
  let version: Version?

  /// `true` if the module is enabled. i.e. activated.
  let isEnabled: Bool

  init(moduleDescriptor: Google_Jacquard_Protocol_ModuleDescriptor) {
    self.name = moduleDescriptor.name
    self.moduleID = moduleDescriptor.moduleID
    self.vendorID = moduleDescriptor.vendorID
    self.productID = moduleDescriptor.productID
    self.version = Version(
      major: moduleDescriptor.verMajor,
      minor: moduleDescriptor.verMinor,
      micro: moduleDescriptor.verPoint
    )
    self.isEnabled = moduleDescriptor.isEnabled
  }

  init(
    name: String,
    moduleID: Identifier,
    vendorID: Identifier,
    productID: Identifier,
    version: Version?,
    isEnabled: Bool
  ) {
    self.name = name
    self.moduleID = moduleID
    self.vendorID = vendorID
    self.productID = productID
    self.version = version
    self.isEnabled = isEnabled
  }

  func getModuleDescriptorRequest() -> Google_Jacquard_Protocol_ModuleDescriptor {
    return Google_Jacquard_Protocol_ModuleDescriptor.with { moduleDescriptor in
      moduleDescriptor.moduleID = self.moduleID
      moduleDescriptor.vendorID = self.vendorID
      moduleDescriptor.productID = self.productID
      moduleDescriptor.name = self.name
    }
  }
}
