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
import JacquardSDK

struct KnownTag: Codable {
  var identifier: UUID
  var name: String

  init(_ tag: JacquardTag) {
    self.identifier = tag.identifier
    self.name = tag.displayName
  }
}

extension KnownTag: JacquardTag {
  var displayName: String { name }
}

class Preferences {
  private static var knownTagsKey = "KnownTags"

  class var knownTags: [KnownTag] {
    set {
      guard let json = try? JSONEncoder().encode(newValue) else {
        return
      }
      UserDefaults.standard.setValue(json, forKey: knownTagsKey)
    }
    get {
      guard let data = UserDefaults.standard.data(forKey: knownTagsKey),
        let knownTags = try? JSONDecoder().decode([KnownTag].self, from: data)
      else {
        return []
      }
      return knownTags
    }
  }

  class func addKnownTag(_ tag: JacquardTag) {
    let existingTags = knownTags.filter { $0.identifier != tag.identifier }
    knownTags = [KnownTag(tag)] + existingTags
  }

  class func removeKnownTag(_ identifier: UUID) {
    knownTags = knownTags.filter { $0.identifier != identifier }
  }
}
