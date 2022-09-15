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

import Combine
import Foundation

enum FirmwareImageWriterError: Swift.Error {
  case crcMismatch
  case internalError
  case dataCorruption
}

class FirmwareImageWriterStateMachine {

  static let initialState: State = .idle

  /// The max payload size for each write request.
  static let imageChunkSize = 128

  private let stateSubject = CurrentValueSubject<State, Never>(
    FirmwareImageWriterStateMachine.initialState)

  lazy var statePublisher: AnyPublisher<State, Never> = stateSubject.eraseToAnyPublisher()

  private var marshalQueue: DispatchQueue
  private var context: Context
  private var observations = [Cancellable]()

  private var state: State = FirmwareImageWriterStateMachine.initialState {
    didSet {
      stateSubject.send(state)
    }
  }

  /// Total bytes written by the writer.
  var totalBytesWritten: Int { context.totalBytesWritten }

  enum State {
    case idle
    case checkingStatus
    case preparingForWrite
    // The associated value with the writing state indicates written bytes so far.
    case writing(Int)
    case complete
    case error(Error)
    case stopped
    var isTerminal: Bool {
      switch self {
      case .complete, .error, .stopped: return true
      default: return false
      }
    }
  }

  private enum Event {
    case checkStatus
    case imagePartiallyWritten
    case imageCompletelyWritten
    case didReceiveStatusCheckError(Error)
    case prepareForWriting
    case didReceivePrepareError(Error)
    case startWriting
    case didReceiveWriteError(Error)
    case stopWriting
  }

  private struct Context {
    /// The firmware image to be written onto the device.
    let image: Data

    /// The `ConnectedTag` onto which the image has to be written.
    let tag: ConnectedTag

    /// The current image write progress.
    var totalBytesWritten = 0

    /// Vendor ID of the component for which the image has to be written.
    let vendorID: String

    /// Product ID of the component for which the image has to be written.
    let productID: String

    /// ID of the component for which the image has to be written.
    let componentID: ComponentID

    /// CRC of firmware image data.
    let imageCrc: UInt16
  }

  private enum WriteStatus: String {
    case finished
    case partial
    case reset
  }

  required init(
    image: Data,
    tag: ConnectedTag,
    vendorID: String,
    productID: String,
    componentID: ComponentID
  ) {
    self.marshalQueue = DispatchQueue(label: "FirmwareImageWriterStateMachine marshaling queue")
    self.context = Context(
      image: image,
      tag: tag,
      vendorID: vendorID,
      productID: productID,
      componentID: componentID,
      imageCrc: CRC16.compute(in: image, seed: 0)
    )
  }
}

//MARK: - External event methods.

extension FirmwareImageWriterStateMachine {

  /// Starts the write process if the state of the writer is valid (`idle`).
  func startWriting() {
    marshalQueue.async {
      self.handleEvent(.checkStatus)
    }
  }

  /// Stops the writing process and sets state to `stopped`.
  func stopWriting() throws {
    switch state {
    case .preparingForWrite, .writing(_):
      marshalQueue.async {
        self.handleEvent(.stopWriting)
      }
    default:
      jqLogger.error("Invalid state `\(state)` to stop writing.")
      throw FirmwareImageWriterError.internalError
    }
  }
}

//MARK: - Internal event methods & helpers.

extension FirmwareImageWriterStateMachine {

  /// Queries the device for the current image write status and moves the state accordingly.
  private func checkStatus() {

    let dfuStatusRequest = DFUStatusCommand(
      vendorID: ComponentImplementation.convertToDecimal(self.context.vendorID),
      productID: ComponentImplementation.convertToDecimal(self.context.productID)
    )
    context.tag.enqueue(dfuStatusRequest).sink { [weak self] completion in
      guard let self = self else {
        return
      }
      switch completion {
      case .finished:
        break
      case .failure(let error):
        self.marshalQueue.async {
          jqLogger.error("Error: \(error) during status request.")
          self.handleEvent(.didReceiveStatusCheckError(error))
        }
      }
    } receiveValue: { [weak self] (response) in
      guard let self = self else {
        return
      }
      self.marshalQueue.async {
        self.processStatusResponse(response: response)
      }
    }.addTo(&observations)
  }

