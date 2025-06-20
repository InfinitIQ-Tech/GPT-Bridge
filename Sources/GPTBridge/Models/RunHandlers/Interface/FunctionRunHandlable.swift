//
//  FunctionRunHandlable.swift
//
//
//  Created by Kenneth Dubroff on 2/27/24.
//

import Foundation

protocol FunctionRunHandlable: RunHandler {
    var requiredAction: RequiredAction? { get }
    func parse() throws -> [String: FunctionArgument]
    var functionParameters: [String: FunctionArgument]? { get }
}

extension FunctionRunHandlable {
    private var noActionRetrievedError: NSError {
        NSError(domain: "noActionRetrievedError", code: 0, userInfo: nil)
    }
    /// Parse `RequiredAction` to retrieve function calls (`ToolCall`)
    /// - throws: `noActionRetrievedError` if `requiredAction` is nil or there are no function calls
    /// - returns: [ToolCall.id: FunctionArgument]
    func parse() throws -> [String: FunctionArgument] {
       guard let action = requiredAction,
             action.submitToolOutputs.toolCalls.count > 0
       else {
           throw noActionRetrievedError
       }
return action.submitToolOutputs.toolCalls.reduce(into: [:]) { partialResult, toolCall in
    partialResult[toolCall.id] = toolCall.function.arguments
}
    }
}
