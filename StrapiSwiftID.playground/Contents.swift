import UIKit
import Foundation

let baseURL = "https://api.swiftid.dev"

struct ErrorResponse: Decodable {
  struct InnerMessage: Decodable {
    let id: String
    let message: String
  }
  enum ErrorMessage: Decodable {
    case string(String)
    case array([Message])
    
    init(from decoder: Decoder) throws {
      let container =  try decoder.singleValueContainer()
      do {
        let stringVal = try container.decode(String.self)
        self = .string(stringVal)
      } catch DecodingError.typeMismatch {
        let arrayVal = try container.decode([Message].self)
        self = .array(arrayVal)
      }
    }
  }
  struct Message: Decodable {
    let messages: [InnerMessage]
  }
  let statusCode: Int
  let error: String
  let message: ErrorMessage
}

extension URLSession {
  func get<ResponseType: Decodable>(pathname: String, authToken: String? = nil) async throws -> ResponseType {
    var request = URLRequest(url: URL(string: "\(baseURL)\(pathname)")!)
    request.httpMethod = "GET"
    
    if let token = authToken {
      request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    }
    
    var fetchData: Data? = nil
    do {
      let (data, response) = try await URLSession.shared.data(for: request)
      
      if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
        let errorData = try JSONDecoder().decode(ErrorResponse.self, from: data)
        var message = ""
        switch errorData.message {
        case .string(let messageString):
          message = messageString
        case .array(let messages):
          message = messages.first?.messages.first?.message ?? ""
        }
        throw NSError(domain: "URLSession", code: httpResponse.statusCode, userInfo: [
          NSLocalizedDescriptionKey: message
        ])
      }
      fetchData = data
    } catch {
      throw error
    }
    
    guard let data = fetchData else {
      throw NSError(domain: "URLSession", code: 0)
    }
    
    let responseData = try JSONDecoder().decode(ResponseType.self, from: data)
    return responseData
  }
  func post<RequestType: Encodable, ResponseType: Decodable>(
    pathname: String,
    data: RequestType,
    authToken: String? = nil) async throws -> ResponseType {
      var request = URLRequest(url: URL(string: "\(baseURL)\(pathname)")!)
      request.httpMethod = "POST"
      request.addValue("application/json", forHTTPHeaderField: "Content-Type")
      if let token = authToken {
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
      }
      request.httpBody = try JSONEncoder().encode(data)
      
      var fetchData: Data? = nil
      do {
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
          let errorData = try JSONDecoder().decode(ErrorResponse.self, from: data)
          var message = ""
          switch errorData.message {
          case .string(let messageString):
            message = messageString
          case .array(let messages):
            message = messages.first?.messages.first?.message ?? ""
          }
          throw NSError(domain: "URLSession", code: httpResponse.statusCode, userInfo: [
            NSLocalizedDescriptionKey: message
          ])
        }
        fetchData = data
      } catch {
        throw error
      }
      
      guard let data = fetchData else {
        throw NSError(domain: "URLSession", code: 0)
      }
      
      let responseData = try JSONDecoder().decode(ResponseType.self, from: data)
      return responseData
    }
}

struct LoginRequestData: Encodable {
  let identifier: String
  let password: String
}
struct LoginResponseData: Decodable {
  let jwt: String
}
func login(_ loginRequest: LoginRequestData) async throws -> String {
  let loginData: LoginResponseData = try await URLSession.shared.post(pathname: "/auth/local", data: loginRequest)
  return loginData.jwt
}

struct RegisterRequestData: Encodable {
  let username: String
  let email: String
  let password: String
}
func register(_ registerRequest: RegisterRequestData) async throws -> String {
  let registerData: LoginResponseData = try await URLSession.shared.post(pathname: "/auth/local/register", data: registerRequest)
  return registerData.jwt
}

struct MeResponseData: Decodable {
  let id: Int
  let username: String
  let email: String
}
func me(authToken: String? = nil) async throws -> MeResponseData {
  let meData: MeResponseData = try await URLSession.shared.get(pathname: "/users/me", authToken: authToken)
  return meData
}

Task {
  do {
    /* Login example */
    let jwt = try await login(LoginRequestData(identifier: "your email", password: "password here"))
    print(jwt)
    
    let registerJwt =  try await register(RegisterRequestData(username: "your username", email: "your email", password: "your password"))
    print(registerJwt)
    
    let meData = try await me(authToken: jwt)
    print(meData)
  } catch {
    print(error)
  }
}
