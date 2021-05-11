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

class ProtocolInitializationStateMachine {

  static let initialState: State = .paired
  // This will need to be refactored when we support > 1 protocol.
  static let supportedProtocol = ProtocolSpec.version2

  private let stateSubject = CurrentValueSubject<State, Never>(
    ProtocolInitializationStateMachine.initialState)

  lazy var statePublisher: AnyPublisher<State, Never> = stateSubject.eraseToAnyPublisher()

  private var marshalQueue: DispatchQueue
  private var context: Context

  private var observations = [Cancellable]()

  private var state: State = ProtocolInitializationStateMachine.initialState {
    didSet {
      stateSubject.send(state)
    }
  }

  enum State {
    case paired
    case helloSent
    case helloAcked
    case helloDidReceivePacket
    case beginSent
    case beginAcked
    case creatingTagInstance
    case tagInitialized(ConnectedTag)
    case error(Error)

    var isTerminal: Bool {
      switch self {
      case .tagInitialized, .error: return true
      default: return false
      }
    }
  }

  private enum Event {
    case startNegotiation
    case didWriteValue(Error?)
    case didReceiveResponse(Google_Jacquard_Protocol_Response)
    case didReceiveResponseError(Error)
    case validateHelloResponse(Google_Jacquard_Protocol_HelloResponse)
    case validateBeginResponse(Data)
    case createdConnectedTagInstance(ConnectedTag)
  }

  private struct Context {
    /// This state machine is the first time commands are sent, so we commence with fresh transport state.
    let transport: Transport
    /// We need to keep a reference to the requested user publish queue to create the ConnectedTag instance with.
    let userPublishQueue: DispatchQueue
    let characteristics: RequiredCharacteristics
  }

  init(
    peripheral: Peripheral,
    characteristics: RequiredCharacteristics,
    userPublishQueue: DispatchQueue
  ) {
    let transport = TransportV2Implementation(
      peripheral: peripheral, characteristics: characteristics)
    self.marshalQueue = DispatchQueue(label: "TagPairingStateMachine marshaling queue")
    self.context = Context(
      transport: transport, userPublishQueue: userPublishQueue, characteristics: characteristics)
  }
}

//MARK: - External event methods.

extension ProtocolInitializationStateMachine {

  func startNegotiation() {

    // Setup transport didWrite event observer.
    context.transport.didWriteCommandPublisher
      .buffer(size: Int.max, prefetch: .byRequest, whenFull: .dropOldest)
      .receive(on: marshalQueue)
      .sink { error in
        self.handleEvent(.didWriteValue(error))
      }.addTo(&observations)

    marshalQueue.async {
      self.handleEvent(.startNegotiation)
    }
  }
}

//MARK: - Internal event methods & helpers.
extension ProtocolInitializationStateMachine {

  private func handleResponseResult(_ responseResult: Transport.ResponseResult) {
    self.marshalQueue.async {
      switch responseResult {
      case .success(let packet):

        do {
          let response = try Google_Jacquard_Protocol_Response(
            serializedData: packet, extensions: Google_Jacquard_Protocol_Jacquard_Extensions)
          self.handleEvent(.didReceiveResponse(response))
        } catch (let error) {
          self.handleEvent(.didReceiveResponseError(error))
        }

      case .failure(let error):
        self.handleEvent(.didReceiveResponseError(error))
      }
    }
  }

  private func sendHello() throws {
    let helloRequest = Google_Jacquard_Protocol_Request.with {
      $0.domain = .base
      $0.opcode = .hello
    }

    context.transport.enqueue(
      request: helloRequest, type: .withResponse, retries: 2, callback: handleResponseResult)
  }

  private func sendBegin() throws {
    let beginRequest = Google_Jacquard_Protocol_Request.with {
      $0.domain = .base
      $0.opcode = .begin
      $0.Google_Jacquard_Protocol_BeginRequest_begin.protocol = ProtocolSpec.version2.rawValue
    }

    context.transport.enqueue(
      request: beginRequest, type: .withResponse, retries: 2, callback: handleResponseResult)
  }

  private func createConnectedTagInstance() {
    let connectedTag = ConnectedTagModel(
      transport: context.transport,
      userPublishQueue: context.userPublishQueue)

    marshalQueue.async {
      self.handleEvent(.createdConnectedTagInstance(connectedTag))
    }
  }
}

