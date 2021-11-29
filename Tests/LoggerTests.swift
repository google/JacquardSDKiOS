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

class LoggerTests: XCTestCase {

  class FakeLogger: Logger {
    var callback: (LogLevel, StaticString, UInt, String, () -> String) -> Void

    init(callback: @escaping (LogLevel, StaticString, UInt, String, () -> String) -> Void) {
      self.callback = callback
    }

    func log(
      level: LogLevel, file: StaticString, line: UInt, function: String, message: () -> String
    ) {
      callback(level, file, line, function, message)
    }
  }

  override class func tearDown() {
    super.tearDown()

    // Other tests may run in the same process. Ensure that our fake logger fulfillment doesn't
    // cause any assertions later.
    JacquardSDK.setGlobalJacquardSDKLogger(JacquardSDK.createDefaultLogger())
  }

  /// Tests that there is a default `PrintLogger` set and we can use it.
  func testGlobalDefault() {
    XCTAssert(JacquardSDK.jqLogger is PrintLogger)
  }

  /// Tests that `setGlobalJacquardSDKLogger` changes the global logger, and that it continues to be accessable.
  func testSetGlobal() {
    let e = expectation(description: "Correct logger called")
    let fakeLogger = FakeLogger { (_, _, _, _, _) in
      e.fulfill()
    }

    JacquardSDK.setGlobalJacquardSDKLogger(fakeLogger)
    XCTAssert(JacquardSDK.jqLogger as? FakeLogger === fakeLogger)

    JacquardSDK.jqLogger.log(level: .debug, file: "", line: 0, function: "") { "" }
    wait(for: [e], timeout: 1)
  }

  /// Tests the log level enum String values.
  func testLogLevelDescription() {
    XCTAssertEqual(LogLevel.debug.rawValue, "DEBUG")
    XCTAssertEqual(LogLevel.info.rawValue, "INFO")
    XCTAssertEqual(LogLevel.warning.rawValue, "WARNING")
    XCTAssertEqual(LogLevel.error.rawValue, "ERROR")
    XCTAssertEqual(LogLevel.assertion.rawValue, "ASSERTION")
  }

  /// This doesn't *really* test that the logger prints to the console, but does exercise it sufficiently to show it doesn't crash and
  /// that we have exercised all code paths including ignored log levels.
  func testPrintLogger() {
    PrintLogger(logLevels: [.debug], includeSourceDetails: true).debug("test log")
    PrintLogger(logLevels: [.debug], includeSourceDetails: false).debug("test log")
    PrintLogger(logLevels: [.warning], includeSourceDetails: true).debug("test log")
    PrintLogger(logLevels: [.warning], includeSourceDetails: false).debug("test log")
  }

  func whoseLineIsThisAnyway(line: UInt = #line) -> UInt { line }

  /// Tests the default `Logger.debug()` method implementation on the `Logger` protocol.
  func testDefaultDebugImplementation() {
    let e = expectation(description: "Correct logger called")
    let actualLine = whoseLineIsThisAnyway() + 10
    let fakeLogger = FakeLogger { (logLevel, file, line, function, messageClosure) in
      XCTAssertEqual(logLevel, .debug)
      XCTAssertEqual(URL(fileURLWithPath: file.description).lastPathComponent, "LoggerTests.swift")
      XCTAssertEqual(function, "testDefaultDebugImplementation()")
      XCTAssertEqual(messageClosure(), "debug message")
      XCTAssertEqual(line, actualLine)
      e.fulfill()
    }

    fakeLogger.debug("debug message")
    wait(for: [e], timeout: 1)
  }

  /// Tests the default `Logger.info()` method implementation on the `Logger` protocol.
  func testDefaultInfoImplementation() {
    let e = expectation(description: "Correct logger called")
    let actualLine = whoseLineIsThisAnyway() + 10
    let fakeLogger = FakeLogger { (logLevel, file, line, function, messageClosure) in
      XCTAssertEqual(logLevel, .info)
      XCTAssertEqual(URL(fileURLWithPath: file.description).lastPathComponent, "LoggerTests.swift")
      XCTAssertEqual(function, "testDefaultInfoImplementation()")
      XCTAssertEqual(messageClosure(), "info message")
      XCTAssertEqual(line, actualLine)
      e.fulfill()
    }

    fakeLogger.info("info message")
    wait(for: [e], timeout: 1)
  }

  /// Tests the default `Logger.warning()` method implementation on the `Logger` protocol.
  func testDefaultWarningImplementation() {
    let e = expectation(description: "Correct logger called")
    let actualLine = whoseLineIsThisAnyway() + 10
    let fakeLogger = FakeLogger { (logLevel, file, line, function, messageClosure) in
      XCTAssertEqual(logLevel, .warning)
      XCTAssertEqual(URL(fileURLWithPath: file.description).lastPathComponent, "LoggerTests.swift")
      XCTAssertEqual(function, "testDefaultWarningImplementation()")
      XCTAssertEqual(messageClosure(), "warning message")
      XCTAssertEqual(line, actualLine)
      e.fulfill()
    }

    fakeLogger.warning("warning message")
    wait(for: [e], timeout: 1)
  }

  /// Tests the default `Logger.error()` method implementation on the `Logger` protocol.
  func testDefaultErrorImplementation() {
    let e = expectation(description: "Correct logger called")
    let actualLine = whoseLineIsThisAnyway() + 10
    let fakeLogger = FakeLogger { (logLevel, file, line, function, messageClosure) in
      XCTAssertEqual(logLevel, .error)
      XCTAssertEqual(URL(fileURLWithPath: file.description).lastPathComponent, "LoggerTests.swift")
      XCTAssertEqual(function, "testDefaultErrorImplementation()")
      XCTAssertEqual(messageClosure(), "error message")
      XCTAssertEqual(line, actualLine)
      e.fulfill()
    }

    fakeLogger.error("error message")
    wait(for: [e], timeout: 1)
  }

  /// Tests the default `Logger.assert()` method implementation on the `Logger` protocol.
  ///
  /// Note that the fake logger doesn't actually assert since it's not possible to catch Swift assertions.
  func testDefaultAssertImplementation() {
    let e = expectation(description: "Correct logger called")
    let actualLine = whoseLineIsThisAnyway() + 10
    let fakeLogger = FakeLogger { (logLevel, file, line, function, messageClosure) in
      XCTAssertEqual(logLevel, .assertion)
      XCTAssertEqual(URL(fileURLWithPath: file.description).lastPathComponent, "LoggerTests.swift")
      XCTAssertEqual(function, "testDefaultAssertImplementation()")
      XCTAssertEqual(messageClosure(), "assertion message")
      XCTAssertEqual(line, actualLine)
      e.fulfill()
    }

    fakeLogger.assert("assertion message")
    wait(for: [e], timeout: 1)
  }
}
