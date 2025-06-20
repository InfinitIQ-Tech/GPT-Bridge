//
//  ThreadResponseTests.swift
//
//
//  Created by Kenneth Dubroff on 5/28/24.
//

import XCTest
@testable import GPTBridge

class ThreadResponseTests: XCTestCase {
    private var testThreadResponse: CreateThreadResponse {
        CreateThreadResponse(id: "thread_abc123")
    }

    private var testThreadResponseJSONString: String {
        """
          {
            "id": "thread_abc123",
            "object": "thread",
            "created_at": 1699012949,
            "metadata": {},
            "tool_resources": {}
          }
        """
    }

    func testCanDecode_threadResponse() throws {
        let testInstance = try XCTUnwrap(
            toInstance(
                from: testThreadResponseJSONString,
                to: CreateThreadResponse.self
            )
        )

        XCTAssertEqual(testInstance.id, testThreadResponse.id)
    }

}
