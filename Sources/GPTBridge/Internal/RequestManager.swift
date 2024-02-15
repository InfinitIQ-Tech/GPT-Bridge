//
//  RequestManager.swift
//  SlackMojiChef
//
//  Created by Kenneth Dubroff on 12/7/23.
//

import Foundation

struct RequestManager {
    private let baseURL: URL

    init(baseURL: URL = URL(string: "https://api.openai.com/v1")!) {
        self.baseURL = baseURL
    }

    func makeRequest<T: DecodableResponse, U: EncodableRequest>(
        endpoint: AssistantEndpoint,
        method: HttpMethod,
        requestData: U?
    ) async throws -> T {
        let endpointURL = baseURL.appendingPathComponent(endpoint.rawValue)

        var request = URLRequest(url: endpointURL)
        request.httpMethod = method.rawValue
        request.allHTTPHeaderFields = requestData?.jsonPayloadHeaders

        // Set the request body if needed
        if let requestData = requestData,
           method != .GET {
            do {
                request.httpBody = try requestData.encodeInstance()
            } catch {
                throw error
            }
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode >= 200 && httpResponse.statusCode < 400 {
                    do {
                        let responseObject = try T.createInstanceFrom(data: data)
                        return responseObject
                    } catch {
                        print("Error decoding data: \(String(data: data, encoding: .utf8))")
                        throw error
                    }
                } else if httpResponse.statusCode == 400 {
                    if let jsonError = try? JSONDecoder().decode(OpenAIJSONErrorWrapper.self, from: data) {
                        let message = jsonError.error.message
                        guard message.contains("Can't add messages to thread") 
                                && message.contains("while a run")
                                && message.contains("is active") else {
                            throw RequestError.openAIErrorMessage(message)
                        }

                        guard let idBaseString = message.components(separatedBy: "run_").last,
                              let id = idBaseString.components(separatedBy: .whitespaces).first else {
                            throw RequestError.openAIErrorMessage(message)
                        }

                        let runId = "run_\(id)"
                        throw RequestError.runAlreadyActive(runId: runId)
                    } else {
                        throw RequestError.invalidResponse(400)
                    }
                } else {
                    print("endpoint: \(endpoint.rawValue), status code: \(httpResponse.statusCode)")
                    print(String(data: data, encoding: .utf8) ?? "No Response Data")
                    throw RequestError.invalidResponse(httpResponse.statusCode)
                }
            } else {
                throw RequestError.invalidResponse(9001)
            }
        } catch {
            throw error
        }
    }
}

enum RequestError: Error, Equatable {
    case openAIErrorMessage(String)
    case invalidResponse(Int)
    case runAlreadyActive(runId: String)
}

struct OpenAIJSONErrorWrapper: Decodable {
    let error: OpenAIJSONError
}

struct OpenAIJSONError: Decodable {
    let message: String
    let type: String?
    let param: String?
    let code: Int?
}
