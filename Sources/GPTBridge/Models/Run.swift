//
//  Run.swift
//  SlackMojiChef
//
//  Created by Kenneth Dubroff on 12/9/23.
//

import Foundation

/// Wrapper struct for `Decodable`
///
/// Decodes input data into various concrete types, and if successful, stores the value as
/// an `Any` type.
///
/// Example usage:
/// ```swift
/// let jsonData = ... // Some JSON data as Data
/// let decoder = JSONDecoder()
/// let anyDecodable = try decoder.decode(AnyDecodable.self, from: jsonData)
/// ```
///
/// Then, the underlying value can be accessed and cast to the expected type:
/// ```swift
/// if let intValue = anyDecodable.value as? Int {
///     print("Decoded integer: \(intValue)")
/// }
/// ```
///
/// - Note: This struct only tries to decode the data into `Bool`, `Int`, `Double`, `String`, `Array<AnyDecodable>`,
/// and `Dictionary<String, AnyDecodable>`.
/// - Throws: `DecodingError.dataCorruptedError` when types aren't implemented.
public struct AnyDecodable: Decodable {
    let value: Any

    public init<T>(_ value: T?) {
        self.value = value ?? ()
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let value = try? container.decode(Bool.self) {
            self.init(value)
        } else if let value = try? container.decode(Int.self) {
            self.init(value)
        } else if let value = try? container.decode(Double.self) {
            self.init(value)
        } else if let value = try? container.decode(String.self) {
            self.init(value)
        } else if let value = try? container.decode([AnyDecodable].self) {
            self.init(value)
        } else if let value = try? container.decode([String: AnyDecodable].self) {
            self.init(value)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode value")
        }
    }
}

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

public struct AssistantFunction: DecodableResponse {
    public let name: String
    public let arguments: [String: AnyDecodable]

    private enum CodingKeys: String, CodingKey {
        case name, arguments
    }

    enum Error: Swift.Error {
        case stringDataNotValidJSON(decodingError: DecodingError)
    }

    init(name: String, arguments: [String: AnyDecodable]) {
        self.name = name
        self.arguments = arguments
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        // arguments come back as a String formatted as an objec rather than direct object
        let argumentsString = try container.decode(String.self, forKey: .arguments)
        
        guard let data = argumentsString.data(using: .utf8) else {
            let decodingError = DecodingError.dataCorruptedError(forKey: .arguments, in: container, debugDescription: "Cannot convert argument String to Data")
            print("Decoding Error: \(decodingError)")
            throw Error.stringDataNotValidJSON(decodingError: decodingError)
        }

        arguments = try JSONDecoder().decode([String: AnyDecodable].self, from: data)
    }
}

/// headers for creating thread runs
struct RunThreadRequest: EncodableRequest {}
