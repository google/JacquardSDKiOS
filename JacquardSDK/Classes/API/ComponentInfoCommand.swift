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

/// Command to request the info of the component like firmware version.
///
/// - SeeAlso: `Commands`
public struct ComponentInfoCommand: CommandRequest {

  /// `ComponentInfoCommand` response value.
  public typealias Response = ComponentInfo

  /// ID of the component for which the info has to be fetched.
  let componentID: UInt32

  /// Initializes the command.
  ///
  /// - Parameters:
  ///   - componentID: ID of the component for which the info has to be fetched.
  public init(componentID: UInt32) {
    self.componentID = componentID
  }
}

/// Information about the component.
///
/// The result type of `ComponentInfoCommand`.
public struct ComponentInfo {

  /// Represents the firmware version of the component.
  public var version: Version

  /// Represents unique identifer of the component.
  public var uuid: String
}
