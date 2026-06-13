//
//  ChatCompletionsTests.swift
//
//
//  Created by Kenneth Dubroff on 5/11/26.
//

import XCTest
@testable import GPTBridge

class ChatCompletionsTests: XCTestCase {
    func testCompletionsEndpoint_makesChatCompletionsURL() throws {
        let endpoint = CompletionsEndpoint.chatCompletions
        let spy = RequestManagerSpy(mockRequest: nil)
        let testURL = spy.makeURL(fromEndpoint: endpoint)

        XCTAssertEqual(testURL.absoluteString, "https://api.openai.com/v1/chat/completions")
    }

    func testCompletionsEndpoint_doesNotUseAssistantsBetaHeader() {
        XCTAssertNil(CompletionsEndpoint.chatCompletions.additionalHeaders["OpenAI-Beta"])
        XCTAssertEqual(AssistantEndpoint.threads.additionalHeaders["OpenAI-Beta"], "assistants=v2")
    }

    func testChatCompletionRequest_encodesMessagesAndTools() throws {
        let request = ChatCompletionRequest(
            model: "test-model",
            messages: [
                ChatCompletionMessage(role: .system, content: "You are concise."),
                ChatCompletionMessage(role: .user, content: "What is the weather?")
            ],
            tools: [
                ChatCompletionTool(
                    function: ChatCompletionFunctionDefinition(
                        name: "get_current_weather",
                        description: "Get the current weather",
                        parameters: [
                            "type": FunctionArgument("object"),
                            "properties": FunctionArgument([
                                "location": FunctionArgument([
                                    "type": FunctionArgument("string")
                                ])
                            ]),
                            "required": FunctionArgument(["location"])
                        ]
                    )
                )
            ],
            toolChoice: .auto,
            temperature: 0.2,
            maxCompletionTokens: 100
        )

        let data = try request.encodeInstance()
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])

        XCTAssertEqual(object["model"] as? String, "test-model")
        XCTAssertEqual(object["tool_choice"] as? String, "auto")
        XCTAssertEqual(object["temperature"] as? Double, 0.2)
        XCTAssertEqual(object["max_completion_tokens"] as? Int, 100)

        let messages = try XCTUnwrap(object["messages"] as? [[String: Any]])
        XCTAssertEqual(messages[0]["role"] as? String, "system")
        XCTAssertEqual(messages[0]["content"] as? String, "You are concise.")
        XCTAssertEqual(messages[1]["role"] as? String, "user")

        let tools = try XCTUnwrap(object["tools"] as? [[String: Any]])
        XCTAssertEqual(tools[0]["type"] as? String, "function")
        let function = try XCTUnwrap(tools[0]["function"] as? [String: Any])
        XCTAssertEqual(function["name"] as? String, "get_current_weather")
    }

    func testChatCompletionRequest_canForceNonStreamingPayload() throws {
        let request = ChatCompletionRequest(
            model: "test-model",
            messages: [
                ChatCompletionMessage(role: .user, content: "Hello")
            ],
            stream: true
        )

        let data = try request.withStream(false).encodeInstance()
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])

        XCTAssertEqual(object["stream"] as? Bool, false)
    }

    func testChatCompletionToolCall_exposesChatCompletionFunctionType() {
        let function = ChatCompletionFunction(
            name: "get_current_weather",
            arguments: ["location": FunctionArgument("San Francisco, CA")]
        )

        let toolCall = ChatCompletionToolCall(id: "call_abc123", function: function)

        XCTAssertEqual(toolCall.function.name, "get_current_weather")
        XCTAssertEqual(toolCall.function.arguments["location"]?.asString, "San Francisco, CA")
    }

    func testChatCompletionResponse_canDecodeMessageResult() throws {
        let response = try toInstance(from: chatCompletionMessageJSONString, to: ChatCompletionResponse.self)

        XCTAssertEqual(response.id, "chatcmpl_abc123")
        XCTAssertEqual(response.choices.first?.message.content, "Hello from chat completions.")
        XCTAssertEqual(response.runStepResult.message, "Hello from chat completions.")
        XCTAssertNil(response.runStepResult.functions)
    }

    func testChatCompletionResponse_canDecodeToolCallsAsFunctionResult() throws {
        let response = try toInstance(from: chatCompletionToolCallJSONString, to: ChatCompletionResponse.self)
        let result = try XCTUnwrap(response.runStepResult as? FunctionRunStepResult)

        XCTAssertEqual(result.toolCallId, "call_abc123")
        XCTAssertEqual(result.functions?.first?.name, "get_current_weather")
        XCTAssertEqual(result.functions?.first?.arguments["location"]?.asString, "San Francisco, CA")
    }

    func testChatCompletionStreamChunk_decodesContentDelta() throws {
        let chunk = try toInstance(from: chatCompletionStreamChunkJSONString, to: ChatCompletionChunk.self)

        XCTAssertEqual(chunk.choices.first?.delta.content, "Hel")
    }

    private var chatCompletionMessageJSONString: String {
        """
        {
          "id": "chatcmpl_abc123",
          "object": "chat.completion",
          "created": 1710000000,
          "model": "test-model",
          "choices": [
            {
              "index": 0,
              "message": {
                "role": "assistant",
                "content": "Hello from chat completions."
              },
              "finish_reason": "stop"
            }
          ],
          "usage": {
            "prompt_tokens": 12,
            "completion_tokens": 4,
            "total_tokens": 16
          }
        }
        """
    }

    private var chatCompletionToolCallJSONString: String {
        """
        {
          "id": "chatcmpl_tool123",
          "object": "chat.completion",
          "created": 1710000000,
          "model": "test-model",
          "choices": [
            {
              "index": 0,
              "message": {
                "role": "assistant",
                "content": null,
                "tool_calls": [
                  {
                    "id": "call_abc123",
                    "type": "function",
                    "function": {
                      "name": "get_current_weather",
                      "arguments": "{\\"location\\":\\"San Francisco, CA\\"}"
                    }
                  }
                ]
              },
              "finish_reason": "tool_calls"
            }
          ],
          "usage": null
        }
        """
    }

    private var chatCompletionStreamChunkJSONString: String {
        """
        {
          "id": "chatcmpl_abc123",
          "object": "chat.completion.chunk",
          "created": 1710000000,
          "model": "test-model",
          "choices": [
            {
              "index": 0,
              "delta": {
                "role": "assistant",
                "content": "Hel"
              },
              "finish_reason": null
            }
          ],
          "usage": null
        }
        """
    }
}
