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
public enum LogLevel: String, CaseIterable {
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
    file: StaticString,
    line: UInt,
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
  func debug(file: StaticString, function: String, line: UInt, _ message: @autoclosure () -> String)

  /// Logs a message with level `LogLevel.info`.
  ///
  /// Implementations must be thread-safe.
  ///
  /// - Parameters:
  ///   - file: The file where the log message comes from.
  ///   - line: The line where the log message comes from.
  ///   - function: The function where the log message comes from.
  ///   - message: the message to display. It is an autoclosure so that if that log level is filtered the code will not be evaluated.
  func info(file: StaticString, function: String, line: UInt, _ message: @autoclosure () -> String)

  /// Logs a message with level `LogLevel.warning`.
  ///
  /// Implementations must be thread-safe.
  ///
  /// - Parameters:
  ///   - file: The file where the log message comes from.
  ///   - line: The line where the log message comes from.
  ///   - function: The function where the log message comes from.
  ///   - message: the message to display. It is an autoclosure so that if that log level is filtered the code will not be evaluated.
  func warning(
    file: StaticString, function: String, line: UInt, _ message: @autoclosure () -> String)

  /// Logs a message with level `LogLevel.error`.
  ///
  /// Implementations must be thread-safe.
  ///
  /// - Parameters:
  ///   - file: The file where the log message comes from.
  ///   - line: The line where the log message comes from.
  ///   - function: The function where the log message comes from.
  ///   - message: the message to display. It is an autoclosure so that if that log level is filtered the code will not be evaluated.
  func error(file: StaticString, function: String, line: UInt, _ message: @autoclosure () -> String)

  /// Raise an assertion with a message.
  ///
  /// Implementations must be thread-safe.
  ///
  /// - Parameters:
  ///   - file: The file where the log message comes from.
  ///   - line: The line where the log message comes from.
  ///   - function: The function where the log message comes from.
  ///   - message: the message to display. It is an autoclosure so that if that log level is filtered the code will not be evaluated.
  func assert(
    file: StaticString, function: String, line: UInt, _ message: @autoclosure () -> String)

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
    file: StaticString,
    function: String,
    line: UInt,
    _ message: @autoclosure () -> String
  )
}

/// Default `Logger` implementation that prints messages to the console.
public class PrintLogger: Logger {

  private enum LogSettings {
    static let numberOfBackup = 5
  }

  private var fileHandle: FileHandle?
  private var logURL = URL(fileURLWithPath: "~/jacquardSDK.0.log")

  private let dateFormatter: DateFormatter = {
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZZZZZ"  // ISO8601 format
    dateFormatter.locale = Locale(identifier: "en_US_POSIX")
    dateFormatter.timeZone = TimeZone.current
    return dateFormatter
  }()

