//
//  MessageRunHandler.swift
//  SlackMojiChef
//
//  Created by Kenneth Dubroff on 12/16/23.
//

import Foundation

class MessageRunHandler: RunHandler {
    enum Error: Swift.Error {
        case noMessageId
    }

    let runThreadResponse: RunThreadResponse

    /// The Thread Run's ID
    private let runID: String
    /// The Thread's ID
    private let threadID: String
    /// the ID of the AI's message
    /// - NOTE: this will be nil until `handle()` completes
    private var messageId: String?
    /// the AI's generated message
    /// - NOTE: this will be nil until `handle()` completes
    public var message: String?

    init(runThreadResponse: RunThreadResponse, runID: String, threadID: String) {
        self.runThreadResponse = runThreadResponse
        self.runID = runID
        self.threadID = threadID
    }
    
    /// Get the AI's response (message)
    /// 1. `getMessageID()`
    /// 2. set self.message with `getMessageText()`
    func handle() async throws {
        try await getMessageID()
        self.message = try await getMessageText()
    }

    /// Get the message ID from the Thread Run's steps
    @discardableResult
    private func getMessageID() async throws -> String {
        let messageId = try await GPTBridge().getMessageId(threadId: threadID, runId: runID)
        self.messageId = messageId
        return messageId
    }
    /// Get the message text from the thread's `messages` array, given the message's ID
    private func getMessageText() async throws -> String {
        guard let messageID = messageId else { throw Error.noMessageId }
        return try await GPTBridge().getMessageText(threadId: threadID, messageId: messageID)
    }
}
