//
//  RetrieveAssistantMessageTests.swift
//
//
//  Created by Kenneth Dubroff on 5/28/24.
//

import XCTest
@testable import GPTBridge

class RetrieveAssistantMessageTests: XCTestCase {
    var testMessageResponse: MessageResponse {
        let stepDetails = StepDetails(messageCreation: MessageCreation(messageId: "msg_abc123"), toolCalls: nil)
        return MessageResponse(data: [GetMessageResponse(stepDetails: stepDetails)])
    }

    var stepDetailsJSONString: String {
        """
          {
            "object": "list",
            "data": [
              {
                "id": "step_abc123",
                "object": "thread.run.step",
                "created_at": 1699063291,
                "run_id": "run_abc123",
                "assistant_id": "asst_abc123",
                "thread_id": "thread_abc123",
                "type": "message_creation",
                "status": "completed",
                "cancelled_at": null,
                "completed_at": 1699063291,
                "expired_at": null,
                "failed_at": null,
                "last_error": null,
                "step_details": {
                  "type": "message_creation",
                  "message_creation": {
                    "message_id": "msg_abc123"
                  }
                },
                "usage": {
                  "prompt_tokens": 123,
                  "completion_tokens": 456,
                  "total_tokens": 579
                }
              }
            ],
            "first_id": "step_abc123",
            "last_id": "step_abc456",
            "has_more": false
          }
        """
    }

    func testCanDecode_messageResponse_toRetrieveMessageId() throws {
        let instance = try XCTUnwrap(
            toInstance(from: stepDetailsJSONString, to: MessageResponse.self)
        )

        XCTAssertEqual(instance.data.first?.stepDetails.messageCreation?.messageId, testMessageResponse.data.first?.stepDetails.messageCreation?.messageId)
    }

    func canDecode_messageContent() {
        
    }
}
