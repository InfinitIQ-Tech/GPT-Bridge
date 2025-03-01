//
//  SSEStreamHandlable.swift
//  GPTBridge
//
//  Created by Kenneth Dubroff on 2/28/25.
//


import Foundation

/// Tracks when the last event was received for timeout logic
fileprivate actor EventTimeTracker {
    private var lastEventTime = Date()
    func updateLastEventTime() {
        lastEventTime = Date()
    }
    func getLastEventTime() -> Date {
        lastEventTime
    }
}

/// Protocol defining common behavior for handling Server-Sent Events (SSE) streams.
protocol SSEStreamHandlable {
    /// The type of events this handler produces.
    associatedtype EventType

    /// Validates the HTTP response to ensure it's valid for streaming.
    func validateResponse(_ response: URLResponse, byteStream: URLSession.AsyncBytes) async throws

    /// Parses raw SSE event data into typed events.
    func parseEvent(eventType: String, eventData: String) -> EventType?
}

/// Extension providing default implementation for the SSE streaming logic.
extension SSEStreamHandlable {

    /// Streams events from a given SSE endpoint.
    /// - Parameters:
    ///   - request: The URLRequest pointing to the SSE endpoint.
    ///   - inactivityTimeout: Optional timeout to cancel the stream if no events are received.
    /// - Returns: An async stream of typed events.
    func streamEvents(
        with request: URLRequest,
        inactivityTimeout: TimeInterval?
    ) -> AsyncThrowingStream<EventType, Error> {

        let eventTracker = EventTimeTracker()

        return AsyncThrowingStream { continuation in
            // 1) Task to read SSE lines from the network
            let eventReadingTask = Task {
                do {
                    let (byteStream, response) = try await URLSession.shared.bytes(for: request)
                    try await validateResponse(response, byteStream: byteStream)

                    var currentEventType: String? = nil
                    var eventDataBuffer = ""

                    for try await rawLine in byteStream.linesPreservingEmpty() {
                        // Update last-event time on every line
                        await eventTracker.updateLastEventTime()

                        let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)

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
                            if let eventType = currentEventType,
                               let event = parseEvent(eventType: eventType, eventData: eventDataBuffer) {
                                continuation.yield(event)
                            } else {
                                // No "event:" → check if data indicates [DONE]
                                let trimmedData = eventDataBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
                                if trimmedData == "[DONE]", let doneEvent = parseEvent(eventType: "done", eventData: "[DONE]") {
                                    continuation.yield(doneEvent)
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

            // 2) Watchdog task for inactivity
            let watchdogTask = Task {
                guard let timeout = inactivityTimeout else { return }
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                    let elapsed = await Date().timeIntervalSince(eventTracker.getLastEventTime())
                    if elapsed > timeout {
                        eventReadingTask.cancel()
                        continuation.finish(throwing: SSEStreamError.timeout(timeout))
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
}

/// Errors specific to SSE streaming
enum SSEStreamError: Error {
    case timeout(TimeInterval)
    case invalidResponse(Int)
    case parsingError(String)
}
