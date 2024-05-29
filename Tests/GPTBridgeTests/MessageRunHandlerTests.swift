//
//  File.swift
//  
//
//  Created by Kenneth Dubroff on 5/28/24.
//

import XCTest
@testable import GPTBridge

class MessageRunHandlerTests: XCTestCase {
    private var testMessageContent: MessageContent {
        MessageContent(content: [MessageTextObject(text: MessageValue(value: "How does AI work? Explain it in simple terms."))])
    }

    private var testMessageContentResponseJSONString: String {
        """
          {
            "id": "msg_abc123",
            "object": "thread.message",
            "created_at": 1699017614,
            "assistant_id": null,
            "thread_id": "thread_abc123",
            "run_id": null,
            "role": "user",
            "content": [
              {
                "type": "text",
                "text": {
                  "value": "How does AI work? Explain it in simple terms.",
                  "annotations": []
                }
              }
            ],
            "attachments": [],
            "metadata": {}
          }
        """
    }

    func testMessageContent_canBeDecodedFromResponse() throws {
        let testInstance = try XCTUnwrap(
            toInstance(from: testMessageContentResponseJSONString, to: MessageContent.self)
        )
        XCTAssertEqual(testInstance, testMessageContent)
    }
}

extension MessageContent: Equatable {
    public static func == (lhs: MessageContent, rhs: MessageContent) -> Bool {
        lhs.content.first?.text.value == rhs.content.first?.text.value
    }
}
