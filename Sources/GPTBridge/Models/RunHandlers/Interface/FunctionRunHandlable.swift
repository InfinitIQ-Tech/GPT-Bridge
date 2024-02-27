//
//  FunctionRunHandlable.swift
//
//
//  Created by Kenneth Dubroff on 2/27/24.
//

import Foundation

protocol FunctionRunHandlable: RunHandler {
    var requiredAction: RequiredAction? { get }
    func parse() throws -> [String: AnyDecodable]
    var functionParameters: [String: AnyDecodable]? { get }
}

extension FunctionRunHandlable {
    private var noActionRetrievedError: NSError {
        NSError(domain: "noActionRetrievedError", code: 0, userInfo: nil)
    }

    func parse() throws -> [String: AnyDecodable] {
       guard let action = requiredAction,
             action.submitToolOutputs.toolCalls.count > 0
       else {
           throw noActionRetrievedError
       }
       return action.submitToolOutputs.toolCalls[0].function.arguments // TODO: Generic arguments
    }
}
