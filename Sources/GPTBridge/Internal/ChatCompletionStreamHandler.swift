//
//  ChatCompletionStreamHandler.swift
//  GPTBridge
//
//  Created by Kenneth Dubroff on 5/11/26.
//

import Foundation

/// Handles streaming of chat completion chunks via SSE.
struct ChatCompletionStreamHandler {
    func streamChatCompletionEvents(
        with request: URLRequest,
        inactivityTimeout: TimeInterval?
    ) -> AsyncThrowingStream<ChatCompletionStreamEvent, Error> {
        actor LastEventTracker {
            private var lastEventTime = Date()
            func updateLastEventTime() {
                lastEventTime = Date()
            }
            func getLastEventTime() -> Date {
                lastEventTime
            }
        }
        let eventTracker = LastEventTracker()

        return AsyncThrowingStream { continuation in
            let eventReadingTask = Task {
                do {
                    let (byteStream, response) = try await URLSession.shared.bytes(for: request)
                    try await validateChatCompletionResponse(response, byteStream: byteStream)

                    var eventDataBuffer = ""

                    for try await rawLine in byteStream.linesPreservingEmpty() {
                        await eventTracker.updateLastEventTime()

                        let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)

                        if line.hasPrefix("data:") {
                            let dataPart = line.dropFirst("data:".count)
                            if !eventDataBuffer.isEmpty { eventDataBuffer.append("\n") }
                            eventDataBuffer.append(contentsOf: dataPart)
                        } else if line.isEmpty {
                            parseAndYieldChatCompletionEvent(
                                eventData: eventDataBuffer,
                                continuation: continuation
                            )
                            eventDataBuffer = ""
                        }

                        if Task.isCancelled { break }
                    }

                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            let watchdogTask = Task {
                guard let timeout = inactivityTimeout else { return }
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                    let elapsed = await Date().timeIntervalSince(eventTracker.getLastEventTime())
                    if elapsed > timeout {
                        eventReadingTask.cancel()
                        let errorInfo = OpenAIJSONError(
                            message: "No chat completion SSE events for \(Int(timeout))s (timeout).",
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

            continuation.onTermination = { _ in
                eventReadingTask.cancel()
                watchdogTask.cancel()
            }
        }
    }

    private func validateChatCompletionResponse(
        _ response: URLResponse,
        byteStream: URLSession.AsyncBytes
    ) async throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            let (bodyData, _) = try await byteStream.collectAll()
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            if let jsonError = try? decoder.decode(OpenAIJSONErrorWrapper.self, from: bodyData) {
                throw RequestError.openAIErrorMessage(jsonError.error.message)
            } else {
                throw RequestError.invalidResponse(httpResponse.statusCode)
            }
        }
    }

    private func parseAndYieldChatCompletionEvent(
        eventData: String,
        continuation: AsyncThrowingStream<ChatCompletionStreamEvent, Error>.Continuation
    ) {
        let trimmedEventData = eventData.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedEventData.isEmpty else { return }

        if trimmedEventData == "[DONE]" {
            continuation.yield(.done)
            return
        }

        let data = Data(trimmedEventData.utf8)
        guard let chunk = try? ChatCompletionChunk.createInstanceFrom(data: data) else {
            continuation.yield(.unknown(data: eventData))
            return
        }

        for choice in chunk.choices {
            if let content = choice.delta.content,
               !content.isEmpty {
                continuation.yield(.contentDelta(content))
            }

            choice.delta.toolCalls?.forEach {
                continuation.yield(.toolCallDelta($0))
            }

            if choice.finishReason != nil {
                continuation.yield(.finished(choice.finishReason))
            }
        }
    }
}
