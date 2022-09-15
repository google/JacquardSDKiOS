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

class IMUModuleTests: XCTestCase {

  func testDesriptorIntializer() {

    let descriptor = Google_Jacquard_Protocol_ModuleDescriptor.with {
      $0.name = "testModule"
      $0.vendorID = 999
      $0.productID = 123
      $0.moduleID = 456
      $0.verMajor = 20
      $0.verMinor = 10
      $0.verPoint = 1
      $0.isEnabled = true
    }

    let testModule = Module(moduleDescriptor: descriptor)
    XCTAssertNotNil(testModule)
    XCTAssertEqual(testModule.name, "testModule")

    let returnDescriptor = testModule.getModuleDescriptorRequest()
    XCTAssertNotNil(returnDescriptor)
    XCTAssertEqual(returnDescriptor.moduleID, descriptor.moduleID)
  }

  func testDFUInfoIntializer() {

    let testModule = Module(
      name: "Test module",
      moduleID: 1_024_190_291,
      vendorID: 293_089_480,
      productID: 4_013_841_288,
      version: nil,
      isEnabled: false
    )

    XCTAssertNotNil(testModule)
    XCTAssertEqual(testModule.name, "Test module")

    let returnDescriptor = testModule.getModuleDescriptorRequest()
    XCTAssertNotNil(returnDescriptor)
    XCTAssertEqual(returnDescriptor.moduleID, 1_024_190_291)
  }
}
