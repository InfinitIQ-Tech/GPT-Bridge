//
//  DeltaEvent.swift
//  GPTBridge
//
//  Created by Kenneth Dubroff on 2/10/25.
//


import Foundation

public struct MessageDeltaEvent: Codable {
    public let id: String
    public let object: String
    public let delta: MessageDelta
}

public struct MessageDelta: Codable {
    public let content: [MessageDeltaContent]
}

public struct MessageDeltaContent: Codable {
    public let index: Int
    public let type: String
    public let text: MessageDeltaText
}

public struct MessageDeltaText: Codable {
    public let value: String
    public let annotations: [String]?
}
