//
//  ThreadRunStatusStreamer.swift
//  GPTBridge
//
//  Created by Kenneth Dubroff on 2/22/25.
//

import Foundation

/// Handles streaming of run-status events for a "thread run" via SSE.
struct ThreadRunStatusStreamer {

    /// Streams "thread run status" events from a given request.
    /// - Parameters:
    ///   - request: The `URLRequest` pointing to the SSE endpoint.
    ///   - inactivityTimeout: If non-nil, a watchdog will cancel the stream if no events arrive within this many seconds.
    func streamRunStatusEvents(
        with request: URLRequest,
        inactivityTimeout: TimeInterval?
    ) -> AsyncThrowingStream<RunStatusEvent, Error> {

        // Tracks when we last received any SSE data, for the timeout logic.
        class LastEventTracker {
            var lastEventTime = Date()
        }
        let eventTracker = LastEventTracker()

        return AsyncThrowingStream { continuation in
            // 1) Task to read SSE lines from the network
            let eventReadingTask = Task {
                do {
                    let (byteStream, response) = try await URLSession.shared.bytes(for: request)
                    try await validateRunStatusResponse(response, byteStream: byteStream)

                    var currentEventType: String? = nil
                    var eventDataBuffer = ""

                    for try await rawLine in byteStream.lines {
                        // Update last-event time on every line
                        eventTracker.lastEventTime = Date()

                        let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !line.isEmpty else { continue }  // skip keep-alive / blank lines

                        if line.hasPrefix("event:") {
                            currentEventType = line
                                .dropFirst("event:".count)
                                .trimmingCharacters(in: .whitespaces)

                        } else if line.hasPrefix("data:") {
                            // SSE data lines may span multiple lines, so accumulate
                            let dataPart = line.dropFirst("data:".count)
                            if !eventDataBuffer.isEmpty { eventDataBuffer.append("\n") }
                            eventDataBuffer.append(contentsOf: dataPart)

                        } else if line.isEmpty {
                            // End of one SSE event block
                            if let eventType = currentEventType {
                                parseAndYieldRunStatusEvent(
                                    eventType: eventType,
                                    eventData: eventDataBuffer,
                                    continuation: continuation
                                )
                            } else {
                                // No "event:" → check if data indicates [DONE]
                                if eventDataBuffer.trimmingCharacters(in: .whitespacesAndNewlines) == "[DONE]" {
                                    continuation.yield(.done)
                                } else if !eventDataBuffer.isEmpty {
                                    continuation.yield(.unknown(event: "<unspecified>", data: eventDataBuffer))
                                }
                            }
                            // Reset
                            currentEventType = nil
                            eventDataBuffer = ""
                        }

                        if Task.isCancelled { break }
                    }

                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            // 2) Optional watchdog task for inactivity
            let watchdogTask = Task {
                guard let timeout = inactivityTimeout else { return }
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                    let elapsed = Date().timeIntervalSince(eventTracker.lastEventTime)
                    if elapsed > timeout {
                        eventReadingTask.cancel()
                        let errorInfo = OpenAIJSONError(
                            message: "No run-status SSE events for \(Int(timeout))s (timeout).",
                            type: nil,
                            param: nil,
                            code: nil
                        )
                        continuation.yield(.errorOccurred(errorInfo))
                        continuation.finish()
                        break
                    }
                }
            }

            // 3) Cleanup on stream termination
            continuation.onTermination = { _ in
                eventReadingTask.cancel()
                watchdogTask.cancel()
            }
        }
    }

    /// Validates that the response is a 2xx. If not, tries to decode an error from the SSE body.
    private func validateRunStatusResponse(
        _ response: URLResponse,
        byteStream: URLSession.AsyncBytes
    ) async throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            // Read entire body for error details
            let (bodyData, _) = try await byteStream.collectAll()
            if httpResponse.statusCode == 400,
               let jsonError = try? JSONDecoder().decode(OpenAIJSONErrorWrapper.self, from: bodyData) {
                throw RequestError.openAIErrorMessage(jsonError.error.message)
            } else {
                throw RequestError.invalidResponse(httpResponse.statusCode)
            }
        }
    }

    /// Converts SSE `eventType` + `eventData` → `RunStatusEvent`, yielding it to the continuation.
    private func parseAndYieldRunStatusEvent(
        eventType: String,
        eventData: String,
        continuation: AsyncThrowingStream<RunStatusEvent, Error>.Continuation
    ) {
        let trimmedEventType = eventType.trimmingCharacters(in: .whitespacesAndNewlines)
        let data = Data(eventData.utf8)

        switch trimmedEventType {
        case RunStatusEvent.threadCreatedKey:
            if let threadResp = try? JSONDecoder().decode(CreateThreadResponse.self, from: data) {
                continuation.yield(.threadCreated(threadResp.id))
            } else {
                continuation.yield(.unknown(event: trimmedEventType, data: eventData))
            }

        case RunStatusEvent.runStepCreatedKey:
            if let step = try? JSONDecoder().decode(MessageRunStepResult.self, from: data) {
                continuation.yield(.runStepCreated(step))
            } else {
                continuation.yield(.unknown(event: trimmedEventType, data: eventData))
            }

        case RunStatusEvent.runStepInProgressKey:
            if let step = try? JSONDecoder().decode(MessageRunStepResult.self, from: data) {
                continuation.yield(.runStepInProgress(step))
            } else {
                continuation.yield(.unknown(event: trimmedEventType, data: eventData))
            }

        case RunStatusEvent.runStepCompletedKey:
            if let step = try? JSONDecoder().decode(MessageRunStepResult.self, from: data) {
                continuation.yield(.runStepCompleted(step))
            } else {
                continuation.yield(.unknown(event: trimmedEventType, data: eventData))
            }

        case RunStatusEvent.messageDeltaKey:
            if let delta = try? JSONDecoder().decode(MessageRunStepResult.self, from: data) {
                continuation.yield(.messageDelta(delta))
            } else {
                continuation.yield(.unknown(event: trimmedEventType, data: eventData))
            }

        case RunStatusEvent.messageCompletedKey:
            if let msg = try? JSONDecoder().decode(ChatMessage.self, from: data) {
                continuation.yield(.messageCompleted(msg))
            } else {
                continuation.yield(.unknown(event: trimmedEventType, data: eventData))
            }

        case RunStatusEvent.runCompletedKey:
            if let runResult = try? JSONDecoder().decode(MessageRunStepResult.self, from: data) {
                continuation.yield(.runCompleted(runResult))
            } else {
                continuation.yield(.unknown(event: trimmedEventType, data: eventData))
            }

        case RunStatusEvent.runFailedKey,
             RunStatusEvent.runCancelledKey,
             RunStatusEvent.runExpiredKey:
            // Differentiate if needed
            if let runResult = try? JSONDecoder().decode(MessageRunStepResult.self, from: data) {
                if trimmedEventType == RunStatusEvent.runFailedKey {
                    continuation.yield(.runFailed(runResult))
                } else if trimmedEventType == RunStatusEvent.runCancelledKey {
                    continuation.yield(.runCancelled(runResult))
                } else {
                    continuation.yield(.runExpired(runResult))
                }
            } else {
                continuation.yield(.unknown(event: trimmedEventType, data: eventData))
            }

        case RunStatusEvent.errorOccurredKey:
            if let errorObj = try? JSONDecoder().decode(OpenAIJSONError.self, from: data) {
                continuation.yield(.errorOccurred(errorObj))
            } else {
                let fallbackError = OpenAIJSONError(message: eventData, type: nil, param: nil, code: nil)
                continuation.yield(.errorOccurred(fallbackError))
            }

        case RunStatusEvent.doneKey:
            continuation.yield(.done)

        default:
            continuation.yield(.unknown(event: trimmedEventType, data: eventData))
        }
    }
}

extension URLSession.AsyncBytes {
    /// Utility to gather all remaining bytes into a single `Data` buffer.
    func collectAll() async throws -> (Data, URLResponse) {
        var buffer = Data()
        for try await chunk in self {
            buffer.append(chunk)
        }
        return (buffer, URLResponse())
    }
}
