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

@testable import JacquardSDK

class FragmenterTests: XCTestCase {

  struct CatchLogger: Logger {
    func log(level: LogLevel, file: String, line: Int, function: String, message: () -> String) {
      expectation.fulfill()
    }

    var expectation: XCTestExpectation
  }

  private let mtu = ProtocolSpec.version2.mtu

  private var singlePacket: Data {
    // Max length in single packet. MTU subtracted by 1 byte opcode, 2 bytes att handle,
    // 1 byte Fragment header 1 byte packet length
    let packetLength = mtu - 5  // 58
    return Data((1...packetLength).map { UInt8($0 % 255) })
  }

  private var invalidFragment: Data {
    let packetLength = mtu - 3  // 58
    var fragment = Data(capacity: 1024)
    fragment.append(0x40)  // First Byte
    let encodedPacketLength = Varint.encode(value: packetLength)
    fragment.append(encodedPacketLength)
    fragment.append(Data((1...packetLength).map { UInt8($0 % 255) }))
    return fragment
  }

  override func setUp() {
    super.setUp()

    let logger = PrintLogger(
      logLevels: [.debug, .info, .warning, .error, .assertion],
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

  func testOversizedPacket() {
    let oversizePacketExpectation = expectation(description: "oversizePacket")
    jqLogger = CatchLogger(expectation: oversizePacketExpectation)

    let packetLength = 1025
    let overSizedPacket = Data((1...packetLength).map { UInt8($0 % 255) })
    let fragmenter = Fragmenter(mtu: mtu)
    let fragments = fragmenter.fragments(fromPacket: overSizedPacket)
    XCTAssertEqual(fragments.count, 0, "Incorrect number of fragments")

    wait(for: [oversizePacketExpectation], timeout: 1.0)
  }

  /// Tests packet assembley from  Invalid fragment should always return nil
  func testInValidPacketAssembling() {
    let packetLength = mtu - 3  // 58
    var fragment = Data(capacity: 1024)
    fragment.append(0x3F)  // First Byte
    let encodedPacketLength = Varint.encode(value: packetLength)
    fragment.append(encodedPacketLength)
    fragment.append(Data((1...packetLength).map { UInt8($0 % 255) }))

    var fragmenter = Fragmenter(mtu: mtu)
    let packet = fragmenter.packet(fromAddedFragment: fragment)
    XCTAssertNil(packet, "Unable to crate packet from garbageFrament")

    let packet1 = fragmenter.packet(fromAddedFragment: invalidFragment)
    XCTAssertNil(packet1, "Unable to crate packet from garbageFrament")
  }

  /// Create single packet from test fragment
  func testSingleFragmentAssembling() {
    var fragmenter = Fragmenter(mtu: mtu)
    let fragments = fragmenter.fragments(fromPacket: singlePacket)
    let packet = fragmenter.packet(fromAddedFragment: fragments[0])
    XCTAssertNotNil(packet, "Assembled packet should not be nil")
    XCTAssertEqual(singlePacket, packet, "Invalid packet")
  }

  /// Create fragments from single test packet
  func testSinglePacketFragmenting() {

    let fragments = Fragmenter(mtu: mtu).fragments(fromPacket: singlePacket)
    let packetLength = mtu - 5

    XCTAssertEqual(fragments.count, 1, "Incorrect number of fragments")
    XCTAssertLessThan(
      fragments[0].count,
      1024,
      "Can't send packet of \(singlePacket.count) bytes it's more than the maximum of 1024 bytes")
    XCTAssertEqual(fragments[0].count, packetLength + 2, "Incorrect length of fragment 0")
    XCTAssertEqual(fragments[0][0], 0xc0, "Incorrect header of fragment 0")  // 192 0xC0
    XCTAssertEqual(fragments[0][1], UInt8(packetLength), "Incorrect packet length")
    XCTAssertEqual(fragments[0][2...], singlePacket[0...], "Incorrect payload of fragment 0")
  }

  func testMultiFragmentAssembling(packetLength: Int) {
    let fragmentSize = mtu - 3
    let maxPayloadSize = fragmentSize - 1

    XCTAssertGreaterThan(packetLength, maxPayloadSize, "Packet fit in a single fragment")

    var fragmenter = Fragmenter(mtu: mtu)

    let packet = Data((1...packetLength).map { UInt8($0 % 256) })

    let fragments = fragmenter.fragments(fromPacket: packet)

    var newPacket: Data? = nil
    fragments.forEach {
      if let packet = fragmenter.packet(fromAddedFragment: $0) {
        newPacket = packet
      }
    }
    XCTAssertEqual(newPacket, packet, "Invalid packet")
  }

  func testMultiPacketFragmenting(packetLength: Int) {
    let fragmentSize = mtu - 3
    let maxPayloadSize = fragmentSize - 1

    XCTAssertGreaterThan(packetLength, maxPayloadSize, "Packet fit in a single fragment")

    let fragmenter = Fragmenter(mtu: mtu)
    let encodedLength = Varint.encode(value: packetLength)
    let packet = Data((1...packetLength).map { UInt8($0 % 256) })
    let encodedPacket = encodedLength + packet

    let lastIndex =
      encodedPacket.count / maxPayloadSize - (encodedPacket.count % maxPayloadSize == 0 ? 1 : 0)

    let fragments = fragmenter.fragments(fromPacket: packet)
    XCTAssertEqual(fragments.count, lastIndex + 1, "Incorrect number of fragments")

    XCTAssertEqual(fragments[0][0] & 0x80, 0x80, "Incorrect header of fragment 0")
    XCTAssertEqual(
      fragments[lastIndex][0] & 0x40, 0x40, "Incorrect header of fragment \(lastIndex)")
    fragments.enumerated().forEach {
      XCTAssertEqual($1[0] & 0x3F, UInt8($0), "Incorrect sequence for fragment \(lastIndex)")
    }

    let payloads = fragments.map { $0[1...] }
    let splitedPackets = stride(from: 0, to: encodedPacket.count, by: maxPayloadSize).map {
      encodedPacket[$0..<min($0 + maxPayloadSize, encodedPacket.count)]
    }
    XCTAssertEqual(payloads, splitedPackets, "Incorrect payload")
  }

  func testTwoFragmentPacket() {
    let packetLength = (mtu - 5) * 2
    testMultiPacketFragmenting(packetLength: packetLength)
    testMultiFragmentAssembling(packetLength: packetLength)
  }

  func testWithSmallerPacketSize() {
    testMultiPacketFragmenting(packetLength: 61)
    testMultiFragmentAssembling(packetLength: 61)
  }

  func testWithMediumPacketSize() {
    testMultiPacketFragmenting(packetLength: 555)
    testMultiFragmentAssembling(packetLength: 555)
  }

  func testWithMaximumPacketSize() {
    testMultiPacketFragmenting(packetLength: 1024)
    testMultiFragmentAssembling(packetLength: 1024)
  }
}
