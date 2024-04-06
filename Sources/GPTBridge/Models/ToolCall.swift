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

struct ToolCallOutput: Encodable {
    let toolCallId: String
    let outputDictionary: [String: FunctionArgument]

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: DynamicCodingKey.self)

        try container.encode(toolCallId, forKey: DynamicCodingKey(stringValue: "tool_call_id")!)

        for (key, value) in outputDictionary {
            let key = DynamicCodingKey(stringValue: key)!
            try value.encode(to: container.superEncoder(forKey: key))
        }

    }
}

// DynamicCodingKey is used to encode dictionary keys dynamically.
struct DynamicCodingKey: CodingKey {
    var stringValue: String
    var intValue: Int?

    init?(stringValue: String) {
        self.stringValue = stringValue
        intValue = nil
    }

    init?(intValue: Int) {
        self.intValue = intValue
        stringValue = "\(intValue)"
    }
}