  private let rootDirectory: URL? = {
    do {
      guard let docDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).last
      else {
        assertionFailure("documentDirectory not found")
        return nil
      }
      let rootDirectoryPath = docDir.appendingPathComponent("Logs")
      if !FileManager.default.fileExists(atPath: rootDirectoryPath.absoluteString) {
        try FileManager.default.createDirectory(
          at: rootDirectoryPath,
          withIntermediateDirectories: true,
          attributes: [FileAttributeKey.protectionKey: FileProtectionType.none]
        )
      }
      return rootDirectoryPath
    } catch {
      assertionFailure("Failed to create 'Logs` directory: \(error)")
      return nil
    }
  }()

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
  public init(logLevels: [LogLevel], includeSourceDetails: Bool, includeFileLogs: Bool = false) {
    self.logLevels = logLevels
    self.includeSourceDetails = includeSourceDetails
    if includeFileLogs {
      openFileHandle()
    }
  }

  private func openFileHandle() {
    let fileManager = FileManager.default
    guard let rootDirectory = rootDirectory else {
      Swift.assertionFailure("Root directory not found.")
      return
    }
    var isDir: ObjCBool = false
    var exist = fileManager.fileExists(atPath: rootDirectory.path, isDirectory: &isDir)
    if exist && !isDir.boolValue {
      do {
        try fileManager.removeItem(at: rootDirectory)
        exist = false
      } catch {
        print(error)
        Swift.assertionFailure("Could not remove \(rootDirectory)")
        return
      }
    }
    let attributes = [FileAttributeKey.protectionKey: FileProtectionType.none]
    if !exist {
      do {
        try fileManager.createDirectory(
          at: rootDirectory, withIntermediateDirectories: true, attributes: attributes)
      } catch {
        print(error)
        Swift.assertionFailure("Could not create and set \(rootDirectory)")
        return
      }
    }

    let newURL = rootDirectory.appendingPathComponent("jacquardSDK")
    logURL = newURL.appendingPathExtension("0.log")

    // Log file size in MB.
    var fileSize = 0.0
    do {
      let currentFileAttribute = try fileManager.attributesOfItem(atPath: logURL.path)
      if let size = currentFileAttribute[FileAttributeKey.size] as? NSNumber {
        fileSize = size.doubleValue
      }
    } catch {
      print("Error while getting log file size: \(error).")
    }

    let fileExists = fileManager.fileExists(atPath: logURL.path)

    if !fileExists || fileSize > 0 {
      let removedURL = newURL.appendingPathExtension("\(LogSettings.numberOfBackup).log")
      do {
        try fileManager.removeItem(at: removedURL)
      } catch {
        print("Error \(error) while removing log file at \(removedURL).")
      }
      for i in (0..<LogSettings.numberOfBackup).reversed() {
        let backupURL = newURL.appendingPathExtension("\(i+1).log")
        let fromURL = newURL.appendingPathExtension("\(i).log")
        do {
          try fileManager.moveItem(at: fromURL, to: backupURL)
          print("Move \(fromURL.path) to \(backupURL.path)")
        } catch {
          print("Error while moving \(fromURL.path) to \(backupURL.path).")
        }
      }

      guard
        fileManager.createFile(
          atPath: logURL.path,
          contents: Data(),
          attributes: [FileAttributeKey.protectionKey: FileProtectionType.completeUnlessOpen]
        )
      else {
        Swift.assertionFailure("Failed to create log file")
        return
      }
    }

    do {
      var resourceValues = URLResourceValues()
      resourceValues.isExcludedFromBackup = true
      try logURL.setResourceValues(resourceValues)
    } catch {
      Swift.assertionFailure("Failed to set log file exclusion from backup")
      return
    }

    guard let fileHandle = FileHandle(forWritingAtPath: logURL.path) else {
      Swift.assertionFailure("Failed to open log file for writing")
      return
    }
    self.fileHandle = fileHandle
    fileHandle.seekToEndOfFile()
  }

  deinit {
    print("Syncing and Closing File")
    fileHandle?.synchronizeFile()
    fileHandle?.closeFile()
  }

  private func logWithTimeStamp(_ message: String) {
    let now = Date()
    let decoratedMessage = "\(dateFormatter.string(from: now)): \(message)\n"

    guard let fileHandle = self.fileHandle else {
      print("Could not find fileHandle to log.")
      return
    }
    fileHandle.write(decoratedMessage.data(using: .utf8) ?? Data())
  }

  /// Logs a message
  ///
  /// - SeeAlso: `Logger.log(level:message:)`
  public func log(
    level: LogLevel,
    file: StaticString,
    line: UInt,
    function: String,
    message: () -> String
  ) {
    guard logLevels.contains(level) || level == .assertion || level == .preconditionFailure else {
      // Return early to avoid overhead of evaluating message.
      return
    }
    var sourceDetails = ""
    if includeSourceDetails {
      let filename = URL(fileURLWithPath: file.description).lastPathComponent
      sourceDetails = " [\(filename)@\(line);\(function)]"
    }

    let fullMessage = "[\(Date())][\(level.rawValue)]\(sourceDetails) \(message())"

    if level == .assertion {
      assertionFailure(fullMessage, file: file, line: line)
    }
    if level == .preconditionFailure {
      preconditionFailure(fullMessage, file: file, line: line)
    }
    if logLevels.contains(level) {
      print(fullMessage)
      if fileHandle != nil {
        logWithTimeStamp(fullMessage)
      }
    }
  }
}

extension Logger {
  /// Logs a message with level `LogLevel.debug`.
  public func debug(
    file: StaticString = #file, function: String = #function, line: UInt = #line,
    _ message: @autoclosure () -> String
  ) {
    log(level: .debug, file: file, line: line, function: function, message: message)
  }

  /// Logs a message with level `LogLevel.info()`.
  public func info(
    file: StaticString = #file, function: String = #function, line: UInt = #line,
    _ message: @autoclosure () -> String
  ) {
    log(level: .info, file: file, line: line, function: function, message: message)
  }

  /// Logs a message with level `LogLevel.warning`.
  public func warning(
    file: StaticString = #file, function: String = #function, line: UInt = #line,
    _ message: @autoclosure () -> String
  ) {
    log(level: .warning, file: file, line: line, function: function, message: message)
  }

  /// Logs a message with level `LogLevel.error`.
  public func error(
    file: StaticString = #file, function: String = #function, line: UInt = #line,
    _ message: @autoclosure () -> String
  ) {
    log(level: .error, file: file, line: line, function: function, message: message)
  }

  /// Raise an assertion.
  public func assert(
    file: StaticString = #file, function: String = #function, line: UInt = #line,
    _ message: @autoclosure () -> String
  ) {
    log(level: .assertion, file: file, line: line, function: function, message: message)
  }

  public func preconditionAssertFailure(
    file: StaticString = #file, function: String = #function, line: UInt = #line,
    _ message: @autoclosure () -> String
  ) {
    log(level: .preconditionFailure, file: file, line: line, function: function, message: message)
  }
}
