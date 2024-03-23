//
//  File.swift
//  
//
//  Created by Kenneth Dubroff on 3/22/24.
//

import Foundation

struct ListAssistantsRequest: EncodableRequest {}
struct ListAssistantsResponse: DecodableResponse {
    let data: [Assistant]
}

public struct Assistant: Codable {
    let id: String
    let name: String
    let description: String?
    let model: String
    let instructions: String
}
