//
//  Run.swift
//  SlackMojiChef
//
//  Created by Kenneth Dubroff on 12/9/23.
//

import Foundation

/// Headers and JSON body for creating thread runs
struct CreateThreadRunRequest: EncodableRequest {
    var assistantId: String = Environment.assistantKey
}

/// JSON body for AI function/tool usage
struct RequiredAction: DecodableResponse {
    let type: String
    let submitToolOutputs: ToolOutputs
}

/// The thread run's JSON Body
struct RunThreadResponse: DecodableResponse {
    enum Status: String, Decodable {
        case queued
        case inProgress = "in_progress"
        case completed
        case expired
        case requiresAction = "requires_action"
        case failed
        case cancelling
        case cancelled
    }


    let id: String
    let status: Status
    let lastError: String?
//    let fileIds: [String]?
    let requiredAction: RequiredAction?
}

// MARK: Tools

/// Contains assistant function run results
struct ToolOutputs: DecodableResponse {
    let toolCalls: [ToolCall]
}

struct ToolCall: DecodableResponse {
    let id: String
    let type: String
    let function: AssistantFunction
}

struct AssistantFunction: DecodableResponse {
    let name: String
    let arguments: DallE3FunctionArguments

    private enum CodingKeys: String, CodingKey {
        case name, arguments
    }

    enum Error: Swift.Error {
        case stringDataNotValidJSON(decodingError: DecodingError)
    }

    init(name: String, arguments: DallE3FunctionArguments) {
        self.name = name
        self.arguments = arguments
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        // arguments come back as a String formatted as an objec rather than direct object
        let argumentsString = try container.decode(String.self, forKey: .arguments)
        guard let data = argumentsString.data(using: .utf8) else {
            let decodingError = DecodingError.dataCorruptedError(forKey: .arguments, in: container, debugDescription: "Cannot convert argument String to Data")
            print("Decoding Error: \(decodingError)")
            throw Error.stringDataNotValidJSON(decodingError: decodingError)
        }

        arguments = try JSONDecoder().decode(DallE3FunctionArguments.self, from: data)
    }
}

/// headers for creating thread runs
struct RunThreadRequest: EncodableRequest {}
