//
//  FunctionArguments.swift
//  GPTBridge
//
//  Created by Kenneth Dubroff on 12/9/23.
//

import Foundation

/// JSON representation of assistant-generated arguments for generating Dall*E 3 images
struct DallE3FunctionArguments: DecodableResponse {
    let prompt: String
    let photoName: String

    enum CodingKeys: String, CodingKey {
        case prompt
        case photoName = "photo_name"
    }
}
