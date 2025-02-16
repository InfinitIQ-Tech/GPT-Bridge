//
//  AssistantMessageResponse.swift
//  GPTBridge
//
//  Created by Kenneth Dubroff on 12/16/23.
//

import Foundation

typealias CancelRunRequest = EmptyEncodableRequest
typealias CancelRunResponse = EmptyDecodableResponse
typealias MessageIdRequest = EmptyEncodableRequest
typealias MessageTextRequest = EmptyEncodableRequest

struct MessageContent: DecodableResponse {
    let content: [MessageTextObject]
}

struct MessageTextObject: DecodableResponse {
    let text: MessageValue
}

struct MessageValue: DecodableResponse {
    let value: String
}

struct MessageCreation: DecodableResponse {
    let messageId: String
}

struct StepDetails: DecodableResponse {
    let messageCreation: MessageCreation?
    let toolCalls: [ToolCall]?
}

struct GetMessageResponse: DecodableResponse {
    let stepDetails: StepDetails
}

struct MessageResponse: DecodableResponse {
    var data: [GetMessageResponse]
}

/// headers for Messages
struct AddMessageToThreadResponse: DecodableResponse {
    let id: String
    let content: [MessageTextObject]
}
