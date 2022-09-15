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

final class ConnectedGearTests: XCTestCase {
  private var observers = [Cancellable]()

  func testConnectedGear() {
    let transport = FakeTransport()
    let connectedTag = ConnectedTagModel(
      transport: transport,
      userPublishQueue: .main,
      tagComponent: FakeConnectedTag(transport: transport).tagComponent,
      sdkConfig: config
    )

    let expectAttach = expectation(description: "Expecting attachment")
    connectedTag.connectedGear.sink { component in
      XCTAssertEqual(component?.vendor.name, "Levi's")
      XCTAssertEqual(component?.version, Version(major: 1, minor: 2, micro: 3))
      XCTAssertEqual(component?.uuid, "123456789")
      expectAttach.fulfill()
    }.addTo(&observers)

    transport.postGearAttach()
    wait(for: [expectAttach], timeout: 1)

    // Ensure attached gear is replayed immediately.

    let expectAttachReplay = expectation(description: "Expecting attachment replay")
    connectedTag.connectedGear.sink { component in
      XCTAssertEqual(component?.vendor.name, "Levi's")
      XCTAssertEqual(component?.version, Version(major: 1, minor: 2, micro: 3))
      XCTAssertEqual(component?.uuid, "123456789")
      expectAttachReplay.fulfill()
    }.addTo(&observers)

    wait(for: [expectAttachReplay], timeout: 1)
  }
}
