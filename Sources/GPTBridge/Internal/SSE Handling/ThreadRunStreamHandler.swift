//
//  ThreadRunStatusStreamer.swift
//  GPTBridge
//
//  Created by Kenneth Dubroff on 2/22/25.
//

import Foundation

/// Handles streaming of run-status events for a "thread run" via SSE.
struct ThreadRunStreamHandler: SSEStreamHandlable {
    /// Validates that the response is a 2xx. If not, tries to decode an error from the SSE body.
    func validateResponse(
        _ response: URLResponse,
        byteStream: URLSession.AsyncBytes
    ) async throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            // Read entire body for error details
            let (bodyData, _) = try await byteStream.collectAll()
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            if httpResponse.statusCode == 400,
               let jsonError = try? decoder.decode(OpenAIJSONErrorWrapper.self, from: bodyData) {
                throw RequestError.openAIErrorMessage(jsonError.error.message)
            } else {
                throw RequestError.invalidResponse(httpResponse.statusCode)
            }
        }
    }


    /// Streams "thread run status" events from a given request.
    /// - Parameters:
    ///   - request: The `URLRequest` pointing to the SSE endpoint.
    ///   - inactivityTimeout: If non-nil, a watchdog will cancel the stream if no events arrive within this many seconds.
    func streamRunStatusEvents(
        with request: URLRequest,
        inactivityTimeout: TimeInterval?
    ) -> AsyncThrowingStream<RunStatusEvent, Error> {
        streamEvents(with: request, inactivityTimeout: inactivityTimeout)
    }

    func parseEvent(eventType: String, eventData: String) -> RunStatusEvent? {
           let trimmedEventType = eventType.trimmingCharacters(in: .whitespacesAndNewlines)
           let data = Data(eventData.utf8)

           switch trimmedEventType {
           case RunStatusEvent.threadCreatedKey:
               if let threadResp = try? CreateThreadResponse.createInstanceFrom(data: data) {
                   return .threadCreated(threadResp.id)
               }

           case RunStatusEvent.runStepCreatedKey:
               if let step = try? MessageRunStepResult.createInstanceFrom(data: data) {
                   return .runStepCreated(step)
               }

        case RunStatusEvent.runStepInProgressKey:
            if let step = try? MessageRunStepResult.createInstanceFrom(data: data) {
                return .runStepInProgress(step)
            } else {

                return handleUnknownEvent(trimmedEventType, data: eventData)
            }

        case RunStatusEvent.runStepCompletedKey:
            if let step = try? MessageRunStepResult.createInstanceFrom(data: data) {
                return .runStepCompleted(step)
            } else {
                return handleUnknownEvent(trimmedEventType, data: eventData)
            }

        case RunStatusEvent.messageDeltaKey:
            if let event = try? MessageDeltaEvent.createInstanceFrom(data: data) {
                let message = event.delta.content.first?.text.value ?? ""
                return .messageDelta(message)
            } else {
                return handleUnknownEvent(trimmedEventType, data: eventData)
            }

        case RunStatusEvent.messageCompletedKey:
            if let response = try? StreamingMessageResponse.createInstanceFrom(data: data) {
                let assistantMessage = ChatMessage(content: response.content.first?.text.value ?? "", role: response.role)
                return .messageCompleted(assistantMessage)
            } else {
                print("message completed event received, but message can't be parsed")
                return handleUnknownEvent(trimmedEventType, data: eventData)
            }

        case RunStatusEvent.runCompletedKey:
            if let runResult = try? MessageRunStepResult.createInstanceFrom(data: data) {
                return .runCompleted(runResult)
            } else {
                return handleUnknownEvent(trimmedEventType, data: eventData)
            }

        case RunStatusEvent.runFailedKey,
             RunStatusEvent.runCancelledKey,
             RunStatusEvent.runExpiredKey:
            if let runResult = try? MessageRunStepResult.createInstanceFrom(data: data) {
                if trimmedEventType == RunStatusEvent.runFailedKey {
                    print("run failed")
                    return .runFailed(runResult)
                } else if trimmedEventType == RunStatusEvent.runCancelledKey {
                    print("run cancelled")
                    return .runCancelled(runResult)
                } else {
                    print("run expired")
                    return .runExpired(runResult)
                }
            } else {
                return handleUnknownEvent(trimmedEventType, data: eventData)
            }

        case RunStatusEvent.errorOccurredKey:
            if let errorObj = try? JSONDecoder().decode(OpenAIJSONError.self, from: data) {
                return .errorOccurred(errorObj)
            } else {
                let fallbackError = OpenAIJSONError(message: eventData, type: nil, param: nil, code: nil)
                return .errorOccurred(fallbackError)
            }

        case RunStatusEvent.runRequiresActionKey:
               if let response = try? RunThreadResponse.createInstanceFrom(data: data) {
                   let toolCalls = response.requiredAction?.submitToolOutputs.toolCalls ?? []
                   let response = AssistantFunctionResponse(runId: response.id, toolCalls: toolCalls)
                   return .runRequiresAction(response)
               } else {
                   print("Required Action Event Emitted, but can't parse data")
                   return handleUnknownEvent(eventType, data: eventData)
               }


        case RunStatusEvent.doneKey:
            return .done

        default:
            return handleUnknownEvent(trimmedEventType, data: eventData)
        }
        return handleUnknownEvent(trimmedEventType, data: eventData)
    }

    private func handleUnknownEvent(_ event: String, data: String) -> RunStatusEvent {
        // for debug
//        print("Unhandled SSE event: \(event), data: \(data)")
        return .unknown(event: event, data: data)
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

    func linesPreservingEmpty() -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                var buffer = [UInt8]()
                var iterator = self.makeAsyncIterator()

                do {
                    while let byte = try await iterator.next() {
                        if byte == UInt8(ascii: "\n") {
                            // Reached end of a line
                            let lineStr = String(decoding: buffer, as: UTF8.self)
                            continuation.yield(lineStr)
                            buffer.removeAll(keepingCapacity: true)
                        } else if byte == UInt8(ascii: "\r") {
                            // SSE often has CR+LF. Skip the CR. We'll handle LF above.
                            continue
                        } else {
                            buffer.append(byte)
                        }
                    }
                    // If there's a trailing line with no final \n:
                    if !buffer.isEmpty {
                        let lineStr = String(decoding: buffer, as: UTF8.self)
                        continuation.yield(lineStr)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
