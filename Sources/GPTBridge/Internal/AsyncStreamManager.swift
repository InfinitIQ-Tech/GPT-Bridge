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

/// Represents the various run status events that can be streamed.
public enum RunStatusEvent {
    case runStepCreated(RunStepResult)
    case runStepInProgress(RunStepResult)
    case runStepCompleted(RunStepResult)
    case messageDelta(MessageRunStepResult)
    case messageCompleted(ChatMessage)
    case runCompleted(RunStepResult)
    case runFailed(RunStepResult)
    case runCancelled(RunStepResult)
    case runExpired(RunStepResult)
    case errorOccurred(OpenAIJSONError)     // Represents an error event from the stream
    case done               // Indicates the stream has finished (completion marker)
    case unknown(event: String, data: String)  // Fallback for unrecognized events

    var key: String {
        switch self {
        case .runStepCreated:
            "thread.run.step.created"
        case .runStepCompleted:
            "thread.run.step.completed"
        case .runStepInProgress:
            "thread.run.step.in_progress"
        case .messageDelta:
            "thread.message.delta"
        case .messageCompleted:
            "thread.message.completed"
        case .runCompleted:
            "thread.run.completed"
        case .runFailed:
            "thread.run.failed"
        case .runCancelled:
            "thread.run.cancelled"
        case .runExpired:
            "thread.run.expired"
        case .errorOccurred:
            "error"
        case .done:
            "done"
        case .unknown:
            "thread.unknown"
        }
    }
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

