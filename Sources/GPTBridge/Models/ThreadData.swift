//
//  ThreadData.swift
//  GPTBridge
//
//  Created by Kenneth Dubroff on 12/9/23.
//

import Foundation

/// headers for creating threads
typealias CreateThreadRequest = EmptyEncodableRequest

struct CreateAndRunThreadRequest: EncodableRequest {
    let stream: Bool = true
    let thread: Thread
    let assistantId: String
}

/// JSON payload including the thread's ID
public struct CreateThreadResponse: DecodableResponse {
    public let id: String
}

