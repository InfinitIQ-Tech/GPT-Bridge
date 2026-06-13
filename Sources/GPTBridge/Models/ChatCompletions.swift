//
//  ChatCompletions.swift
//  GPTBridge
//
//  Created by Kenneth Dubroff on 5/11/26.
//

import Foundation

public struct ChatCompletionRequest: EncodableRequest {
    public let model: String
    public let messages: [ChatCompletionMessage]
    public let tools: [ChatCompletionTool]?
    public let toolChoice: ChatCompletionToolChoice?
    public let temperature: Double?
    public let maxCompletionTokens: Int?
    public let stream: Bool?

    public init(
        model: String,
        messages: [ChatCompletionMessage],
        tools: [ChatCompletionTool]? = nil,
        toolChoice: ChatCompletionToolChoice? = nil,
        temperature: Double? = nil,
        maxCompletionTokens: Int? = nil,
        stream: Bool? = nil
    ) {
        self.model = model
        self.messages = messages
        self.tools = tools
        self.toolChoice = toolChoice
        self.temperature = temperature
        self.maxCompletionTokens = maxCompletionTokens
        self.stream = stream
    }

    func withStream(_ stream: Bool) -> ChatCompletionRequest {
        ChatCompletionRequest(
            model: model,
            messages: messages,
            tools: tools,
            toolChoice: toolChoice,
            temperature: temperature,
            maxCompletionTokens: maxCompletionTokens,
            stream: stream
        )
    }
}

public struct ChatCompletionMessage: Codable, Identifiable {
    public let id: String
    public let role: Role
    public let content: String?
    public let name: String?
    public let toolCallId: String?
    public let toolCalls: [ChatCompletionToolCall]?

    enum CodingKeys: String, CodingKey {
        case role
        case content
        case name
        case toolCallId
        case toolCalls
    }

    public init(
        role: Role,
        content: String?,
        name: String? = nil,
        toolCallId: String? = nil,
        toolCalls: [ChatCompletionToolCall]? = nil
    ) {
        self.id = UUID().uuidString
        self.role = role
        self.content = content
        self.name = name
        self.toolCallId = toolCallId
        self.toolCalls = toolCalls
    }

    public static func toolOutput(toolCallId: String, output: String) -> ChatCompletionMessage {
        ChatCompletionMessage(role: .tool, content: output, toolCallId: toolCallId)
    }

    public init(from decoder: any Decoder) throws {
        self.id = UUID().uuidString
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.role = try container.decode(Role.self, forKey: .role)
        self.content = try container.decodeIfPresent(String.self, forKey: .content)
        self.name = try container.decodeIfPresent(String.self, forKey: .name)
        self.toolCallId = try container.decodeIfPresent(String.self, forKey: .toolCallId)
        self.toolCalls = try container.decodeIfPresent([ChatCompletionToolCall].self, forKey: .toolCalls)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(role, forKey: .role)
        try container.encodeIfPresent(content, forKey: .content)
        try container.encodeIfPresent(name, forKey: .name)
        try container.encodeIfPresent(toolCallId, forKey: .toolCallId)
        try container.encodeIfPresent(toolCalls, forKey: .toolCalls)
    }
}

public struct ChatCompletionTool: Codable {
    public let type: String
    public let function: ChatCompletionFunctionDefinition

    public init(function: ChatCompletionFunctionDefinition, type: String = "function") {
        self.type = type
        self.function = function
    }
}

public struct ChatCompletionFunctionDefinition: Codable {
    public let name: String
    public let description: String?
    public let parameters: [String: FunctionArgument]?
    public let strict: Bool?

    public init(
        name: String,
        description: String? = nil,
        parameters: [String: FunctionArgument]? = nil,
        strict: Bool? = nil
    ) {
        self.name = name
        self.description = description
        self.parameters = parameters
        self.strict = strict
    }
}

public enum ChatCompletionToolChoice: String, Codable {
    case none
    case auto
    case required
}

public typealias ChatCompletionFunction = AssistantFunction

public struct ChatCompletionToolCall: Codable {
    public let id: String
    public let type: String
    public let function: ChatCompletionFunction

    public init(id: String, type: String = "function", function: ChatCompletionFunction) {
        self.id = id
        self.type = type
        self.function = function
    }
}

public struct ChatCompletionResponse: DecodableResponse {
    public let id: String
    public let object: String?
    public let created: Int?
    public let model: String
    public let choices: [ChatCompletionChoice]
    public let usage: ChatCompletionUsage?

    public var runStepResult: RunStepResult {
        guard let message = choices.first?.message else {
            return MessageRunStepResult(message: "")
        }

        if let toolCalls = message.toolCalls,
           !toolCalls.isEmpty {
            return FunctionRunStepResult(
                toolCallId: toolCalls[0].id,
                functions: toolCalls.map(\.function),
                message: message.content
            )
        }

        return MessageRunStepResult(message: message.content ?? "")
    }
}

public struct ChatCompletionChoice: Decodable {
    public let index: Int
    public let message: ChatCompletionMessage
    public let finishReason: String?
}

public struct ChatCompletionUsage: Decodable {
    public let promptTokens: Int
    public let completionTokens: Int
    public let totalTokens: Int
}

public struct ChatCompletionChunk: DecodableResponse {
    public let id: String
    public let object: String?
    public let created: Int?
    public let model: String?
    public let choices: [ChatCompletionChunkChoice]
    public let usage: ChatCompletionUsage?
}

public struct ChatCompletionChunkChoice: Decodable {
    public let index: Int
    public let delta: ChatCompletionDelta
    public let finishReason: String?
}

public struct ChatCompletionDelta: Decodable {
    public let role: Role?
    public let content: String?
    public let toolCalls: [ChatCompletionToolCallDelta]?
}

public struct ChatCompletionToolCallDelta: Decodable {
    public let index: Int
    public let id: String?
    public let type: String?
    public let function: ChatCompletionFunctionDelta?
}

public struct ChatCompletionFunctionDelta: Decodable {
    public let name: String?
    public let arguments: String?
}

public enum ChatCompletionStreamEvent {
    case contentDelta(String)
    case toolCallDelta(ChatCompletionToolCallDelta)
    case finished(String?)
    case errorOccurred(OpenAIJSONError)
    case done
    case unknown(data: String)
}
