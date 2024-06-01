//
//  File.swift
//  
//
//  Created by Kenneth Dubroff on 3/22/24.
//

import Foundation

typealias ListAssistantsRequest = EmptyEncodableRequest
struct ListAssistantsResponse: DecodableResponse {
    public let firstId: String
    public let lastId: String
    public let hasMore: Bool
    let data: [Assistant]
}

public struct Assistant: Codable, Equatable {
    public let id: String
    public let name: String
    public let description: String?
    public let model: String
    public let instructions: String?

    public init(id: String, name: String, description: String?, model: String, instructions: String?) {
        self.id = id
        self.name = name
        self.description = description
        self.model = model
        self.instructions = instructions
    }
}
