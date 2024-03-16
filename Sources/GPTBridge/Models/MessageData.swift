//
//  File.swift
//  SlackMojiChef
//
//  Created by Kenneth Dubroff on 12/9/23.
//

import Foundation
/// The role of the message sender
public enum Role: String, EncodableRequest {
    case user
    case assistant
}
/// Headers and JSON body for adding a message to a thread
struct AddMessageToThreadRequest: EncodableRequest, OpenAIMessageable {
    let role: Role
    let content: String
    
    init(role: Role = .user, content: String) {
        self.role = role
        self.content = content
    }
}
