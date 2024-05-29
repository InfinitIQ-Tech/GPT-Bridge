//
//  File.swift
//  
//
//  Created by Kenneth Dubroff on 4/6/24.
//

@testable import GPTBridge
import XCTest

class SubmitToolCallTests: XCTestCase {
    private let testToolCallOutput = ToolCallOutput(toolCallId: "1", output: "Test")
    private var testToolCallOutputJSONString: String {
        """
        {
          "tool_call_id": "1",
          "output": "Test"
        }
        """
    }

    func testEncodedToolCallOutputs_areEqual() throws {
        // test decoding returns equatable instance
        let testInstance = try XCTUnwrap(
            toInstance(
                from: testToolCallOutputJSONString,
                to: ToolCallOutput.self
            )
        )
        XCTAssertEqual(testToolCallOutput, testInstance)
    }

    func testToolCallOutputResponse_canBeDecoded() throws {
        let testInstance = try XCTUnwrap(
            toInstance(
                from: runThreadResponseJSONString,
                to: RunThreadResponse.self
            )
        )
    }
}

extension ToolCallOutput: Decodable {
    enum CodingKeys: String, CodingKey {
        case toolCallId
        case output
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let toolCallId = try container.decode(String.self, forKey: .toolCallId)
        let output = try container.decode(String.self, forKey: .output)
        self.init(toolCallId: toolCallId, output: output)
    }
}

extension ToolCallOutput: Equatable {
    public static func == (lhs: ToolCallOutput, rhs: ToolCallOutput) -> Bool {
        lhs.toolCallId == rhs.toolCallId &&
        lhs.output == rhs.output
    }
}

extension XCTestCase {
    var runThreadResponseJSONString: String {
        """
          {
            "id": "run_123",
            "object": "thread.run",
            "created_at": 1699075592,
            "assistant_id": "asst_123",
            "thread_id": "thread_123",
            "status": "queued",
            "started_at": 1699075592,
            "expires_at": 1699076192,
            "cancelled_at": null,
            "failed_at": null,
            "completed_at": null,
            "last_error": null,
            "model": "gpt-4-turbo",
            "instructions": null,
            "tools": [
              {
                "type": "function",
                "function": {
                  "name": "get_current_weather",
                  "description": "Get the current weather in a given location",
                  "parameters": {
                    "type": "object",
                    "properties": {
                      "location": {
                        "type": "string",
                        "description": "The city and state, e.g. San Francisco, CA"
                      },
                      "unit": {
                        "type": "string",
                        "enum": ["celsius", "fahrenheit"]
                      }
                    },
                    "required": ["location"]
                  }
                }
              }
            ],
            "metadata": {},
            "usage": null,
            "temperature": 1.0,
            "top_p": 1.0,
            "max_prompt_tokens": 1000,
            "max_completion_tokens": 1000,
            "truncation_strategy": {
              "type": "auto",
              "last_messages": null
            },
            "response_format": "auto",
            "tool_choice": "auto"
          }
        """
    }
}
