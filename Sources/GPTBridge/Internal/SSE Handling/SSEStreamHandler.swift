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

    /// Event type to use when an SSE stream emits only data lines.
    var defaultEventType: String { get }

    /// Validates the HTTP response to ensure it's valid for streaming.
    func validateResponse(_ response: URLResponse, byteStream: URLSession.AsyncBytes) async throws

    /// Parses raw SSE event data into typed events.
    func parseEvents(eventType: String, eventData: String) -> [EventType]

    /// Optional typed event to yield before finishing on timeout.
    func timeoutEvent(timeout: TimeInterval) -> EventType?
}

/// Extension providing default implementation for the SSE streaming logic.
extension SSEStreamHandlable {
    var defaultEventType: String {
        "message"
    }

    func timeoutEvent(timeout: TimeInterval) -> EventType? {
        nil
    }

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

                    var eventParser = SSEEventLineParser<EventType>()

                    for try await rawLine in byteStream.linesPreservingEmpty() {
                        // Update last-event time on every line
                        await eventTracker.updateLastEventTime()

                        let events = eventParser.parseLine(
                            rawLine,
                            defaultEventType: defaultEventType,
                            parseEvents: parseEvents
                        )
                        for event in events {
                            continuation.yield(event)
                        }

                        if Task.isCancelled { break }
                    }

                    let remainingEvents = eventParser.flush(
                        defaultEventType: defaultEventType,
                        parseEvents: parseEvents
                    )
                    for event in remainingEvents {
                        continuation.yield(event)
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
                        if let timeoutEvent = timeoutEvent(timeout: timeout) {
                            continuation.yield(timeoutEvent)
                            continuation.finish()
                        } else {
                            continuation.finish(throwing: SSEStreamError.timeout(timeout))
                        }
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

struct SSEEventLineParser<EventType> {
    private var currentEventType: String? = nil
    private var eventDataBuffer = ""

    mutating func parseLine(
        _ rawLine: String,
        defaultEventType: String,
        parseEvents: (String, String) -> [EventType]
    ) -> [EventType] {
        let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)

        if line.hasPrefix("event:") {
            currentEventType = line
                .dropFirst("event:".count)
                .trimmingCharacters(in: .whitespaces)
            return []
        }

        if line.hasPrefix("data:") {
            let dataPart = line.dropFirst("data:".count)
            if !eventDataBuffer.isEmpty { eventDataBuffer.append("\n") }
            eventDataBuffer.append(contentsOf: dataPart)
            return []
        }

        if line.isEmpty {
            return flush(defaultEventType: defaultEventType, parseEvents: parseEvents)
        }

        return []
    }

    mutating func flush(
        defaultEventType: String,
        parseEvents: (String, String) -> [EventType]
    ) -> [EventType] {
        let trimmedData = eventDataBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
        defer {
            currentEventType = nil
            eventDataBuffer = ""
        }

        guard !trimmedData.isEmpty else {
            return []
        }

        let eventType = trimmedData == "[DONE]" ? "done" : currentEventType ?? defaultEventType
        return parseEvents(eventType, eventDataBuffer)
    }
}

/// Errors specific to SSE streaming
enum SSEStreamError: Error {
    case timeout(TimeInterval)
    case invalidResponse(Int)
    case parsingError(String)
}
