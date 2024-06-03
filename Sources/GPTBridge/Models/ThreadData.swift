//
//  Thread.swift
//  SlackMojiChef
//
//  Created by Kenneth Dubroff on 12/9/23.
//

import Foundation

/// headers for creating threads
typealias CreateThreadRequest = EmptyEncodableRequest

/// JSON payload including the thread's ID
struct CreateThreadResponse: DecodableResponse {
    let id: String
}
