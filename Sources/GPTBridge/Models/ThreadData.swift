//
//  Thread.swift
//  SlackMojiChef
//
//  Created by Kenneth Dubroff on 12/9/23.
//

import Foundation

/// JSON payload including the thread's ID
struct CreateThreadResponse: DecodableResponse {
    let id: String
}

/// headers for creating threads
struct CreateThreadRequest: EncodableRequest {}
