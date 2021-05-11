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

/// Sets the global `Logger` instance used by all code in Jacquard SDK.
///
/// You do not need to set this - the default logger prints log messages to the console using `print()`, ignoring `LogLevel.debug`
/// messages and does not print source details (ie. file, line, function). You can set a new instance of `PrintLogger` with the
/// levels you desire, or you may implement your own custom `Logger` type.
///
/// - Important: This var is accessed from multiple threads and is not protected with a lock. You can alter this *only* prior
///              to accessing any Jacquard SDK APIs for the first time in your code.
///
/// - Parameter logger: new `Logger` instance.
public func setGlobalJacquardSDKLogger(_ logger: Logger) {
  jqLogger = logger
}

func createDefaultLogger() -> Logger {
  PrintLogger(
    logLevels: [.info, .warning, .error, .assertion, .preconditionFailure],
    includeSourceDetails: false
  )
}

var jqLogger: Logger = createDefaultLogger()

/// Describes different types of log messages which can be used to filter which messages are collected.
public enum LogLevel: String {
  /// Filter debug log messages.
  case debug = "DEBUG"

  /// Filter info log messages.
  case info = "INFO"

  /// Filter warning log messages.
  case warning = "WARNING"

  /// Filter error log messages.
  case error = "ERROR"

  /// Filter assertion log messages.
  case assertion = "ASSERTION"

  /// Filter precondition failure log messages.
  case preconditionFailure = "PRECONDITIONFAILURE"
}

/// Describes the type you must implement if you wish to provide your own logging implementation.
///
/// The only required function to implement is `Logger.log(level:message:)` as the rest have default implementations.
///
/// - SeeAlso: `jqLogger`
public protocol Logger {
  /// Logs a message.
  ///
  /// Implementations must be thread-safe.
  ///
  /// - Parameters:
  ///   - level: Describes the level/type of the message.
  ///   - file: The file where the log message comes from.
  ///   - line: The line where the log message comes from.
  ///   - function: The function where the log message comes from.
  ///   - message: A closure which returns the message to display.
  func log(
    level: LogLevel,
    file: String,
    line: Int,
    function: String,
    message: () -> String
  )

  /// Logs a message with level `LogLevel.debug`.
  ///
  /// Implementations must be thread-safe.
  ///
  /// - Parameters:
  ///   - file: The file where the log message comes from.
  ///   - line: The line where the log message comes from.
  ///   - function: The function where the log message comes from.
  ///   - message: the message to display. It is an autoclosure so that if that log level is filtered the code will not be evaluated.
  func debug(file: String, function: String, line: Int, _ message: @autoclosure () -> String)

  /// Logs a message with level `LogLevel.info`.
  ///
  /// Implementations must be thread-safe.
  ///
  /// - Parameters:
  ///   - file: The file where the log message comes from.
  ///   - line: The line where the log message comes from.
  ///   - function: The function where the log message comes from.
  ///   - message: the message to display. It is an autoclosure so that if that log level is filtered the code will not be evaluated.
  func info(file: String, function: String, line: Int, _ message: @autoclosure () -> String)

  /// Logs a message with level `LogLevel.warning`.
  ///
  /// Implementations must be thread-safe.
  ///
  /// - Parameters:
  ///   - file: The file where the log message comes from.
  ///   - line: The line where the log message comes from.
  ///   - function: The function where the log message comes from.
  ///   - message: the message to display. It is an autoclosure so that if that log level is filtered the code will not be evaluated.
  func warning(file: String, function: String, line: Int, _ message: @autoclosure () -> String)

  /// Logs a message with level `LogLevel.error`.
  ///
  /// Implementations must be thread-safe.
  ///
  /// - Parameters:
  ///   - file: The file where the log message comes from.
  ///   - line: The line where the log message comes from.
  ///   - function: The function where the log message comes from.
  ///   - message: the message to display. It is an autoclosure so that if that log level is filtered the code will not be evaluated.
  func error(file: String, function: String, line: Int, _ message: @autoclosure () -> String)

