//
//  AssistantAPIService.swift
//  SlackMojiChef
//
//  Created by Kenneth Dubroff on 12/10/23.
//

import Foundation
/// > Getting Started
/// >
/// > To get started, create a secrets.xcconfig file in your project with the following keys and values:
/// >
/// > - ```assistantKey=your-assistantKey```
/// > - ```openAIAPIKey=sk-something```
///
/// > Conversing with the bot
/// > 1. Create a thread
/// > 
/// > ```let threadId = GPTBridge.createThread()```
/// >
/// > 2. Add a message to the thread
/// >
/// > ```GPTBridge.addMessageToThread(message: "Message from user", threadId: threadId, role: .user)```
/// >
/// > 3. Create a Run - this is where the assistant determines how to respond and/or which tools to use
/// >
/// > ```let runId = GPTBridge.createRun(threadId: threadId)```
/// > - NOTE: only 1 run can be active in a thread at once
/// >
/// > 4. Poll for run status - wait for the assistant to come back with a response
/// >
/// > `GPTBridge.pollRunStatus(runId: runId`)
/// >
/// > 5. Handle the response.
/// >
/// > - If tools were run, the `functions` parameter of the returned `RunStepResult` will be populated
/// >
/// > - If a message was generated, the `message` parameter of the returned `RunStepResult` will be populated
/// >
/// > - NOTE: Both `functions` and `message` should never be populated
public class GPTBridge {
    public enum Error: Swift.Error {
        case nilRunResponse
        case emptyMessageResponseDate
    }

    private static let requestManager = RequestManager()

    public static func appLaunch(openAIAPIKey: String, assistantKey: String) {
        GPTSecretsConfig.appLaunch(openAIAPIKey: openAIAPIKey, assistantKey: assistantKey)
    }

    /// Create a thread to converse with the assistant
    /// - Returns: The thread's ID
    public static func createThread() async throws -> String {
        let createThreadRequestData: CreateThreadRequest? = CreateThreadRequest()
        let response: CreateThreadResponse = try await requestManager
            .makeRequest(endpoint: .threads, method: .POST, requestData: createThreadRequestData)
        return response.id
    }

    /// Add a message to a thread
    public static func addMessageToThread(message: String, threadId: String, role: Role = .user) async throws {
        let messageRequestData: AddMessageToThreadRequest = .init(role: role, content: message)
        do {
            let _: AddMessageToThreadResponse? = try await requestManager
                .makeRequest(endpoint: .addMessage(threadId: threadId), method: .POST, requestData: messageRequestData)
        } catch {
            if let requestError = error as? RequestError {
                switch requestError {
                case let .runAlreadyActive(runId):
                    let cancelRunRequest = CancelRunRequest()
                    let _: CancelRunResponse? = try await requestManager
                        .makeRequest(endpoint: .cancelRun(threadId: threadId, runId: runId), method: .POST, requestData: cancelRunRequest)
                    try await addMessageToThread(message: message, threadId: threadId)
                default:
                    throw Error.nilRunResponse
                }
            }
        }
    }

    /// Create a run in a thread
    /// - Parameter threadId: The threadId of the run to create
    /// - Returns: The created Run's ID
    public static func createRun(threadId: String) async throws -> String {
        // MARK: Create the run
        let runRequestData: CreateThreadRunRequest = CreateThreadRunRequest()
        let runResponse: RunThreadResponse = try await requestManager
            .makeRequest(endpoint: .createRun(threadId: threadId), method: .POST, requestData: runRequestData)
        return runResponse.id
    }

