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

import Starling

enum Note: String {
  case b2 = "B2"
  case b3 = "B3"
  case b4 = "B4"
  case d3 = "D3"
  case d4 = "D4"
  case g2 = "G2"
  case g3 = "G3"
  case g4 = "G4"
}

class NoteHelper {
  private let starling = Starling()
  private var currentlyPlaying: [Int] = []

  /// 12 notes played in the following sequence:
  ///   G2 G3  B2 B3  D3 D4  G3 G4  D4 D4  G4 G4
  private let lookupTable: [Note] = [
    .g2, .g3, .b2, .b3, .d3, .d4, .g3, .g4, .d4, .d4, .g4, .g4,
  ]

  private enum Constants {
    static let velocityThreshold = 15
  }

  init() {
    for note in lookupTable {
      starling.load(resource: note.rawValue, type: "mp3", for: note.rawValue)
    }
  }

  private func lookUp(item: Int) -> String {
    precondition(item >= 0 && item < lookupTable.count)
    return lookupTable[item].rawValue
  }

  public func playLine(_ line: Int, _ velocity: UInt8) {
    if currentlyPlaying.contains(line) {
      onPlaying(line, velocity)
    } else {
      onNotPlaying(line, velocity)
    }
  }

  // The note it currently playing.
  private func onPlaying(_ line: Int, _ velocity: UInt8) {
    if velocity > 0 {
      return
    }
    if let index = currentlyPlaying.firstIndex(of: line) {
      currentlyPlaying.remove(at: index)
    }
  }

  // The note is not currently playing
  private func onNotPlaying(_ line: Int, _ velocity: UInt8) {
    if velocity < Constants.velocityThreshold {
      // The note's velocity is below threshold. Ignore.
      return
    }
    if !currentlyPlaying.contains(line) {
      currentlyPlaying.append(line)
      let itemToPlay = lookUp(item: line)
      starling.play(itemToPlay, allowOverlap: true)
    }
  }
}
