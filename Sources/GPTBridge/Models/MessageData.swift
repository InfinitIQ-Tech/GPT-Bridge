//
//  MessageData.swift
//  GPTBridge
//
//  Created by Kenneth Dubroff on 12/9/23.
//

import Foundation
/// The role of the message sender
public enum Role: String, EncodableRequest, Decodable {
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

public struct ChatThread {
    public let thread: Thread
}

public struct Thread: Codable {
    public var messages: [ChatMessage] = []

    public init(messages: [ChatMessage]) {
        self.messages = messages
    }
}

public struct ChatMessage: Codable, OpenAIMessageable, Identifiable {
    public let id: String
    public var content: String
    public var role: Role

    public init(from decoder: any Decoder) throws {
        self.id = UUID().uuidString
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.content = try container.decode(String.self, forKey: .content)
        self.role = try container.decode(Role.self, forKey: .role)
    }

    public init(content: String, role: Role = .user) {
        self.id = UUID().uuidString
        self.content = content
        self.role = role
    }
}

