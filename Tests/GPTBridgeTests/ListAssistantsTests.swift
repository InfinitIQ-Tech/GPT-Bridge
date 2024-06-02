//
//  ListAssistantsTests.swift
//
//
//  Created by Kenneth Dubroff on 3/24/24.
//

import XCTest
@testable import GPTBridge

class ListAssistantsTests: XCTestCase {
    private var testAssistant1: Assistant {
        Assistant(id: "asst_abc123", name: "Coding Tutor", description: nil, model: "gpt-4-turbo", instructions: "You are a helpful assistant designed to make me better at coding!")
    }

    private var testAssistant2: Assistant {
        Assistant(id: "asst_abc456", name: "My Assistant", description: nil, model: "gpt-4-turbo", instructions: "You are a helpful assistant designed to make me better at coding!")
    }

    private var assistantJSONString: String {
        """
        {
          "id": "\(testAssistant1.id)",
          "name": "\(testAssistant1.name)",
          "description": null,
          "model": "\(testAssistant1.model)",
          "instructions": "\(testAssistant1.instructions!)"
        }
        """
    }

    var testResponse: ListAssistantsResponse {
        ListAssistantsResponse(
            firstId: "asst_abc123",
            lastId: "asst_abc789",
            hasMore: false,
            data: [testAssistant1, testAssistant1]
        )
    }

    private var listAssistantsReponseJSONString: String {
        """
        {
          "object": "list",
          "data": [
            {
              "id": "asst_abc123",
              "object": "assistant",
              "created_at": 1698982736,
              "name": "Coding Tutor",
              "description": null,
              "model": "gpt-4-turbo",
              "instructions": "You are a helpful assistant designed to make me better at coding!",
              "tools": [],
              "tool_resources": {},
              "metadata": {},
              "top_p": 1.0,
              "temperature": 1.0,
              "response_format": "auto"
            },
            {
              "id": "asst_abc456",
              "object": "assistant",
              "created_at": 1698982718,
              "name": "My Assistant",
              "description": null,
              "model": "gpt-4-turbo",
              "instructions": "You are a helpful assistant designed to make me better at coding!",
              "tools": [],
              "tool_resources": {},
              "metadata": {},
              "top_p": 1.0,
              "temperature": 1.0,
              "response_format": "auto"
            }
          ],
          "first_id": "asst_abc123",
          "last_id": "asst_abc789",
          "has_more": false
        }
        """
    }

    func testAssistants_areDecodable() throws {
        let decodedAssistant = try toInstance(from: assistantJSONString, to: Assistant.self)
        XCTAssertEqual(decodedAssistant, testAssistant1)
    }

    func testAssistantsResponse_canBeDecoded() throws {
        let decodedResponse = try toInstance(from: listAssistantsReponseJSONString, to: ListAssistantsResponse.self)
        XCTAssertEqual(decodedResponse.firstId, testResponse.firstId)
        XCTAssertEqual(decodedResponse.lastId, testResponse.lastId)
        XCTAssertFalse(decodedResponse.hasMore)
        XCTAssertEqual(decodedResponse.data[0], testAssistant1)
        XCTAssertEqual(decodedResponse.data[1], testAssistant2)
    }
}
