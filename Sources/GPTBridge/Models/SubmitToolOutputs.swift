//
//  File.swift
//  
//
//  Created by Kenneth Dubroff on 4/5/24.
//

import Foundation

struct ToolCallRequest: EncodableRequest {
    let toolOutputs: [ToolCallOutput]
}

public struct ToolCallOutput: Encodable {
    /// the tool call ID returned in the `FunctionRunStepHandler` result
    public let toolCallId: String
    /// the result back to the model
    public let output: String
}
