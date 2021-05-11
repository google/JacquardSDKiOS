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

/// The possible errors published by a network activity.
public enum APIError: Error {

  /// This class of status code is intended for situations in which the client seems to have erred.
  case clientError

  /// This class of status code indicates the server failed to fulfill an apparently valid request.
  case serverError

  /// This class of status code indicates the failure while parsing the data.
  case parsingFailed

  /// This class of status code indicates the failure while downloading a file.
  case downloadFailed

  /// This class of status code indicates the download url was Invalid.
  case invalidURL

  /// The class of the status code cannot be resolved.
  case undefined

  /// The class of status code indicates no internet connection.
  case noInternet

  /// Localized description of API Error cases.
  public var localizedDescription: String {
    switch self {
    case .clientError: return "Client error (Bad Request / unauthorized / notFound)."
    case .serverError: return "Server error (internalServerError / not Implemented)."
    case .parsingFailed: return "Parsing Failed."
    case .downloadFailed: return "Failed to download file"
    case .invalidURL: return "Download URL provided was invalid"
    case .undefined: return "Request could not be resolved."
    case .noInternet: return "The internet connection appears to be offline."
    }
  }
}

protocol CloudManager {
  var session: URLSession { get }
  /// Returns the publisher based on url request passed to it.
  ///
  /// - Parameters:
  ///   - request: The url request mostly built from URLRequestBuilder class.
  ///   - type: The codable data model
  /// - Returns: The publisher contains Output as passed data model and Failure as APIError.
  func execute<T>(request: URLRequest, type: T.Type) -> AnyPublisher<T, APIError> where T: Decodable

  func downloadFile(request: URLRequest) -> AnyPublisher<Data, APIError>

  func getDeviceFirmware(params: [String: Any]) -> AnyPublisher<DFUUpdateInfo, APIError>

  func downloadFirmwareImage(url: URL) -> AnyPublisher<Data, APIError>
}

extension CloudManager {

  func execute<T: Decodable>(request: URLRequest, type: T.Type) -> AnyPublisher<T, APIError> {
    return session.dataTaskPublisher(for: request)
      .tryMap({ data, response in
        if let response = response as? HTTPURLResponse, response.statusCode != 200 {
          switch response.statusCode {
          case 400..<500: throw APIError.clientError
          case 500..<600: throw APIError.serverError
          default: throw APIError.undefined
          }
        }
        return data
      })
      .mapError {
        if let error = $0 as NSError?,
          error.domain == NSURLErrorDomain && error.code == NSURLErrorNotConnectedToInternet
        {
          return APIError.noInternet
        }
        return $0 as? APIError ?? .undefined
      }
      .flatMap {
        Just($0)
          .decode(type: T.self, decoder: JSONDecoder())
          // return error if json decoding fails
          .mapError { error in APIError.parsingFailed }
      }
      .receive(on: DispatchQueue.main)
      .eraseToAnyPublisher()
  }

  func downloadFile(request: URLRequest) -> AnyPublisher<Data, APIError> {

    let subject: PassthroughSubject<Data, APIError> = PassthroughSubject()
    let task = session.downloadTask(with: request) { url, response, error in
      if let response = response as? HTTPURLResponse, response.statusCode != 200 {
        switch response.statusCode {
        case 400..<500:
          subject.send(completion: .failure(.clientError))
        case 500..<600:
          subject.send(completion: .failure(.serverError))
        default: break
        }
      }

      guard
        let url = url,
        let data = try? Data(contentsOf: url)
      else {
        subject.send(completion: .failure(.downloadFailed))
        return
      }
      subject.send(data)
      subject.send(completion: .finished)
    }
    task.resume()

    return subject.eraseToAnyPublisher()
  }
}
