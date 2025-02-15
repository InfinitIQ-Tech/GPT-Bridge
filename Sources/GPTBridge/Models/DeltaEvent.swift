//
//  DeltaEvent.swift
//  GPTBridge
//
//  Created by Kenneth Dubroff on 2/10/25.
//


import Foundation

public struct DeltaEvent: Codable {
    public let id: String
    public let object: String
    public let delta: Delta
}

public struct Delta: Codable {
    public let content: [Content]
}

public struct Content: Codable {
    public let index: Int
    public let type: String
    public let text: Text
}

public struct Text: Codable {
    public let value: String
    public let annotations: [String]?
}
