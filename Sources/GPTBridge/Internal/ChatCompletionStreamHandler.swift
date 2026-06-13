//
//  ChatCompletionStreamHandler.swift
//  GPTBridge
//
//  Created by Kenneth Dubroff on 5/11/26.
//

import Foundation

/// Handles streaming of chat completion chunks via SSE.
struct ChatCompletionStreamHandler: SSEStreamHandlable {
    func streamChatCompletionEvents(
        with request: URLRequest,
        inactivityTimeout: TimeInterval?
    ) -> AsyncThrowingStream<ChatCompletionStreamEvent, Error> {
        streamEvents(with: request, inactivityTimeout: inactivityTimeout)
    }

    func validateResponse(
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

    func parseEvents(eventType: String, eventData: String) -> [ChatCompletionStreamEvent] {
        let trimmedEventData = eventData.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedEventData.isEmpty else { return [] }

        if eventType == "done" || trimmedEventData == "[DONE]" {
            return [.done]
        }

        let data = Data(trimmedEventData.utf8)
        guard let chunk = try? ChatCompletionChunk.createInstanceFrom(data: data) else {
            return [.unknown(data: eventData)]
        }

        return chunk.choices.flatMap { choice in
            var events: [ChatCompletionStreamEvent] = []

            if let content = choice.delta.content,
               !content.isEmpty {
                events.append(.contentDelta(content))
            }

            choice.delta.toolCalls?.forEach {
                events.append(.toolCallDelta($0))
            }

            if choice.finishReason != nil {
                events.append(.finished(choice.finishReason))
            }

            return events
        }
    }

    func timeoutEvent(timeout: TimeInterval) -> ChatCompletionStreamEvent? {
        let errorInfo = OpenAIJSONError(
            message: "No chat completion SSE events for \(Int(timeout))s (timeout).",
            type: nil,
            param: nil,
            code: nil
        )
        return .errorOccurred(errorInfo)
    }
}
