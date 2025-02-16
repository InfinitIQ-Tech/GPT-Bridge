//
//  RunHandler.swift
//  GPTBridge
//
//  Created by Kenneth Dubroff on 12/16/23.
//

import Foundation

protocol RunHandler {
    /// The run's response, decoded
    var runThreadResponse: RunThreadResponse { get }
    /// Handle the run - implemented differently for different handlers
    func handle() async throws
}

public protocol RunStepResult: Decodable {
    var functions: [AssistantFunction]? { get }
    var message: String? { get }
}

public struct FunctionRunStepResult: RunStepResult {
    public let toolCallId: String
    public let functions: [AssistantFunction]?
    public let message: String?

    init(toolCallId: String, functions: [AssistantFunction], message: String? = nil) {
        self.toolCallId = toolCallId
        self.functions = functions
        self.message = message
    }
}

public struct MessageRunStepResult: RunStepResult {
    public var functions: [AssistantFunction]? = nil
    public var message: String?

    public init(message: String) {
        self.message = message
    }
}