    /// Continuously polls the status of a specific run (identified by `runId`) in a thread (identified by `threadId`).
    ///
    /// Assumes the beginning status of the run is `.queued`. In each iteration of the loop, makes a GET request to the `runThread` endpoint, updating the status of the run.
    ///
    /// The function continues to loop until the status of the run is one of the following: `.completed`, `.cancelled`, `.failed`, `.requiresAction`.
    ///
    /// Depending on the final status of the run, the function returns a different type of `RunHandler`:
    /// - If the status is `.requiresAction`, it returns a `FunctionRunHandler`.
    /// - If the status is `.cancelled`, `.cancelling`, `.expired`, or `.failed`, it returns a `FailedRunHandler`.
    /// - Otherwise, it returns a `MessageRunHandler`.
    ///
    /// - Throws: An `NSError` if the run response is `nil` after the run is completed.
    /// - Returns: An instance of a `RunStepResult` implementation based on the final status of the run. If the assistant runs functions, their propertries will be available in the `functions` property of the `RunStepResult`. Otherwise, if the assistant sends a message back or there's an error, the `message` propperty will contain a String
    ///
    /// - Note: This function uses `Task.sleep(nanoseconds: 500_000_000)` to introduce a delay of 0.5 seconds between each poll, to prevent overwhelming the server with requests.
    public static func pollRunStatus(threadId: String, runId: String) async throws -> RunStepResult {
        let runLoopRequestData: RunThreadRequest? = RunThreadRequest()
        let completedStatuses: [RunThreadResponse.Status] = [
            RunThreadResponse.Status.completed,
            .cancelled,
            .cancelling,
            .expired,
            .failed,
            .requiresAction
        ]

        var loopStatus: RunThreadResponse.Status = .queued // assume queued status to begin with. This will be overwritten on the first run anyway
        var currentRunResponse: RunThreadResponse?

        while !completedStatuses.contains(loopStatus) {
            let runResponse: RunThreadResponse = try await requestManager
                .makeRequest(endpoint: .runThread(threadId: threadId, runId: runId),
                             method: .GET,
                             requestData: runLoopRequestData)
            loopStatus = runResponse.status
            currentRunResponse = runResponse
            try await Task.sleep(nanoseconds: 500_000_000)
        }

        guard let currentRunResponse else {
            throw NSError(domain: #function, code: 400, userInfo: [NSLocalizedDescriptionKey: "The run response is nil, though the run is complete"])
        }

        if loopStatus == .requiresAction {
            let functions = currentRunResponse.requiredAction?.submitToolOutputs.toolCalls.compactMap { $0.function } ?? []
            return FunctionRunStepResult(functions: functions)
        } else if [RunThreadResponse.Status.cancelled, .cancelling, .expired, .failed].contains(loopStatus) {
            let failedRunHandler = FailedRunHandler(runThreadResponse: currentRunResponse)
            return MessageRunStepResult(message: failedRunHandler.lastError.localizedString) // TODO: Anti-pattern. create FailedRunStepResult
        } else {
            let messageHandler = MessageRunHandler(runThreadResponse: currentRunResponse, runID: runId, threadID: threadId)
            return MessageRunStepResult(message: messageHandler.message ?? "")
        }
    }

    static func getMessageId(threadId: String, runId: String) async throws -> String { // TODO: Move to MessageRunHandler
        let endpoint = AssistantEndpoint.getMessageId(threadId: threadId, runId: runId)
        let requestData: MessageIdRequest? = MessageIdRequest()
        let messageResponse: MessageResponse = try await requestManager.makeRequest(endpoint: endpoint, method: .GET, requestData: requestData)
        guard !messageResponse.data.isEmpty else { throw Error.emptyMessageResponseDate }
        return messageResponse.data[0].stepDetails.messageCreation.messageId
    }

    static func getMessageText(threadId: String, messageId: String) async throws -> String { // TODO: Move to MessageRunHandler
        let endpoint = AssistantEndpoint.getMessageText(threadId: threadId, messageId: messageId)
        let requestData: MessageTextRequest? = MessageTextRequest()
        let messageTextResponse: MessageContent = try await requestManager.makeRequest(endpoint: endpoint, method: .GET, requestData: requestData)
        guard !messageTextResponse.content.isEmpty else { return "Unknown Error. Please try again" }
        return messageTextResponse.content[0].text.value
    }

}
