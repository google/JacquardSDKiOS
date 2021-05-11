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

import CoreBluetooth

struct AdvertisedTagModel: AdvertisedTag, TagPeripheralAccess {
  var pairingSerialNumber: String
  var rssi: Float
  var peripheral: Peripheral
  var identifier: UUID {
    return peripheral.identifier
  }

  init?(peripheral: Peripheral, advertisementData: [String: Any], rssi rssiValue: Float) {
    guard let pairingSerialNumber = AdvertisedTagModel.decodeSerialNumber(advertisementData) else {
      return nil
    }
    self.peripheral = peripheral
    self.pairingSerialNumber = pairingSerialNumber
    self.rssi = rssiValue
  }
}

// MARK: Serial number decoding

extension AdvertisedTagModel {
  private static func decodeSerialNumber(_ advertisementData: [String: Any]) -> String? {
    guard let manufacturerData = advertisementData[CBAdvertisementDataManufacturerDataKey] as? Data
    else {
      return nil
    }

    // New style, it's all serial number all the time, but 6-bit encoding
    // First two bytes are the MFG 0xE000 followed by the 6bit encoded ascii string
    let sixBitData = manufacturerData.subdata(in: 2..<manufacturerData.count)
    return decodeSerialNumber(sixBitData)
  }

  /// Decode a 6bit encoded serial number.
  private static func decodeSerialNumber(_ data: Data) -> String {
    // SERIAL NUMBER DECODING
    //
    // The serial number is encoded using a 6-bit encoding:
    // '0'-'9' = 0-9
    // 'A'-'Z' = 10-35
    // 'a'-'z' = 36-61
    // '-'     = 62
    // (end)   = 63
    //
    // Example encoding of "0GWPw9eQus":
    // "0" =  0 = b'000000'
    // "G" = 16 = b'010000'
    // "W" = 32 = b'100000'
    // "P" = 25 = b'011001'
    // "w" = 58 = b'111010'
    // "9" =  9 = b'001001'
    // "e" = 40 = b'101000'
    // "Q" = 26 = b'011010'
    // "u" = 56 = b'111000'
    // "s" = 54 = b'110110'
    //
    // The bits are then packed into bytes 8 bits at a time.  So the first byte has all 6
    // bits of the first character (LSB aligned), plus the least significant 2 bits of the
    // next character.  The second byte has the remaining 4 bits of the 2nd character plus
    // the least significant 4 bits of the next.

    // Get the raw bytes as type safe UInt8 array
    let bytes = [UInt8](data)

    let nbytes = data.count

    var accumulator: UInt32 = 0  // Accumulator to aggregate multiple bytes' worth of bits.
    var bitsLeft = 0  // How many bits of valid data are in the LSB of the accumulator.
    var bytesUsed = 0  // How many bytes from the input data have been shifted into
    // the accumulator.

    let nchars = nbytes * 8 / 6  // It's a 6-bit encoding, so this is how many
    // output characters are encoded

    var decodedSerialNumber = String()

    for _ in 0..<nchars {
      //Check if we need to load more bits into the accumulator
      if bitsLeft < 6 {
        if bytesUsed == nbytes {  // Used all the bytes from the input! Finished!
          break
        }
        //Load the next byte in, shifted to the left to avoid bits already in the accumulator
        accumulator += UInt32(bytes[bytesUsed]) << bitsLeft
        bytesUsed += 1  //Mark one more byte used
        bitsLeft += 8  //Mark 8 bits available
      }
      // 0b00111111 = 0x3F
      // Take the lowest 6 bits of the accumulator
      var sixBitCode: UInt8 = UInt8(accumulator & 0x3F)

      //Decode the encoded character into [0-9A-Za-z-]
      if sixBitCode <= 9 {
        sixBitCode += 48
      }  // 0
      else if sixBitCode <= 35 {
        sixBitCode += 65 - 10
      }  // A
      else if sixBitCode <= 61 {
        sixBitCode += 97 - 36
      }  // a
      else if sixBitCode == 62 {
        sixBitCode = 45
      }  // -
      else if sixBitCode == 63 {
        break
      }  //End-of-string character
      else {
        continue
      }  //Invalid characters are skipped

      accumulator >>= 6  //Chop the bits out of the accumulator
      bitsLeft -= 6  //Mark those bits as used

      //Add it to the output string
      decodedSerialNumber.append(String(UnicodeScalar(sixBitCode)))
    }
    return decodedSerialNumber
  }

}
