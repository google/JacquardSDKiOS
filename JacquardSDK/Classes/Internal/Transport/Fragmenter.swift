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

struct Fragmenter {

  enum Constants {
    static let maximumPacketLength = 1024
    static let firstFragmentFlag: UInt8 = 0x80
    static let lastFragmentFlag: UInt8 = 0x40
  }

  let maximumFragmentLength: Int

  private var incomingData: Data
  private var fragmentCounter: UInt8 = 0
  private var dataLength: Int = 0

  init(mtu: Int) {
    maximumFragmentLength = mtu - 3  // 1 byte opcode, 2 bytes att handle
    incomingData = Data(capacity: maximumFragmentLength)
  }

  /// Adds the given fragment to the internal state. If the fragment completes a packet, the packet
  /// is returned.
  /// - Parameter fragment: small chunks of a packet receiving over the transmission channel.
  /// - Returns: Packet once the last fragment is received.
  mutating func packet(fromAddedFragment fragment: Data) -> Data? {
    let firstByte = fragment[0]
    var byteStartIndex = 1
    var counter: UInt8 = 0

    // MSB indicates first-packet
    if firstByte & Constants.firstFragmentFlag != 0 {
      if incomingData.count != 0 {
        jqLogger.debug(
          "Remaining fragments did not arrive for a packet, reseting to receive new packet.")
        reset()
      }

      fragmentCounter = (firstByte & 0x3F) + 1

      let (bytesRead, length) = Varint.decode(data: Data(fragment[1...]))
      dataLength = length
      byteStartIndex = 1 + bytesRead
    } else {
      counter = firstByte & 0x3F
      if (counter != 0) && (counter != fragmentCounter) {
        jqLogger.error(
          """
          Incoming message data error! Counter received is \(counter) \
          but we expected \(fragmentCounter)
          """
        )
        reset()
        return nil
      }
      fragmentCounter = counter + 1
    }

    incomingData.append(Data(fragment[byteStartIndex...]))

    // Next-to-MSB indicates last-packet
    if firstByte & Constants.lastFragmentFlag != 0 {
      if incomingData.count != dataLength {
        jqLogger.error(
          """
          Incoming message data error! Expected \(dataLength) bytes \
          but received \(incomingData.count) bytes
          """
        )
        reset()
        return nil
      }

      let packet = incomingData
      reset()
      return packet
    }

    return nil
  }

  /// Splits a single whole packet into fragments for transmission.
  func fragments(fromPacket packet: Data) -> [Data] {
    if packet.count > Constants.maximumPacketLength {
      jqLogger.assert(
        """
        Fragmentation error: Can't send packet of \(packet.count) bytes it's more than \
        the maximum of 1024 bytes
        """
      )
      return [Data]()
    }

    let encodedPacketLength = Varint.encode(value: packet.count)
    var counter: UInt8 = 0
    var remainingData = packet
    var fragments = [Data]()

    while remainingData.count != 0 {
      var firstByte = counter
      var fragment = Data(capacity: maximumFragmentLength)

      let maxLength: Int
      if counter == 0 {
        firstByte = firstByte | Constants.firstFragmentFlag
        maxLength = maximumFragmentLength - 1 - encodedPacketLength.count
      } else {
        maxLength = maximumFragmentLength - 1  // 1 byte fragment header
      }

      if remainingData.count <= maxLength {
        firstByte = firstByte | Constants.lastFragmentFlag
      }

      fragment.append(firstByte)

      if counter == 0 {
        fragment.append(encodedPacketLength)
      }

      let dataBlock = Data(remainingData[0..<min(Int(maxLength), remainingData.count)])
      fragment.append(dataBlock)

      if dataBlock.count != remainingData.count {
        remainingData = Data(remainingData[dataBlock.count..<remainingData.count])
      } else {
        remainingData = Data()
      }

      fragments.append(fragment)
      counter += 1
    }

    return fragments
  }

  mutating func reset() {
    incomingData.count = 0
    fragmentCounter = 0
    dataLength = 0
  }
}
