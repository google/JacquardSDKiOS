# Motion Capture

UJT contains an Inertial Measurement Unit (IMU) sensor that consists of an accelerometer and gyroscope. With this feature, you can record, view and download your tag's IMU sensor data. Accelerometer data consits of a vector  (x, y, z) data, and Gyroscope has vector  (yaw, pitch, roll) data.

This section will guide you to record, download, parse, erase IMU session. If you want the tag should collect IMU samples, loadable module must be activated. Note that activating IMU Module, will disable Wake on Motion(WoM) on the tag and you will also notice the tag battery draining considerably quickly.

#### 1. Instantiate
You can create instance of `ImuModule` using `ConnectedJacquardTag` as below -

```swift
    let imuModule = IMUModuleImplementation(connectedTag: tag)
```

#### 2. Initialize
This is a mandatory step before you start recording IMU samples. There are multiple steps performed during initialize process.
Calling Initialize for the first time will load the Data Collection Loadable module(DCLM) on the device.
This process will be similar to Firmware Updating and will only be done once. `ImuModule` will perform device firmware update(DFU) to download DCLM binary from cloud and send it to the tag. Once DFU is successful, `ImuModule` will activate the DCLM to finish initialize process.

 ```swift
 imuModule.initialize().sink { result in
   switch result {
   case .failure(let error):
     print("IMU initialize error: \(error)")
   case .finished:
     break
   }
 } receiveValue: {
   print("IMU initialized")
   // After initialize, it's good practice to call `imuModule.checkStatus()`, to see if Tag is ready to record.
 }
 ```

#### 3. Start & stop IMU recording.
You can start collecting IMU samples by calling ```imuModule.startRecording(sessionID:)``` api.
Provide a unique SessionID, less than 30 characters. It is a good practice to simply pass in the timestamp so that the SessionID is unique.
Similarly Call ```imuModule.stopRecording()``` to end current IMU session.

```swift
imuModule.startRecording(sessionID: timestamp)
  .sink { result in
    switch result {
    case .failure(let error):
      print("Could not start IMUSession: \(error)")
    case .finished:
      break
    }
  } receiveValue: { status in
    switch status {
    case .logging:
      // Indicates the recording has started.
    case .lowBattery:
    // Indicates the tag battery is not enough to start recording. Minimum battery should be 50%.
    case .lowMemory:
    // Indicates the tag storage is not enough to start recording.
    default:
      break
    }
  }
```

> Note: An important point to remember here is that - you should not attach/detach the tag from gear during IMU session.
> Which means - while starting a new IMU session whichever is the gear state, either attached or detached, must be same till you call `stopImuSession()`
api.

#### 4. Fetch IMU session list

Calling this api will return each session individually, receiveValue for the publisher will be called everytime a session is received.
```swift
// Call listSessions api and sink immediately on the returned publisher to observe IMUSessions.
imuModule.listSessions().sink { result in
  switch result {
  case .failure(let error):
    print("List Sessions error: \(error)")
  case .finished:
    break
  }
} receiveValue: { [weak self] sessionInfo in
  // Hold the sessionInfo objects.
  guard let self = self else { return }
  self.imuSessions.append(session)
}
```

#### 5. Download IMU session

Calling listSessions() only fetches the metadata for the recorded sessions on the tag,
Once the metadata is fetched, you can download the actual session file, using below code.

The apis gives you download progress and file path where IMU session data will be saved. As tag has
limited storage, to free up the space, The Jacquard SDK will erase the session file from Tag once download is complete.
It is highly recommended to move the file to another directory for further use. If there is an active IMU session on the tag, you can't call
this api. To cancel ongoing download, you can simply call `imuModule.stopDownloading()`.

```swift
imuModule.downloadIMUSessionData(session: session)
  .sink { completion in
    switch completion {
    case .finished:
      print("IMU file downloaded.")
    case .failure(let error):
      print("failed to download IMU file: \(error)")
    }
  } receiveValue: { [weak self] downloadState in
    guard let self = self else { return }
    switch downloadState {
    case .downloading(let progress):
      print("IMU downloading... \(progress)%")
    case .downloaded(let filePath):
      print("IMU state downloaded IMU file \(filePath)")
      // Copy file locally to another folder.
      }
    @unknown default:
      preconditionFailure("switch case not implemented.")
    }
  }
```


#### 6. Erase IMU session(s)
You can either choose to delete a specific IMU session or all sessions from the tag.

```swift
imuModule.eraseSession(session: sessionInfo)
```

OR
```swift
imuModule.eraseAllSessions()
```

#### 7. Parse IMU session data
Once you download the IMU session to the mobile device, You can view the IMU samples by parsing the session file. You can pass the downloaded session file path to below api to parse IMU session. It will return an `IMUSessionData` object that will contain the vector data for accelerometer and gyroscope.

```swift
imuModule.parseIMUSession(path: filePath)
```

#### 8. Get Data Collection status
To know the current data collection status of the tag, use below code -
```swift
imuModule.checkStatus()
```

The different states a tag could be in, are specified below.
```
enum DataCollectionStatus {
  /// No logging in progress.
  case idle
  /// Session recording in progress.
  case logging
  /// Session data transfer in progress.
  case dataTransferInProgress
  /// Erasing session data in progress.
  case erasingData
  /// Not sufficient storage to start logging.
  case lowMemory
  /// Not sufficient battery to start logging. Minimum battery should be 50%.
  case lowBattery
  /// Error state.
  case error
}
```
If ```DataCollectionStatus``` is ```.idle``` means the tag is ready to record new sessions.

#### 9. Deactivate Data Collection Loadable Module
When you no longer require `IMUModule`, it is advisable to deactivate the data collection module to save the tag battery.

```swift
imuModule.deactivateModule()
```
