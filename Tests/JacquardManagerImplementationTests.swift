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
import XCTest

@testable import JacquardSDK

final class JacquardManagerImplementationTests: XCTestCase {

  var observations = [Cancellable]()

  func testBluetoothtPowerStateCallback() {
    let stateExpectation = expectation(description: "StateExpectation")
    stateExpectation.expectedFulfillmentCount = 2

    var centralManager: FakeCentralManager?
    let jqm = JacquardManagerImplementation { (delegate) -> CentralManagerProtocol in
      centralManager = FakeCentralManager(delegate: delegate)
      return centralManager!
    }
    jqm.centralState.sink { (state) in
      stateExpectation.fulfill()
    }.addTo(&observations)

    centralManager?.fakeState = .poweredOn
    wait(for: [stateExpectation], timeout: 1.0)
  }
}
