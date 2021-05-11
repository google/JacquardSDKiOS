Commands are how your app asks the Jacquard Tag to do something. Using them is straightforward:

1. Construct an instance of the relevant request type. Some will require arguments (like `PlayLEDPatternCommand`), others will not (like `BatteryStatusCommand`).
2. Enqueue the request to be sent to a tag using `ConnectedTag.enqueue(_:)` or `ConnectedTag.enqueue(_:retries:)`.
3. Observe the Combine publisher returned by one of the enqueue methods for a result or error (the request types declare an
   associated result type, which is the type published). Once a result is received, no more values will be published.

For example, to measure the battery status of the connected tag, assuming a published
stream of the currently connected tag (see example code in [Connecting to Tags](Connecting to Tags.html)).

```swift
    // Observe future battery status notifications.
    let subscription = BatteryStatusNotificationSubscription()
    let cancellable = tagStream
      .prefix(1)
      .flatMap { $0.subscribe(subscription) }
      .sink { [weak self] response in
        guard let self = self else { return }
        switch response.chargingState {
        case .notCharging:
          print("not charging")
        case .charging:
          print("charging")
        }
        print("battery charge: \(response.batteryLevel)%")
      }
```

When sending comands or observing events, you should always check if the component supports that `Component.capability`
You can check the capabilities on a component using e.g `component.capabilities.contains(.haptic)` 
The supported capabilties are :-
1. `case led // = 0 `Gear can be used for `PlayLEDPatternCommand`.
2. `case gesture // = 1 `Gear supports gestures. i.e`TouchMode.gesture` 
3. `case touchDataStream // = 2 `Gear supports touch data stream. i.e `TouchMode.touchDataStream` 
4. `case haptic // = 3 `Gear can be used for `PlayHapticCommand`.

```swift
  tagPublisher
    .flatMap { $0.connectedGear }
    .sink { [weak self] gear in
      guard let self = self else { return }
      // Check if Component has supported capability to execute the co.mand. 
      guard let gear = gear, gear.capabilities.contains(.led) else {
        return
      }
    }.addTo(&observers)
  }
```
