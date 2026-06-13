//
//  SSEEventLineParserTests.swift
//
//
//  Created by Kenneth Dubroff on 6/13/26.
//

import XCTest
@testable import GPTBridge

class SSEEventLineParserTests: XCTestCase {
    func testFlush_emitsBufferedDataWithoutTrailingBlankLine() {
        var parser = SSEEventLineParser<String>()

        let lineEvents = parser.parseLine("data: {\"message\":\"hello\"}", defaultEventType: "message") { eventType, eventData in
            ["\(eventType):\(eventData)"]
        }
        let flushedEvents = parser.flush(defaultEventType: "message") { eventType, eventData in
            ["\(eventType):\(eventData)"]
        }

        XCTAssertTrue(lineEvents.isEmpty)
        XCTAssertEqual(flushedEvents, ["message: {\"message\":\"hello\"}"])
    }

    func testParseLine_emitsDataOnlyEventOnBlankLine() {
        var parser = SSEEventLineParser<String>()

        _ = parser.parseLine("data: {\"message\":\"hello\"}", defaultEventType: "message") { eventType, eventData in
            ["\(eventType):\(eventData)"]
        }
        let events = parser.parseLine("", defaultEventType: "message") { eventType, eventData in
            ["\(eventType):\(eventData)"]
        }

        XCTAssertEqual(events, ["message: {\"message\":\"hello\"}"])
    }

    func testParseLine_preservesExplicitEventType() {
        var parser = SSEEventLineParser<String>()

        _ = parser.parseLine("event: thread.message.delta", defaultEventType: "message") { eventType, eventData in
            ["\(eventType):\(eventData)"]
        }
        _ = parser.parseLine("data: {}", defaultEventType: "message") { eventType, eventData in
            ["\(eventType):\(eventData)"]
        }
        let events = parser.parseLine("", defaultEventType: "message") { eventType, eventData in
            ["\(eventType):\(eventData)"]
        }

        XCTAssertEqual(events, ["thread.message.delta: {}"])
    }

    func testParseLine_treatsDoneMarkerAsDoneEvent() {
        var parser = SSEEventLineParser<String>()

        _ = parser.parseLine("data: [DONE]", defaultEventType: "message") { eventType, eventData in
            ["\(eventType):\(eventData)"]
        }
        let events = parser.parseLine("", defaultEventType: "message") { eventType, eventData in
            ["\(eventType):\(eventData)"]
        }

        XCTAssertEqual(events, ["done: [DONE]"])
    }
}
