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
import XCTest

extension Result {
  func assertSuccess(
    file: StaticString = #filePath, line: UInt = #line, valueCallback: (Success) -> Void = { _ in }
  ) {
    switch self {
    case .success(let value):
      valueCallback(value)
    case .failure(let error):
      XCTFail("Unexpected failure: \(error)", file: file, line: line)
    }
  }

  func assertFailure(
    file: StaticString = #filePath, line: UInt = #line, errorCallback: (Failure) -> Void = { _ in }
  ) {
    switch self {
    case .success(let value):
      XCTFail("Unexpected success: \(value)", file: file, line: line)
    case .failure(let error):
      errorCallback(error)
    }
  }
}
