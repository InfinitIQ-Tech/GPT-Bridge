//
//  RunHandler.swift
//  SlackMojiChef
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

public protocol RunStepResult {
    var functions: [AssistantFunction]? { get }
    var message: String? { get }
}

struct FunctionRunStepResult: RunStepResult {
    var functions: [AssistantFunction]?
    var message: String? = nil

    init(functions: [AssistantFunction]) {
        self.functions = functions
    }
}

struct MessageRunStepResult: RunStepResult {
    var functions: [AssistantFunction]? = nil
    var message: String?

    init(message: String) {
        self.message = message
    }
}
