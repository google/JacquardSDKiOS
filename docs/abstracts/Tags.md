![Jacquard Tag](https://kstatic.googleusercontent.com/files/1754f79cd1b759a1052d7a68c0713c1a629a7c2ae35d34a4c3e0dabc7f24f7e8c266bcff6c72b7f9eb86b00d132d81d495179e1106df0067152831c3746ac8c0)

The core of all Jacquard products is the [Jacquard tag](https://atap.google.com/jacquard/technology/). The Jacquard tag connects via Bluetooth Low Energy and contains
a range of sensors and sophisticated machine learning capabilities.

Once your app has connected to a Jacquard Tag it can listen to notifications from the tag about
[gear attachments](Components%20and%20Gear.html), [gestures](Notifications.html), send
[commands](Commands.html) to light up the LED, etc.


## Types

### Jacquard Tag Types
![Jacquard Tag Types](assets/tagTypes.png)


### JacquardTag Protocol

The `JacquardTag` is the Base protocol which all other tag types inherit from.

![Jacquard Tag Protocol](assets/jacquardTagProtocol.png)
The jacquard tag has 2 properties.
1. `identifier`: Unique identify of the peripheral instance in the current running app on the current iOS device. (peripheral uuid)
2. `displayName`: A human readable string describing the tag.

> Note: The displayName value may change over time, eg. when CoreBluetooth updates the name for a connected tag.

To distingush between a tag which is already known, and an unknown tag. There are 2 protocols, that inherit from the `JacquardTag`, they are
`ConnectedTag` and `ConnectableTag`. 
In the spirit of making invalid state unrepresentable a Jacquard Tag will always be a represented by only one of these Protocols.

### ConnectableTagProtocol
Tags which are not yet known to the app can further be divided into two types `AdvertisedTag` and` PreConnectedTag`

![Connectable Tag Protocol](assets/connectableTagProtocol.png)

`AdvertisedTag` are tags which are not yet paired to the iOS mobile device, these tags will not be visible in the iOS Bluetooth settings screen.
`AdvertisedTag` exposes a short pairing identification you can display to the user (which matches the serial number printed on the tag), can be used
for pairing and nothing else. 

`PreConnectedTag` are tags which are already paired to the iOS mobile device but not yet connected to the app.
These tags if in range should be visible in the iOS Bluetooth settings screen. Similar to AdvertisedTag `PreConnectedTag` also exposes an `identifier` which is used for connecting.

There are 2 API's which can be used to connect to a tag, 
1.  `sharedJacquardManager.connect(_ tag: ConnectableTag) `
2.  `sharedJacquardManager.connect(_ identifier: UUID)`

During initial scan and pairing, you can use the `sharedJacquardManager.connect(tag)` api to initiate pairing/connection to these tags. 

For re-connection your app must store the peripheral identifier, and use `sharedJacquardManager.connect(identifier)` api to reconnect.

After a successful connection, your code will get access to a `ConnectedTag` instance, which will remain valid until you are notified of disconnection.

```swift
let connectionStream = sharedJacquardManager.connect(connectableTag)
connectionStream
  .sink { [weak self] error in
    // Connection attempts never time out,
    // so an error will be received only when the connection cannot be recovered or retried.
  } receiveValue: { [weak self] connectionState in

    switch connectionState {
    case .connected(let connectedTag):
      // Tag is successfully paired, you can now subscribe and retrieve the tag stream.
  }
  .addTo(&cancellables)
```

### ConnectedTagProtocol
Represents Tags which are fully paired and connected to the app. 

![Connected Tag Protocol](assets/connectedTagProtocol.png)

Once you have obtained a `ConnectedTag` instance from the connect publisher you can use it to send Commands and subscribe to Notifications. Some commands work with just a connection to the Tag, others require Jacquard garment or gear attached - the attachment state can also be observed via the `ConnectedTag`.
> see all available api details at  `ConnectedTag`


