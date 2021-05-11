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
import Foundation
import SwiftProtobuf

enum IMUParsingError: Swift.Error {
  case fileCouldNotBeOpened
  case couldNotParseData
  case couldNotMatchStartMarker
  case unexpectedEndOfStream
}

// Parses the IMU Session raw data file.
//
// Binary format description: go/jacquard-dc-framework#heading=h.lgt57q4p2c8c
struct IMUParser {
  typealias DataCollectionMetadata = Google_Jacquard_Protocol_DataCollectionMetadata
  typealias ImuConfiguration = Google_Jacquard_Protocol_ImuConfiguration

  let stream: InputStream
  let metadata: DataCollectionMetadata
  let configuration: ImuConfiguration

  private let sampleLength = 16
  private let actionIDLength = 4

  private static var startMarkerPrefix: [UInt8] =
    [0xfe, 0xca, 0xfe, 0xca, 0xfe, 0xca, 0xfe, 0xca, 0xfe, 0xca, 0xfe, 0xca]

  private static var endMarkerPrefix: [UInt8] =
    [0xad, 0xde, 0xad, 0xde, 0xad, 0xde, 0xad, 0xde, 0xad, 0xde, 0xad, 0xde, 0xad, 0xde]

  init(_ stream: InputStream) throws {
    self.stream = stream

    // Open the receiving stream. Parsing cannot begin unless stream is opened.
    stream.open()

    // This assumes all required data is available to be read immediately, which is true for a file,
    // not necessarily true if you tried to parse directly from the BLE stream or an http stream.
    // Solving this would require an enhancement to SwiftProtobuf.
    self.metadata =
      try BinaryDelimited.parse(messageType: DataCollectionMetadata.self, from: stream)
    self.configuration = try BinaryDelimited.parse(messageType: ImuConfiguration.self, from: stream)
  }

  // Creates the IMUSamples in memory and returns when end marker is reached,
  // or no unread bytes are remaining.
  func readAction() throws -> (completedSuccessfully: Bool, samples: [IMUSample])? {
    // Close the stream after parsing is complete.
    defer { stream.close() }

    if !stream.hasBytesAvailable {
      return nil
    }

    // Read the start marker, result is actionID which can be ignored as its currently not needed.
    let _ = try readStartMarker()

    var samples = [IMUSample]()

    while stream.hasBytesAvailable {
      let readBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: sampleLength)
      defer { readBuffer.deallocate() }
      guard stream.read(readBuffer, maxLength: sampleLength) == sampleLength else {
        // Couldn't read any more samples, but also found no valid end marker.
        return (false, samples)
      }

      if let ended = try readEndMarker(buffer: readBuffer) {
        // End marker found, return parsed samples.
        return (ended, samples)
      }

      let sample = try IMUSample(buffer: readBuffer)
      samples.append(sample)
    }

    throw IMUParsingError.unexpectedEndOfStream
  }

  private func readStartMarker() throws -> UInt32 {
    // Assumed the offset is at a start marker.
    let length = IMUParser.startMarkerPrefix.count + actionIDLength
    let readBuffer =
      UnsafeMutablePointer<UInt8>.allocate(capacity: IMUParser.startMarkerPrefix.count)

    defer { readBuffer.deallocate() }

    // Match start marker.
    guard stream.read(readBuffer, maxLength: length) == length else {
      throw IMUParsingError.unexpectedEndOfStream
    }
    let matchArray =
      Array(UnsafeBufferPointer(start: readBuffer, count: IMUParser.startMarkerPrefix.count))
    guard matchArray == IMUParser.startMarkerPrefix else {
      throw IMUParsingError.couldNotMatchStartMarker
    }

    // Read Action ID.
    guard stream.read(readBuffer, maxLength: length) == length else {
      throw IMUParsingError.unexpectedEndOfStream
    }
    return readBuffer.withMemoryRebound(to: UInt32.self, capacity: 1) { ptr in
      ptr.pointee
    }
  }

  // If the end marker is at the current offset, returns a bool which indicates if the action was
  // performed successfully or not.
  // This is sent to the UJT by the mobile app as part of the DataCollectionStopRequest.
  // If the current offset is not at an end marker, returns nil.
  private func readEndMarker(buffer: UnsafeMutablePointer<UInt8>) throws -> Bool? {

    let matchArray =
      Array(UnsafeBufferPointer(start: buffer, count: IMUParser.endMarkerPrefix.count))
    if matchArray != IMUParser.endMarkerPrefix {
      return nil
    }

    let resultBuffer = buffer.advanced(by: IMUParser.endMarkerPrefix.count)

    // Little endian 16 bit, so we can just bind it (since every Swift supported CPU is little endian).
    return resultBuffer.withMemoryRebound(to: UInt16.self, capacity: 1) { ptr in
      ptr.pointee > 0
    }
  }

}