  /// Extracts information from the status response to check where the update is currently at.
  /// That is, the upgrade could be resumed, the file could already be written or there could be
  /// an error that requires the upgrade to restart from the beginning.
  ///
  /// - Parameter response: The response packet obtained after querying the device.
  private func processStatusResponse(response: Google_Jacquard_Protocol_DFUStatusResponse) {
    var status = WriteStatus.reset
    if context.image.count == response.finalSize && context.imageCrc == response.finalCrc {
      context.totalBytesWritten = Int(response.currentSize)
      let crcCheck = currentCRC() == response.currentCrc
      if !crcCheck {
        status = .reset
      } else if context.totalBytesWritten == context.image.count {
        status = .finished
      } else {
        status = .partial
      }
    }

    jqLogger.debug("Status response: \(status)")
    switch status {
    case .reset:
      handleEvent(.prepareForWriting)

    case .finished:
      handleEvent(.imageCompletelyWritten)

    case .partial:
      handleEvent(.imagePartiallyWritten)
    }
  }

  /// First step that asks the Tag to erase its cache and prepare for an incoming image.
  private func prepareForWriting() {

    let dfuPrepareRequest = DFUPrepareCommand(
      vendorID: ComponentImplementation.convertToDecimal(self.context.vendorID),
      productID: ComponentImplementation.convertToDecimal(self.context.productID),
      componentID: self.context.componentID,
      finalCrc: UInt32(self.context.imageCrc),
      finalSize: UInt32(self.context.image.count)
    )
    context.tag.enqueue(dfuPrepareRequest).sink { [weak self] completion in
      guard let self = self else {
        return
      }
      switch completion {
      case .finished:
        break
      case .failure(let error):
        self.marshalQueue.async {
          jqLogger.error("Error \(self.state) preparing for image transfer.")
          self.handleEvent(.didReceivePrepareError(error))
        }
      }
    } receiveValue: { [weak self] in
      guard let self = self else {
        return
      }
      self.marshalQueue.async {
        jqLogger.info(
          "Prepare response OK; starting transfer for \(self.context.vendorID)-\(self.context.productID)"
        )
        self.handleEvent(.startWriting)
      }
    }.addTo(&observations)
  }

  /// Sends the 'next' slice of data from the image being transferred.
  private func sendPacket() {

    let packet = imagePacket()
    jqLogger.debug("Sending packet: \(packet)")

    let dfuWriteRequest = DFUWriteCommand(
      data: packet,
      offset: UInt32(self.context.totalBytesWritten)
    )
    context.tag.enqueue(dfuWriteRequest).sink { [weak self] completion in
      guard let self = self else {
        return
      }
      switch completion {
      case .finished:
        break
      case .failure(let error):
        self.marshalQueue.async {
          self.processWriteResponse(result: .failure(error))
        }
      }
    } receiveValue: { [weak self] response in
      guard let self = self else {
        return
      }
      self.marshalQueue.async {
        self.processWriteResponse(result: .success(response))
      }
    }.addTo(&observations)
  }

  private func processWriteResponse(
    result: Result<Google_Jacquard_Protocol_DFUWriteResponse, Error>
  ) {
    switch result {
    case .success(let response):
      context.totalBytesWritten = Int(response.offset)
      jqLogger.debug("bytes written: \(context.totalBytesWritten)/ \(context.image.count)")

      if context.totalBytesWritten < context.image.count {
        jqLogger.debug("Current crc \(currentCRC()) vs \(response.crc)")
        if UInt32(currentCRC()) != response.crc {
          jqLogger.error("CRC mismatch at offset \(context.totalBytesWritten)")
          handleEvent(.didReceiveWriteError(FirmwareImageWriterError.crcMismatch))
          return
        }
        handleEvent(.imagePartiallyWritten)
      } else if context.totalBytesWritten == context.image.count {
        handleEvent(.imageCompletelyWritten)
      } else {
        handleEvent(.didReceiveWriteError(FirmwareImageWriterError.dataCorruption))
      }

    case .failure(let error):
      jqLogger.error("Write error: \(error) during image transfer.")
      handleEvent(.didReceiveWriteError(error))
    }
  }

  /// Grabs the next slice of the image in transfer, up to the chunk size (128).
  ///
  /// - Returns: The packet of Data to be transferred.
  private func imagePacket() -> Data {
    let upperLimit = min(
      (context.totalBytesWritten + FirmwareImageWriterStateMachine.imageChunkSize),
      context.image.count
    )
    return context.image.subdata(in: context.totalBytesWritten..<upperLimit)
  }

