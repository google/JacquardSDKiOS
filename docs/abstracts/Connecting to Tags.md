![Image showing location of micro USB, LED and button on Jacquard Tag](https://lh3.googleusercontent.com/qo9tyWdqWNIB_1y2YDUIAUmSiY9I9qietKl4S2x1jOdZCOcNyoWreUCwpy6_eg1zzg=w900)

The `JacquardManager` protocol describes the API you will use to find
and pair with Jacquard Tags. For most general useage, your app should
ideally create and hold only a single instance of `JacquardManager`
using `JacquardManagerImplementation(publishQueue:, options:)`, both
parameters optional. (Note: `publishQueue` defaults to `.main` and
`options` defaults to an empty dictionary, you can omit the parameters
when calling the function).

# Before connecting

Once you have a `JacquardManager` instance, it is important to make
sure Bluetooth is powered on and ready before accessing any Bluetooth
features such as scanning or connecting. These events are published by
`JacquardManager.centralState`, wait for the `.poweredOn` state before
proceeding.

> Note that even after `.poweredOn` has been published, the user may
> turn off Bluetooth, de-authorize Bluetooth for your app, or a random
> error may occur. This will cause `JacquardManager.centralState` to
> leave the `.poweredOn` state. At this point all connections will
> become invalid and you must again wait for the `.poweredOn` state.

Once `JacquardManager.centralState` has published the `.poweredOn`
state, you then need either a CoreBluetooth identifier (UUID) or an
instance of one of the `ConnectableTag` types.

If you have persisted a UUID (ie. from a tag you have seen before and
wish to connect to again), use `JacquardManager.connect(_ uuid:)`.

Otherwise you have two ways to get one of the `ConnectableTag` instances:

1. Start scanning for advertising tags with `JacquardManager.startScanning()`,
1. and then observe the `JacquardManager.advertisingTags` publisher,
1. which will publish `AdvertisedTag` instances.

or

1. You can retrieve a list of tags which are both paired and connected to iOS already by calling `JacquardManager.preConnectedTags()`,
1. this will return an array of `PreConnectedTag` instances.

2. This command returns a `connectionState` publisher.
3. Subscribe to this publisher, if you want to track the state changes of the connection process.

# Connected Tag Lifecycle and Automatic Reconnection

# Initiating a connection

Armed with either a UUID or a `ConnectableTag` instance, you can call
`JacquardManager.connect(_:)` to obtain a Combine publisher which will
publish the change in connection state over time.

## Connection States

The value type published by the publisher returned by `JacquardManager.connect(_:)` is `TagConnectionState`:


```swift
/// The states published by the tag connection publisher.
public enum TagConnectionState {
  /// This is initial state, and also the state while waiting for reconnection.
  ///
  /// To conserve battery if the Jacqaurd tag is kept idle for 10 Minutes it will drop BLE connection.
  /// This state is also transitioned when the tag is moves out of the Bluetooth range of the mobile device.
  case preparingToConnect
  /// Connecting with approximate progress.
  ///
  /// First Int is the current step, second Int is total number of steps (including initializing)
  case connecting(Int, Int)
  /// Initializing with approximate progress.
  ///
  /// First Int is the current step, second Int is total number of steps. This continues on from the progress reported by the
  /// `connecting` state.
  case initializing(Int, Int)
  /// Configuring with approximate progress.
  ///
  /// First Int is the current step, second Int is total number of steps. This continues on from the progress reported by the
  /// `initializing` state.
  case configuring(Int, Int)
  /// Note this is not a terminal state - the stream may bo back to disconnected, and then subsequently reconnect again.
  case connected(ConnectedTag)
  /// This terminal state will only be reached if reconnecting or retrying is not possible.
  case disconnected(Error?)
}
```

When the tag is fully connected and ready, the state published will be
`.connected()`, with the `ConnectedTag` instance as the associated
value.

## Automatic Reconnection

Jacquard manager automatically manges re-connection for you, so in
cases of BLE disconnect for expected events such as going out of
range, the tag going into sleep mode or the tag battery going flat.

In any of these events, the `TagConnectionState` will transition from
`'connected` state to `.preparingToConnect`. Once the tag comes back
into range or wakes up etc., the published state will again cycle
through the `.connecting`, `.initializing` and `.configuring` states
and finally publish the `.connectected` state with the associated
`ConnectedTag` instance.

The use of Combine streams make it easy to do this. For example, see
the code snippet below. First it saves a publisher as an instance
variable which allows easy access to the latest `ConnectedTag`
instance. Second it checks the battery level every time the tag
connects or reconnects.


```swift
private let connectionStream: AnyPublisher<JacquardConnectionState, Never>
/// Convenience stream that only contains the tag.
private let tagStream: AnyPublisher<ConnectedTag, Never>
/// A shared JacquardManager Instance
private let sharedJacquardManager: JacquardManagerImplementation

connectionStream = sharedJacquardManager.connect(tag)

tagStream = connectionStream
    .compactMap { state -> ConnectedTag? in
      switch state {
      case .connected(let tag): return tag
      default: return nil
      }
    }
  .eraseToAnyPublisher()

// Fetch battery status every time the tag connects.
let batteryRequest = BatteryStatusCommand()
let cancellable = tagStream
  .mapNeverToError()
  .flatMap { $0.enqueue(batteryRequest) }
  .sink { completion in
    switch completion {
    case .failure(let error):
      print("Error reading battery status: \(error)")
    case .finished:
      break
    }
  } receiveValue: { [weak self] response in
    guard let self = self else { return }
    self.updateBatteryStatus(response)
  }
```

## Reading the Current Connection State

The publisher returned by `JacquardManager.connect(_)` will always
publish the current state (which includes the current `ConnectedTag`
instance in the case of `.connected`) when any new subscription is
made.[^1]

[^1]: Currently this property is due to the underlying subject being
    `CurrentValueSubject`, but even if this implementation changes the
    api contract will remain that the current state will always be
    published first.

### Every reconnection creates a new `ConnectedTag` instance

Every reconnection creates a new `ConnectedTag` instance. This means
that it is important not to keep a long-term reference to any
`ConnectedTag` instance - instead use the publisher (or a derivative)
each time you wish to access a tag.

You can see demonstrations of this in the [tutorial](tutorial.html),
throughout the sample code in the documentation, or in the [sample
app](https://github.com/google/JacquardSDKiOS).

> Note: In case that Bluetooth is turned off by the user or an
> unexpected error occurs, the `.disconnected(Error)` state will be
> published. This state is terminal and no more messages will be
> published.
>
> Your app code is responsible to observe the
> `JacquardManager.centralState` publisher for CoreBluetooth
> `.poweredOn` events and initiate a new connection as above.

## State Preservation and Restoration

CoreBluetooth State Restoration will relaunch your app in the
background for pending Core Bluetooth requests. To learn more about
State Preservation and Restoration, refer to these two Apple
documents:

* [Core Bluetooth Programming Guide (Background Processing for iOS
  Apps)](https://developer.apple.com/library/archive/documentation/NetworkingInternetWeb/Conceptual/CoreBluetooth_concepts/CoreBluetoothBackgroundProcessingForIOSApps/PerformingTasksWhileYourAppIsInTheBackground.html)
* [Technical Q&A QA1962 - Conditions Under Which Bluetooth State
  Restoration Will Relaunch An
  App](https://developer.apple.com/library/archive/qa/qa1962/_index.html)

### Adding Support for State Preservation and Restoration

State preservation and restoration using Jacquard manager is an opt-in
feature and requires you to provide a unique restoration identifier
when you allocate and initialize the Jacquard manager.

```swift
let options = [CBCentralManagerOptionRestoreIdentifierKey: "YourAppRestoreIdentifier"]
aJacquardManager = JacquardManagerImplementation(options: options)
```

See the Apple documentation for other valid [Central Manager
Initialization
options](https://developer.apple.com/documentation/corebluetooth/cbcentralmanager/central_manager_initialization_options).

