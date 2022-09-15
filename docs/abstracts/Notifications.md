Notifications are how your app can observe messages sent by the Jacquard tag. Using Notifications is straightforward:

1. Construct an instance of the relevant subscription type (none require arguments).
2. Using the `ConnectedTag.subscribe(_:)` method on the current connected tag, construct a Combine publisher which
   can be used to observe notifications (which are published using the associated result type declared by the
   subscription type).

For example, to observe gesture notifications, assuming a published
stream of the currently connected tag (see example code in [Connecting to Tags](Connecting to Tags.html)).

```swift
    // Observe gestures (these will not be delivered when in touchDataStream mode).
    let gestureSubscription = GestureNotificationSubscription()
    let cancellable = tagStream
      .flatMap { $0.subscribe(gestureSubscription) }
      .sink { [weak self] gesture in
        guard let self = self else { return }

        print("received gesture: \(gesture)")
        switch gesture.touchMode {
        case .brushUp, .brushIn:
          print("increase something")

        case .brushDown, .brushOut:
          print("decrease something")

        default:
          print("rest easy")
        }
      }
```
