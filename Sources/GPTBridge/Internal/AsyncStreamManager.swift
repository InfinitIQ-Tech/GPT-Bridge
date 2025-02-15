//
//  AsyncStreamManager.swift
//  GPTBridge
//
//  Created by Kenneth Dubroff on 2/9/25.
//

import Foundation

protocol StreamingRequestManageable: RequestManageable {
    func makeRequest<U: EncodableRequest>(
        endpoint: AssistantEndpoint,
        method: HttpMethod,
        requestData: U?
    ) async throws -> AsyncThrowingStream<DeltaEvent, any Error> where U: EncodableRequest
}

struct StreamingRequestManager: StreamingRequestManageable {
    var baseURL: URL

    init(baseURL: URL = URL(string: Self.baseURLString)!) {
        self.baseURL = baseURL
    }

    func makeRequest<U>(
        endpoint: AssistantEndpoint,
        method: HttpMethod,
        requestData: U?
    ) async throws -> AsyncThrowingStream<DeltaEvent, any Error>
    where U : EncodableRequest {

        AsyncThrowingStream<DeltaEvent, any Error> { continuation in
            Task {
                do {
                    let endpointURL = makeURL(fromEndpoint: endpoint)
                    var request = URLRequest(url: endpointURL)
                    request.httpMethod = method.rawValue
                    request.allHTTPHeaderFields = requestData?.jsonPayloadHeaders

                    if let requestData = requestData,
                       method != .GET {
                        request.httpBody = try requestData.encodeInstance()
                    }

                    let (byteStream, response) = try await URLSession.shared.bytes(for: request)

                    guard let httpResponse = response as? HTTPURLResponse else {
                        throw RequestError.invalidResponse(9001)
                    }

                    guard (200..<300).contains(httpResponse.statusCode) else {
                        if httpResponse.statusCode == 400 {
                            // Attempt to decode OpenAI error message
                            let (data, _) = try await byteStream.collectAll()
                            if let jsonError = try? JSONDecoder().decode(OpenAIJSONErrorWrapper.self, from: data) {
                                let message = jsonError.error.message
                                if message.contains("Can't add messages to thread"),
                                   message.contains("while a run"),
                                   message.contains("is active") {
                                    // extract runId from the message
                                    if let idBaseString = message.components(separatedBy: "run_").last,
                                       let id = idBaseString.components(separatedBy: .whitespaces).first {
                                        let runId = "run_\(id)"
                                        throw RequestError.runAlreadyActive(runId: runId)
                                    } else {
                                        throw RequestError.openAIErrorMessage(message)
                                    }
                                } else {
                                    throw RequestError.openAIErrorMessage(message)
                                }
                            } else {
                                print(String(data: data, encoding: .utf8) ?? "No Data")
                                throw RequestError.invalidResponse(400)
                            }
                        } else {
                            let (bodyData, _) = try await byteStream.collectAll()
                            print("endpoint: \(endpoint.path), status code: \(httpResponse.statusCode)")
                            print(String(data: bodyData, encoding: .utf8) ?? "No Response Data")
                            throw RequestError.invalidResponse(httpResponse.statusCode)
                        }
                    }

                    // MARK: SSE Handling
                    for try await rawLine in byteStream.lines {
                        let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)

                        // Blank line? SSE event boundary or keep-alive
                        guard !line.isEmpty else {
                            continue
                        }

                        // Lines starting with a colon => keep-alive / comment
                        // // SSE spec says ignore/comment lines.
                        if line.hasPrefix(":") {
                            continue
                        }

                        // Handle events
                        if line.hasPrefix("event:") {
                            let eventValue = line
                                .dropFirst("event:".count)
                                .trimmingCharacters(in: .whitespacesAndNewlines)
                            // If the server uses "event: done" to signal finish:
                            if eventValue == "done" {
                                continuation.finish()
                                return
                            } else {
                                continue
                            }
                        }

                        // Handle "data: ..." lines
                        if line.hasPrefix("data:") {
                            let dataValue = line
                                .dropFirst("data:".count)
                                .trimmingCharacters(in: .whitespacesAndNewlines)

                            if dataValue == "[DONE]" {
                                continuation.finish()
                                return
                            }

                            // Try decoding this line as `DeltaEvent`
                            let chunkData = Data(dataValue.utf8)
                            do {
                                let decoder = JSONDecoder()
                                let partialResponse = try decoder.decode(DeltaEvent.self, from: chunkData)
                                continuation.yield(partialResponse)
                            } catch {
                                continue
                            }

                            continue
                        }
                        // TODO: Unhandled SSE lines (currently ignored)
                    }

                    // (EOF?), end the stream
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}

// (unchanged) for collecting the entire byte stream
extension URLSession.AsyncBytes {
    /// Collect the remaining bytes into a single Data buffer.
    func collectAll() async throws -> (Data, URLResponse) {
        var buffer = Data()
        do {
            for try await chunk in self {
                buffer.append(chunk)
            }
        } catch {
            print(error)
            throw error
        }
        return (buffer, URLResponse())
    }
}