  /// Raise an assertion with a message.
  ///
  /// Implementations must be thread-safe.
  ///
  /// - Parameters:
  ///   - file: The file where the log message comes from.
  ///   - line: The line where the log message comes from.
  ///   - function: The function where the log message comes from.
  ///   - message: the message to display. It is an autoclosure so that if that log level is filtered the code will not be evaluated.
  func assert(file: String, function: String, line: Int, _ message: @autoclosure () -> String)

  /// Precondition failure with a message.
  ///
  /// Implementations must be thread-safe.
  ///
  /// - Parameters:
  ///   - file: The file where the log message comes from.
  ///   - line: The line where the log message comes from.
  ///   - function: The function where the log message comes from.
  ///   - message: the message to display. It is an autoclosure so that if that log level is filtered the code will not be evaluated.
  func preconditionAssertFailure(
    file: String,
    function: String,
    line: Int,
    _ message: @autoclosure () -> String
  )
}

/// Default `Logger` implementation that prints messages to the console.
public class PrintLogger: Logger {
  /// Which log levels should be displayed.
  let logLevels: [LogLevel]

  /// Whether source file, line and function information should be logged.
  let includeSourceDetails: Bool

  /// Creates a `PrintLogger` instance.
  ///
  /// Whether assertions are raised or not depends on the usual compiler flags. If compiler flags prevent assertions being raised, the
  /// assertion message will still be printed to the console based on the usual `logLevels` check.
  ///
  /// - Parameter logLevels: Which log levels should be displayed.
  public init(logLevels: [LogLevel], includeSourceDetails: Bool) {
    self.logLevels = logLevels
    self.includeSourceDetails = includeSourceDetails
  }

  /// Logs a message
  ///
  /// - SeeAlso: `Logger.log(level:message:)`
  public func log(
    level: LogLevel,
    file: String,
    line: Int,
    function: String,
    message: () -> String
  ) {
    guard logLevels.contains(level) || level == .assertion || level == .preconditionFailure else {
      // Return early to avoid overhead of evaluating message.
      return
    }

    var sourceDetails = ""
    if includeSourceDetails {
      let filename = URL(fileURLWithPath: file).lastPathComponent
      sourceDetails = " [\(filename)@\(line);\(function)]"
    }

    let fullMessage = "[\(level.rawValue)]\(sourceDetails) \(message())"

    if level == .assertion {
      assertionFailure(fullMessage)
    }
    if level == .preconditionFailure {
      preconditionFailure(fullMessage)
    }
    if logLevels.contains(level) {
      print(fullMessage)
    }
  }
}

extension Logger {
  /// Logs a message with level `LogLevel.debug`.
  public func debug(
    file: String = #file, function: String = #function, line: Int = #line,
    _ message: @autoclosure () -> String
  ) {
    log(level: .debug, file: file, line: line, function: function, message: message)
  }

  /// Logs a message with level `LogLevel.info()`.
  public func info(
    file: String = #file, function: String = #function, line: Int = #line,
    _ message: @autoclosure () -> String
  ) {
    log(level: .info, file: file, line: line, function: function, message: message)
  }

  /// Logs a message with level `LogLevel.warning`.
  public func warning(
    file: String = #file, function: String = #function, line: Int = #line,
    _ message: @autoclosure () -> String
  ) {
    log(level: .warning, file: file, line: line, function: function, message: message)
  }

  /// Logs a message with level `LogLevel.error`.
  public func error(
    file: String = #file, function: String = #function, line: Int = #line,
    _ message: @autoclosure () -> String
  ) {
    log(level: .error, file: file, line: line, function: function, message: message)
  }

  /// Raise an assertion.
  public func assert(
    file: String = #file, function: String = #function, line: Int = #line,
    _ message: @autoclosure () -> String
  ) {
    log(level: .assertion, file: file, line: line, function: function, message: message)
  }

  public func preconditionAssertFailure(
    file: String = #file, function: String = #function, line: Int = #line,
    _ message: @autoclosure () -> String
  ) {
    log(level: .preconditionFailure, file: file, line: line, function: function, message: message)
  }
}