    /// Streams the status of a given run (by polling via Server-Sent Events).
    /// - Parameters:
    ///   - threadId: The ID of the thread the run belongs to.
    ///   - runId: The ID of the run to monitor.
    ///   - timeout: Timeout interval (in seconds) to stop if no events are received (prevents hanging).
    /// - Returns: An `AsyncThrowingStream` of `RunStatusEvent` values that can be awaited.
    func pollRunStatusStream(
        threadId: String,
        runId: String,
        endpoint: AssistantEndpoint,
        timeout: TimeInterval = 30.0
    ) async throws -> AsyncThrowingStream<RunStatusEvent, any Error> {
        // A class is used so both tasks see the *same* lastEventTime.
        class LastEventTracker {
            var value = Date()  // start as 'now'
        }
        let sharedTime = LastEventTracker()

        return AsyncThrowingStream<RunStatusEvent, any Error> { continuation in
            // Build your SSE endpoint, request, etc.
            let url = URL(string: "https://api.openai.com/v1/assistants/\(threadId)/runs/\(runId)?stream=true")!
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue("text/event-stream", forHTTPHeaderField: "Accept")

            // 1) Task for reading the SSE stream
            let networkTask = Task.detached(priority: .medium) {
                do {
                    let (bytesStream, response) = try await URLSession.shared.bytes(for: request)

                    // Validate HTTP response
                    guard let httpResponse = response as? HTTPURLResponse else {
                        throw URLError(.badServerResponse)
                    }

                    if httpResponse.statusCode != 200 {
                        // Non-200 => read the response body for an error
                        var errorData = Data()
                        for try await byte in bytesStream {
                            errorData.append(byte)
                        }
                        if let errorObj = try? JSONDecoder().decode(OpenAIJSONError.self, from: errorData) {
                            continuation.yield(.errorOccurred(errorObj))
                        }
                        continuation.finish()
                        return
                    }

                    // SSE Parsing
                    var currentEvent: String? = nil
                    var dataBuffer = ""

                    for try await line in bytesStream.lines {
                        // Update last-event time on any new line
                        sharedTime.value = Date()

                        if line.hasPrefix("event:") {
                            let eventName = line.dropFirst("event:".count).trimmingCharacters(in: .whitespaces)
                            currentEvent = eventName.isEmpty ? nil : eventName
                        }
                        else if line.hasPrefix("data:") {
                            let dataPart = line.dropFirst("data:".count)
                            if !dataBuffer.isEmpty { dataBuffer.append("\n") }
                            dataBuffer.append(contentsOf: dataPart)
                        }
                        else if line.isEmpty {
                            // End of SSE event
                            guard !dataBuffer.isEmpty || currentEvent != nil else {
                                // Likely a keep-alive blank line
                                continue
                            }

                            // Dispatch event
                            if let eventType = currentEvent {
                                switch eventType {
                                case "thread.run.step.created":
                                    if let step = try? JSONDecoder().decode(MessageRunStepResult.self, from: Data(dataBuffer.utf8)) {
                                        continuation.yield(.runStepCreated(step))
                                    }
                                case "thread.run.step.in_progress":
                                    if let step = try? JSONDecoder().decode(MessageRunStepResult.self, from: Data(dataBuffer.utf8)) {
                                        continuation.yield(.runStepInProgress(step))
                                    }
                                case "thread.run.step.completed":
                                    if let step = try? JSONDecoder().decode(MessageRunStepResult.self, from: Data(dataBuffer.utf8)) {
                                        continuation.yield(.runStepCompleted(step))
                                    }
                                case "thread.run.completed":
                                    if let run = try? JSONDecoder().decode(MessageRunStepResult.self, from: Data(dataBuffer.utf8)) {
                                        continuation.yield(.runCompleted(run))
                                    }
                                case "thread.run.failed", "thread.run.incomplete", "thread.run.expired":
                                    if let run = try? JSONDecoder().decode(MessageRunStepResult.self, from: Data(dataBuffer.utf8)) {
                                        continuation.yield(.runFailed(run))
                                    }
                                case "thread.run.cancelled":
                                    if let run = try? JSONDecoder().decode(MessageRunStepResult.self, from: Data(dataBuffer.utf8)) {
                                        continuation.yield(.runCancelled(run))
                                    }
                                case "thread.message.delta":
                                    if let msgDelta = try? JSONDecoder().decode(MessageRunStepResult.self, from: Data(dataBuffer.utf8)) {
                                        continuation.yield(.messageDelta(msgDelta))
                                    }
                                case "thread.message.completed":
                                    if let message = try? JSONDecoder().decode(ChatMessage.self, from: Data(dataBuffer.utf8)) {
                                        continuation.yield(.messageCompleted(message))
                                    }
                                case "thread.message.created", "thread.message.in_progress":
                                    // Possibly partial or in-progress
                                    if let message = try? JSONDecoder().decode(MessageRunStepResult.self, from: Data(dataBuffer.utf8)) {
                                        continuation.yield(.messageDelta(message))
                                    }
                                case "error":
                                    // Some error event from server
                                    if let apiError = try? JSONDecoder().decode(OpenAIJSONError.self, from: Data(dataBuffer.utf8)) {
                                        continuation.yield(.errorOccurred(apiError))
                                    } else {
                                        let errInfo = OpenAIJSONError(message: dataBuffer, type: nil, param: nil, code: nil)
                                        continuation.yield(.errorOccurred(errInfo))
                                    }
                                    // End the stream on an error event (server-chosen convention)
                                    currentEvent = nil
                                    dataBuffer = ""
                                    break

                                case "done":
                                    // Server signals done
                                    continuation.yield(.done)
                                    currentEvent = nil
                                    dataBuffer = ""
                                    break

                                default:
                                    // Unknown or unhandled event type
                                    continuation.yield(.unknown(event: eventType, data: dataBuffer))
                                }
                            } else {
                                // No explicit "event:" => check data content
                                let trimmed = dataBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
                                if trimmed == "[DONE]" {
                                    continuation.yield(.done)
                                } else {
                                    continuation.yield(.unknown(event: "<unspecified>", data: dataBuffer))
                                }
                            }

                            if Task.isCancelled { break }
                            currentEvent = nil
                            dataBuffer = ""
                        }

                        if Task.isCancelled { break }
                    }

                    // Finished reading SSE
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            // 2) A "watchdog" task that checks once per second whether we've gone too long since last event
            let inactivityTimeoutTask = Task.detached(priority: .medium) {
                while !Task.isCancelled {
                    // Sleep 1 second at a time
                    do {
                        try await Task.sleep(nanoseconds: 1_000_000_000)
                    } catch {
                        // Sleep was cancelled => just exit
                        return
                    }

                    // If we've exceeded 'timeout' since last event, bail out
                    let elapsed = Date().timeIntervalSince(sharedTime.value)
                    if elapsed > timeout {
                        networkTask.cancel() // Cancel reading
                        let timeoutError = OpenAIJSONError(
                            message: "No SSE events arrived for \(Int(timeout))s (inactivity timeout).",
                            type: nil,
                            param: nil,
                            code: nil
                        )
                        continuation.yield(.errorOccurred(timeoutError))
                        continuation.finish()
                        break
                    }
                }
            }

            // 3) Cleanup when the stream finishes or is cancelled
            continuation.onTermination = { @Sendable _ in
                networkTask.cancel()
                inactivityTimeoutTask.cancel()
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
