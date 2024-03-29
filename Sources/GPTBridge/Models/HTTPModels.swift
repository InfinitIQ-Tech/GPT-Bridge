//
//  Models.swift
//  SlackMojiChef
//
//  Created by Kenneth Dubroff on 12/5/23.
//

import SwiftUI
/// HTTP Request Method
enum HttpMethod: String {
    case POST
    case GET
}

/// Endpoints for the OpenAI Assistants API
enum AssistantEndpoint {
    case threads
    case addMessage(threadId: String)
    case createRun(threadId: String)
    case runThread(threadId: String, runId: String)
    case getMessageId(threadId: String, runId: String)
    case getMessageText(threadId: String, messageId: String)
    case cancelRun(threadId: String, runId: String)

    var rawValue: String {
        switch self {
        case .threads:
            "/threads"
        case .addMessage(let threadId):
            messageEndpoint(threadId: threadId)
        case .createRun(let threadId):
            threadEndpoint(threadId: threadId) + "/runs"
        case .runThread(let threadId, let runId):
            runEndpoint(threadId: threadId, runId: runId)
        case .getMessageId(let threadId, let runId):
            runEndpoint(threadId: threadId, runId: runId) + "/steps"
        case .getMessageText(let threadId, let messageId):
            messageEndpoint(threadId: threadId) + "/\(messageId)"
        case .cancelRun(let threadId, let runId):
            runEndpoint(threadId: threadId, runId: runId) + "/cancel"
        }
    }

    private func threadEndpoint(threadId: String) -> String {
        Self.threads.rawValue + "/\(threadId)"
    }

    private func messageEndpoint(threadId: String) -> String {
        threadEndpoint(threadId: threadId) + "/messages"
    }

    private func runEndpoint(threadId: String, runId: String) -> String {
        let threadEndpoint = threadEndpoint(threadId: threadId)
        return threadEndpoint + "/runs/\(runId)"
    }
}

/// Standard headers for the OpenAI Assistants API
struct OpenAIHeaders {
    typealias HttpHeaders = [String: String]

    struct HeaderGroup {
        let headers: HttpHeaders
    }

    private static var contentTypeHeaders: HeaderGroup {
        HeaderGroup(headers: [
            "Content-Type": "application/json"
        ])
    }

    private static var authorizationHeaders: HeaderGroup {
        HeaderGroup(headers: [
            "Authorization": "Bearer \(Environment.openAIAPIKey)"
        ])
    }


    private static var openAIBetaHeaders: HeaderGroup {
        HeaderGroup(headers: [
            "OpenAI-Beta": "assistants=v1"
        ])
    }
    
    /// Standard headers for requests including a JSON payload/body
    static var jsonPayloadHeaders: [String: String] {
        let headerGroups = [contentTypeHeaders, authorizationHeaders, openAIBetaHeaders]

        let allHttpHeaders = headerGroups.reduce(into: [:]) { result, headerGroup in
            result.merge(headerGroup.headers) { (_, new) in new }
        }

        return allHttpHeaders
    }

}

// MARK: Response models

/// Use to decode JSON payloads
protocol DecodableResponse: Decodable {
    /// Return an instance of the concrete type conforming to this protocol
    /// - Parameter data: JSON representable data in .utf8 format
   static func createInstanceFrom(data: Data) throws -> Self
}

extension DecodableResponse {
    static func createInstanceFrom(data: Data) throws -> Self {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(Self.self, from: data)
    }
}
/// Use to encode types to JSON payloads
protocol EncodableRequest: Encodable {
    var jsonPayloadHeaders: [String: String] { get }
    /// Encode an instance of a concrete type to JSON data
    func encodeInstance() throws -> Data
}

extension EncodableRequest {

    /// Headers describing content type and including Bearer auth
    /// - NOTE: computed in order to prevent encoding parameter
    var jsonPayloadHeaders: [String: String] {
        OpenAIHeaders.jsonPayloadHeaders
    }
    
    func encodeInstance() throws -> Data {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        return try encoder.encode(self)
    }
}
