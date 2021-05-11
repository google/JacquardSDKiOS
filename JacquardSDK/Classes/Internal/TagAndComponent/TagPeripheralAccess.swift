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

/// Access to the peripheral in the Tag types is via this internal protocol.
///
/// This unfortunately requires the occasional optional cast, but avoids exposing the CBPeripheral as a public var
/// in the JacquardTag protocol.
protocol TagPeripheralAccess {
  var peripheral: Peripheral { get }
}
