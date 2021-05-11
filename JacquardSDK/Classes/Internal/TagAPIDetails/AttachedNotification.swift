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

struct AttachedNotificationSubscription: NotificationSubscription {
  func extract(from outerProto: Any) -> ComponentImplementation?? {
    guard let notification = outerProto as? Google_Jacquard_Protocol_Notification else {
      jqLogger.assert(
        "calling extract() with anything other than Google_Jacquard_Protocol_Notification is an error"
      )
      return nil
    }

    // Silently ignore other notifications.
    guard notification.hasGoogle_Jacquard_Protocol_AttachedNotification_attached
    else {
      return nil
    }

    let innerProto = notification.Google_Jacquard_Protocol_AttachedNotification_attached
    return ComponentImplementation(innerProto)
  }

  typealias Notification = ComponentImplementation?
}
