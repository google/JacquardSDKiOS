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

extension TouchData {
  init?(_ touchData: Google_Jacquard_Protocol_TouchData) {
    // diffDataScaled has 13 (8 bit)values. 1st represents the proximity and remaining 12
    // represent touch data for the threads.
    guard touchData.diffDataScaled.count == 13 else {
      assertionFailure("invalid Google_Jacquard_Protocol_TouchData: \(touchData)")
      return nil
    }

    self.sequence = touchData.sequence
    self.proximity = UInt32(touchData.diffDataScaled[0])
    let d = touchData.diffDataScaled
    self.lines = (d[1], d[2], d[3], d[4], d[5], d[6], d[7], d[8], d[9], d[10], d[11], d[12])
  }
}

extension ContinuousTouchNotificationSubscription {
  /// :nodoc:
  public func extract(from outerProto: Any) -> TouchData? {
    guard let notification = outerProto as? Google_Jacquard_Protocol_Notification else {
      jqLogger.assert(
        "calling extract() with anything other than Google_Jacquard_Protocol_Notification is an error"
      )
      return nil
    }

    // Silently ignore other notifications.
    guard notification.hasGoogle_Jacquard_Protocol_DataChannelNotification_data,
      notification.Google_Jacquard_Protocol_DataChannelNotification_data.hasTouchData
    else {
      return nil
    }

    return TouchData(notification.Google_Jacquard_Protocol_DataChannelNotification_data.touchData)
  }
}
