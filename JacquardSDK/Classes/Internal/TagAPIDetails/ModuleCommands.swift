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

/// Command request to retrieve all the modules available in the device.
struct ListModulesCommand: CommandRequest {

  var request: V2ProtocolCommandRequestIDInjectable {
    var request = Google_Jacquard_Protocol_Request()
    request.domain = .base
    request.opcode = .listModules

    return request
  }

  func parseResponse(outerProto: Any) -> Result<[Module], Error> {
    guard let outerProto = outerProto as? Google_Jacquard_Protocol_Response else {
      jqLogger.assert(
        "calling parseResponse() with anything other than Google_Jacquard_Protocol_Response is an error"
      )
      return .failure(CommandResponseStatus.errorAppUnknown)
    }
    guard outerProto.hasGoogle_Jacquard_Protocol_ListModuleResponse_listModules else {
      return .failure(JacquardCommandError.malformedResponse)
    }

    let moduleDiscriptors =
      outerProto.Google_Jacquard_Protocol_ListModuleResponse_listModules.modules

    let modules = moduleDiscriptors.map { Module(moduleDescriptor: $0) }

    return .success(modules)
  }
}

/// Command request to activate a module in the device.
struct ActivateModuleCommand: CommandRequest {

  let module: Module

  init(module: Module) {
    self.module = module
  }

  var request: V2ProtocolCommandRequestIDInjectable {
    var request = Google_Jacquard_Protocol_Request()
    request.domain = .base
    request.opcode = .loadModule

    var loadModuleRequest = Google_Jacquard_Protocol_LoadModuleRequest()
    loadModuleRequest.module = module.getModuleDescriptorRequest()
    request.Google_Jacquard_Protocol_LoadModuleRequest_loadModule = loadModuleRequest

    return request
  }

  func parseResponse(outerProto: Any) -> Result<Void, Error> {
    guard outerProto is Google_Jacquard_Protocol_Response else {
      jqLogger.assert(
        "calling parseResponse() with anything other than Google_Jacquard_Protocol_Response is an error"
      )
      return .failure(CommandResponseStatus.errorAppUnknown)
    }
    return .success(())
  }
}

struct ActivateModuleNotificationSubscription: NotificationSubscription {

  /// Initialize a subscription request.
  public init() {}

  func extract(from outerProto: Any) -> Google_Jacquard_Protocol_LoadModuleNotification? {
    guard let notification = outerProto as? Google_Jacquard_Protocol_Notification else {
      jqLogger.assert(
        "calling extract() with anything other than Google_Jacquard_Protocol_Notification is an error"
      )
      return nil
    }

    // Silently ignore other notifications.
    guard
      notification.hasGoogle_Jacquard_Protocol_LoadModuleNotification_loadModuleNotif
    else {
      return nil
    }

    let innerProto =
      notification.Google_Jacquard_Protocol_LoadModuleNotification_loadModuleNotif
    return innerProto
  }
}

/// Command request to de-activate a module in the device.
struct DeactivateModuleCommand: CommandRequest {

  let module: Module

  init(module: Module) {
    self.module = module
  }

  var request: V2ProtocolCommandRequestIDInjectable {
    var request = Google_Jacquard_Protocol_Request()
    request.domain = .base
    request.opcode = .unloadModule

    var unloadModuleRequest = Google_Jacquard_Protocol_UnloadModuleRequest()
    unloadModuleRequest.module = module.getModuleDescriptorRequest()
    request.Google_Jacquard_Protocol_UnloadModuleRequest_unloadModule = unloadModuleRequest

    return request
  }

  func parseResponse(outerProto: Any) -> Result<Void, Error> {
    guard outerProto is Google_Jacquard_Protocol_Response else {
      jqLogger.assert(
        "calling parseResponse() with anything other than Google_Jacquard_Protocol_Response is an error"
      )
      return .failure(CommandResponseStatus.errorAppUnknown)
    }
    return .success(())
  }
}

/// Command request to delete a module in the device.
struct DeleteModuleCommand: CommandRequest {

  let module: Module

  init(module: Module) {
    self.module = module
  }

  var request: V2ProtocolCommandRequestIDInjectable {
    var request = Google_Jacquard_Protocol_Request()
    request.domain = .base
    request.opcode = .deleteModule

    var deleteModuleRequest = Google_Jacquard_Protocol_DeleteModuleRequest()
    deleteModuleRequest.module = module.getModuleDescriptorRequest()
    request.Google_Jacquard_Protocol_DeleteModuleRequest_deleteModule = deleteModuleRequest

    return request
  }

  func parseResponse(outerProto: Any) -> Result<Void, Error> {
    guard outerProto is Google_Jacquard_Protocol_Response else {
      jqLogger.assert(
        "calling parseResponse() with anything other than Google_Jacquard_Protocol_Response is an error"
      )
      return .failure(CommandResponseStatus.errorAppUnknown)
    }
    return .success(())
  }
}