  /// Returns the CRC for the image in transfer, from 0 to however many bytes have been sent.
  ///
  /// - Returns: The CRC16 check for the subdata being written.
  private func currentCRC() -> UInt16 {
    let dataSent = context.image.subdata(in: 0..<context.totalBytesWritten)
    return CRC16.compute(in: dataSent, seed: 0)
  }

}

//MARK: - Transitions.

extension FirmwareImageWriterStateMachine {
  /// Examines events and current state to apply transitions.
  private func handleEvent(_ event: Event) {
    dispatchPrecondition(condition: .onQueue(marshalQueue))

    if state.isTerminal {
      jqLogger.info("State machine is already terminal, ignoring event: \(event)")
    }

    jqLogger.debug("Entering \(self).handleEvent(\(state), \(event)")

    switch (state, event) {

    // (t1)
    case (.idle, .checkStatus):
      state = .checkingStatus
      checkStatus()

    // (t2)
    case (.checkingStatus, .prepareForWriting):
      state = .preparingForWrite
      prepareForWriting()

    // (t3)
    case (.checkingStatus, .imagePartiallyWritten):
      state = .writing(context.totalBytesWritten)
      sendPacket()

    // (t4)
    case (.checkingStatus, .imageCompletelyWritten):
      state = .complete

    // (e5)
    case (.checkingStatus, .didReceiveStatusCheckError(let error)):
      state = .error(error)

    // (t6)
    case (.preparingForWrite, .startWriting):
      state = .writing(context.totalBytesWritten)
      self.sendPacket()

    // (e7)
    case (.preparingForWrite, .didReceivePrepareError(let error)):
      state = .error(error)

    // (t8)
    case (.writing(_), .imagePartiallyWritten):
      state = .writing(context.totalBytesWritten)
      sendPacket()

    // (t9)
    case (.writing(_), .imageCompletelyWritten):
      state = .complete

    // (e10)
    case (.writing(_), .didReceiveWriteError(let error)):
      state = .error(error)

    // (t15)
    case (.preparingForWrite, .stopWriting),
      (.writing(_), .stopWriting):
      state = .stopped

    // No valid transition found.
    default:
      jqLogger.error("No transition found for (\(state), \(event))")
      state = .error(FirmwareImageWriterError.internalError)
    }

    if state.isTerminal {
      observations.removeAll()
    }

    jqLogger.debug("Exiting \(self).handleEvent() new state: \(state)")
  }
}

//MARK: - Dot Statechart

// Note that the order is important - the transition events/guards will be evaluated in order and
// only the first matching transition will have effect.

//digraph G {
//
//    "start" -> "idle"
//
//    "idle" -> "checkingStatus"
//    [label = "(t1)
//              checkStatus
//              / checkStatus()"];
//
//    "checkingStatus" -> "preparingForWrite"
//    [label = "(t2)
//              prepareForWriting
//              / prepareForWriting()"];
//
//    "checkingStatus" -> "writing"
//    [label = "(t3)
//              imagePartiallyWritten
//              / sendPacket()"];
//
//    "checkingStatus" -> "complete"
//    [label = "(t4)
//              imageCompletelyWritten"];
//
//    "checkingStatus" -> "error"
//    [label = "(e5)
//              didReceiveStatusCheckError(error)"];
//
//    "preparingForWrite" -> "writing"
//    [label = "(t6)
//              startWriting
//              / sendPacket()"];
//
//    "preparingForWrite" -> "error"
//    [label = "(e7)
//              didReceivePrepareError(error)"];
//
//    "writing" -> "writing"
//    [label = "(t8)
//              imagePartiallyWritten
//              / sendPacket()"];
//
//    "writing" -> "complete"
//    [label = "(t9)
//              imageCompletelyWritten"];
//
//    "writing" -> "error"
//    [label = "(e10)
//              didReceiveWriteError(error)"];
//
//    "preparingForWrite" -> "stopped"
//    [label = "(t11)
//              stopWriting"];
//
//    "writing" -> "stopped"
//    [label = "(t12)
//              stopWriting"];
//
//    "complete" -> "end"
//    "stopped" -> "end"
//
//    error [color=red style=filled]
//    start [shape=diamond]
//    end [shape=diamond]
//}
