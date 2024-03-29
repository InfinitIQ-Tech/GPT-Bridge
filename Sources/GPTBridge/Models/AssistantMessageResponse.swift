//
//  AssistantMessageResponse.swift
//  SlackMojiChef
//
//  Created by Kenneth Dubroff on 12/16/23.
//

import Foundation

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
    let messageCreation: MessageCreation
}

struct GetMessageResponse: DecodableResponse {
    let stepDetails: StepDetails
}

struct MessageResponse: DecodableResponse {
    let data: [GetMessageResponse]
}

/// headers for Messages
struct AddMessageToThreadResponse: DecodableResponse {}
struct CancelRunRequest: EncodableRequest {}
struct CancelRunResponse: DecodableResponse {}
struct MessageIdRequest: EncodableRequest {}
struct MessageTextRequest: EncodableRequest {}

