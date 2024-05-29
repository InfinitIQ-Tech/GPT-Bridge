//
//  File.swift
//  
//
//  Created by Kenneth Dubroff on 5/28/24.
//

import XCTest
@testable import GPTBridge

class MessageRunHandlerTests: XCTestCase {
    private var testMessageValue: MessageValue {
        MessageValue(value: "How does AI work? Explain it in simple terms.")
    }

    private var testMessageContent: MessageContent {
        MessageContent(content: [testMessageTextObject])
    }

    private var testMessageTextObject: MessageTextObject {
        MessageTextObject(text: testMessageValue)
    }

    private var addMessageToThreadResponse: AddMessageToThreadResponse {
        AddMessageToThreadResponse(id: "msg_abc123", content: testMessageContent.content)
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

    func testCreateMessageResponse_canBeDecoded() throws {
        let testInstance = try XCTUnwrap(
            toInstance(from: testMessageContentResponseJSONString, to: AddMessageToThreadResponse.self)
        )
        XCTAssertEqual(testInstance.content, testMessageContent.content)
        XCTAssertEqual(testInstance.id, addMessageToThreadResponse.id)
    }
}

extension MessageTextObject: Equatable {
    public static func == (lhs: MessageTextObject, rhs: MessageTextObject) -> Bool {
        lhs.text.value == rhs.text.value
    }
}
