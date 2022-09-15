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

import XCTest

@testable import JacquardSDK

class ModuleComandsTests: XCTestCase {

  private let testModule = Module(
    name: "Test module",
    moduleID: 1_024_190_291,
    vendorID: 293_089_480,
    productID: 4_013_841_288,
    version: nil,
    isEnabled: false
  )

  struct CatchLogger: Logger {
    func log(
      level: LogLevel, file: StaticString, line: UInt, function: String, message: () -> String
    ) {
      let _ = message()
      if level == .assertion {
        expectation.fulfill()
      }
    }

    var expectation: XCTestExpectation
  }

  override func setUp() {
    super.setUp()

    let logger = PrintLogger(
      logLevels: [.debug, .info, .warning, .error, .assertion, .preconditionFailure],
      includeSourceDetails: true
    )
    setGlobalJacquardSDKLogger(logger)
  }

  override func tearDown() {
    // Other tests may run in the same process. Ensure that any fake logger fulfillment doesn't
    // cause any assertions later.
    JacquardSDK.setGlobalJacquardSDKLogger(JacquardSDK.createDefaultLogger())

    super.tearDown()
  }

  func testGoodProtoResponse<T: CommandRequest>(_ command: T) {
    let goodResponseExpectation = expectation(description: "goodResponseExpectation")
    let goodProto = Google_Jacquard_Protocol_Response()
    command.parseResponse(outerProto: goodProto).assertSuccess { _ in
      goodResponseExpectation.fulfill()
    }
    wait(for: [goodResponseExpectation], timeout: 1)
  }

  func testBadProtoResponse<T: CommandRequest>(_ command: T) {
    let badResponseExpectation = expectation(description: "badResponseExpectation")
    let badResponse = Google_Jacquard_Protocol_Color()
    jqLogger = CatchLogger(expectation: badResponseExpectation)
    command.parseResponse(outerProto: badResponse).assertFailure()
    wait(for: [badResponseExpectation], timeout: 1)
  }

  func testListModulesCommand() {
    let command = ListModulesCommand()

    guard let request = command.request as? Google_Jacquard_Protocol_Request else {
      XCTFail("Request type should be Jacquard Protocol Request")
      return
    }
    XCTAssertNotNil(command)
    XCTAssertEqual(request.domain, .base)
    XCTAssertEqual(request.opcode, .listModules)

    let descriptor = Google_Jacquard_Protocol_ModuleDescriptor.with {
      $0.name = "testModule"
      $0.vendorID = 999
      $0.productID = 123
      $0.moduleID = 456
      $0.verMajor = 78
      $0.verMinor = 910
      $0.verPoint = 11
      $0.isEnabled = true
    }

    let oneModuleResponse = Google_Jacquard_Protocol_Response.with {
      let listModules = Google_Jacquard_Protocol_ListModuleResponse.with {
        $0.modules = [descriptor]
      }
      $0.Google_Jacquard_Protocol_ListModuleResponse_listModules = listModules
    }

    command.parseResponse(outerProto: oneModuleResponse).assertSuccess { result in
      XCTAssertEqual(result.count, 1)
      let module = result.first!
      XCTAssertEqual(module.name, descriptor.name)
      XCTAssertEqual(module.moduleID, descriptor.moduleID)
    }

    let emptyModuleResponse = Google_Jacquard_Protocol_Response.with {
      let listModules = Google_Jacquard_Protocol_ListModuleResponse.with {
        $0.modules = []
      }
      $0.Google_Jacquard_Protocol_ListModuleResponse_listModules = listModules
    }
    command.parseResponse(outerProto: emptyModuleResponse).assertSuccess { result in
      XCTAssertEqual(result.count, 0)
    }

    testBadProtoResponse(command)
  }

  func testActivateModuleCommand() {
    let command = ActivateModuleCommand(module: testModule)
    XCTAssertNotNil(command)

    guard let request = command.request as? Google_Jacquard_Protocol_Request else {
      XCTFail("Request type should be Jacquard Protocol Request")
      return
    }
    XCTAssertEqual(request.domain, .base)
    XCTAssertEqual(request.opcode, .loadModule)
    let descriptor = request.Google_Jacquard_Protocol_LoadModuleRequest_loadModule.module
    XCTAssertEqual(descriptor.name, testModule.name)
    XCTAssertEqual(descriptor.moduleID, testModule.moduleID)

    testGoodProtoResponse(command)
    testBadProtoResponse(command)
  }

  func testDeactivateModuleCommand() {
    let command = DeactivateModuleCommand(module: testModule)
    XCTAssertNotNil(command)

    guard let request = command.request as? Google_Jacquard_Protocol_Request else {
      XCTFail("Request type should be Jacquard Protocol Request")
      return
    }
    XCTAssertEqual(request.domain, .base)
    XCTAssertEqual(request.opcode, .unloadModule)
    let descriptor = request.Google_Jacquard_Protocol_UnloadModuleRequest_unloadModule.module
    XCTAssertEqual(descriptor.name, testModule.name)
    XCTAssertEqual(descriptor.moduleID, testModule.moduleID)

    testGoodProtoResponse(command)
    testBadProtoResponse(command)
  }

  func testDeleteModuleCommand() {
    let command = DeleteModuleCommand(module: testModule)
    XCTAssertNotNil(command)

    guard let request = command.request as? Google_Jacquard_Protocol_Request else {
      XCTFail("Request type should be Jacquard Protocol Request")
      return
    }
    XCTAssertEqual(request.domain, .base)
    XCTAssertEqual(request.opcode, .deleteModule)
    let descriptor = request.Google_Jacquard_Protocol_DeleteModuleRequest_deleteModule.module
    XCTAssertEqual(descriptor.name, testModule.name)
    XCTAssertEqual(descriptor.moduleID, testModule.moduleID)

    testGoodProtoResponse(command)
    testBadProtoResponse(command)
  }
}