//MARK: - Transitions.

// Legend of comments that cross reference the Dot Statechart at the end of this file.
// (labels) cross reference individual transitions
// case where clauses represent [guard] statements
// / Actions are labelled with comments in the case bodies.

extension ProtocolInitializationStateMachine {
  /// Examines events and current state to apply transitions.
  private func handleEvent(_ event: Event) {
    dispatchPrecondition(condition: .onQueue(marshalQueue))

    if state.isTerminal {
      jqLogger.info("State machine is already terminal, ignoring event: \(event)")
    }

    jqLogger.debug("Entering \(self).handleEvent(\(state), \(event)")

    switch (state, event) {

    // (e1)
    case (_, .didWriteValue(let error)) where error != nil:
      state = .error(error!)

    // (e1)
    case (_, .didReceiveResponseError(let error)):
      state = .error(error)

    // (t3)
    case (.paired, .startNegotiation):
      do {
        try sendHello()
        state = .helloSent
      } catch (let error) {
        state = .error(error)
      }

    // (t4)
    case (.helloSent, .didWriteValue(_)):
      state = .helloAcked

    // (t5)
    case (.helloAcked, .didReceiveResponse(let response))
    where
      response.hasGoogle_Jacquard_Protocol_HelloResponse_hello
      && response.Google_Jacquard_Protocol_HelloResponse_hello.protocolMin >= 2
      && response.Google_Jacquard_Protocol_HelloResponse_hello.protocolMax <= 2:
      do {
        try sendBegin()
        state = .beginSent
      } catch (let error) {
        state = .error(error)
      }

    // (e6)
    case (.helloAcked, .didReceiveResponse(_)):
      state = .error(TagConnectionError.malformedResponseError)

    // (t7)
    case (.beginSent, .didWriteValue(_)):
      state = .beginAcked

    // (t8)
    case (.beginAcked, .didReceiveResponse(let response))
    where response.hasGoogle_Jacquard_Protocol_BeginResponse_begin:
      state = .creatingTagInstance
      createConnectedTagInstance()

    // (e9)
    case (.beginAcked, .didReceiveResponse(_)):
      state = .error(TagConnectionError.malformedResponseError)

    // (t10)
    case (.creatingTagInstance, .createdConnectedTagInstance(let tag)):
      state = .tagInitialized(tag)

    // No valid transition found.
    default:
      jqLogger.error("No transition found for (\(state), \(event))")
      state = .error(TagConnectionError.internalError)
    }

    jqLogger.debug("Exiting \(self).handleEvent() new state: \(state)")
  }
}

//MARK: - Dot Statechart

// Note that the order is important - the transition events/guards will be evaluated in order and
// only the first matching transition will have effect.

// digraph {
//   node [shape=point] start, complete;
//   node [shape=Mrecord]
//   edge [decorate=1, minlen=2]
//
//   start -> paired;
//
//   //TODO: add timeout.
//
//   // Note that unlike regular commands after initialization is complete, throughout this
//   // state machine we request write responses from CoreBluetooth.
//
//   "*" -> error
//    [label="(e1)
//            didWriteValue(error)
//            [error != nil]"];
//
//   "* " -> error
//     [label="(e2) didReceiveResponseError(error)"];
//
//   paired ->  helloSent
//     [label="(t3)
//             startNegotiation
//             / sendHello"];
//
//   helloSent -> helloAcked
//     [label="(t4)
//             didWriteValue(_)"];
//
//   helloAcked -> beginSent
//     [label="(t5)
//             didReceiveResponse(data)
//             [response.hasHelloResponse && (resp.minProtocol ≤ 2 ≤ resp.maxProtocol)]
//             / sendBegin()"];
//
//   helloAcked -> error
//     [label="(e6)
//             didReceiveResponse(_)"];
//
//   beginSent -> beginAcked
//     [label="(t7)
//             didWriteValue(_)"];
//
//   beginAcked -> creatingTagInstance
//     [label="(t8)
//             didReceiveResponse(_)
//             [response.hasBeginResponse)]
//             / createConnectedTagInstance(resp)"];
//
//   beginAcked -> error
//     [label="(e9)
//             didReceiveResponse(_)"];
//
//   creatingTagInstance -> tagInitialized
//     [label="(t10) createdTagInstance(tag)"];
//
//   tagInitialized -> complete;
//}
