//
//  AssistantAPIService.swift
//  SlackMojiChef
//
//  Created by Kenneth Dubroff on 12/10/23.
//

import Foundation
/// > Getting Started
/// >
/// > To get started, run `appLaunch` with your OpenAI API key and assistant key
/// >
/// > - `GPTBridge.appLaunch(openAIAPIKey: "sk-xxxx", assistantKey: "YOUR_ASSISTANT_KEY")`
///
/// > Conversing with the bot
/// > 1. Create a thread
/// > 
/// > `let threadId = GPTBridge.createThread()`
/// >
/// > 2. Add a message to the thread
/// >
/// > `GPTBridge.addMessageToThread(message: "Message from user", threadId: threadId, role: .user)`
/// >
/// > 3. Create a Run - this is where the assistant determines how to respond and/or which tools to use
/// >
/// > `let runId = GPTBridge.createRun(threadId: threadId)`
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

    public static func appLaunch(
        openAIAPIKey: String,
        assistantKey: String
    ) {
        GPTSecretsConfig.appLaunch(
            openAIAPIKey: openAIAPIKey,
            assistantKey: assistantKey
        )
    }

    /// List assistants in `orgId`
    /// - NOTE: If no `orgId` is provided, your OpenAI account's default `org_id` is used
    public static func listAssistants(
        orgId: String? = nil,
        paginatedBy: PaginatedRequestParameters? = nil
    ) async throws -> ListAssistantsResponse {
        if let orgId {
            GPTSecretsConfig.setOrgId(
                orgId: orgId
            )
        }

        let listAssistantRequest = ListAssistantsRequest(
            after: paginatedBy?.startAfter,
            before: paginatedBy?.startBefore,
            limit: paginatedBy?.limit,
            order: paginatedBy?.order
        )
        
        return try await requestManager
            .makeRequest(
                endpoint: .listAssistants,
                method: .GET,
                requestData: listAssistantRequest
            )
    }
    
    /// Create a thread to converse with the assistant
    /// - Returns: The thread's ID
    public static func createThread() async throws -> String {
        let createThreadRequestData: CreateThreadRequest? = CreateThreadRequest()
        let response: CreateThreadResponse = try await requestManager
            .makeRequest(
                endpoint: .threads,
                method: .POST,
                requestData: createThreadRequestData
            )
        return response.id
    }
    
    /// Add a message to a thread
    public static func addMessageToThread(
        message: String,
        threadId: String,
        role: Role = .user
    ) async throws {
        let messageRequestData: AddMessageToThreadRequest = .init(
            role: role,
            content: message
        )
        do {
            let _: AddMessageToThreadResponse? = try await requestManager
                .makeRequest(
                    endpoint: .addMessage(
                        threadId: threadId
                    ),
                    method: .POST,
                    requestData: messageRequestData
                )
        } catch {
            if let requestError = error as? RequestError {
                switch requestError {
                case let .runAlreadyActive(
                    runId
                ):
                    try await cancelRun(
                        threadId: threadId,
                        runId: runId
                    )
                    try await addMessageToThread(
                        message: message,
                        threadId: threadId
                    )
                default:
                    throw Error.nilRunResponse
                }
            }
        }
    }
    
    /// Create a run in a thread
    /// - Parameter threadId: The threadId of the run to create
    /// - Returns: The created Run's ID
    public static func createRun(
        threadId: String
    ) async throws -> String {
        // MARK: Create the run
        let runRequestData: CreateThreadRunRequest = CreateThreadRunRequest()
        let runResponse: RunThreadResponse = try await requestManager
            .makeRequest(
                endpoint: .createRun(
                    threadId: threadId
                ),
                method: .POST,
                requestData: runRequestData
            )
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
    public static func pollRunStatus(
        threadId: String,
        runId: String
    ) async throws -> RunStepResult {
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
        
        while !completedStatuses.contains(
            loopStatus
        ) {
            let runResponse: RunThreadResponse = try await requestManager
                .makeRequest(
                    endpoint: .runThread(
                        threadId: threadId,
                        runId: runId
                    ),
                    method: .GET,
                    requestData: runLoopRequestData
                )
            loopStatus = runResponse.status
            currentRunResponse = runResponse
            try await Task.sleep(
                nanoseconds: 500_000_000
            )
        }
        
        guard let currentRunResponse else {
            throw NSError(
                domain: #function,
                code: 400,
                userInfo: [NSLocalizedDescriptionKey: "The run response is nil, though the run is complete"]
            )
        }
        
        if loopStatus == .requiresAction {
            guard let requiredAction = currentRunResponse.requiredAction else {
                throw Error.nilRunResponse
            }
            let toolCalls = requiredAction.submitToolOutputs.toolCalls
            let functions = requiredAction.submitToolOutputs.toolCalls.compactMap({
                $0.function
            })
            guard !functions.isEmpty,
                  !toolCalls.isEmpty else {
                throw Error.nilRunResponse
            }
            
            let toolCallId = toolCalls[0].id
            return FunctionRunStepResult(
                toolCallId: toolCallId,
                functions: functions
            )
        } else if [
            RunThreadResponse.Status.cancelled,
            .cancelling,
            .expired,
            .failed
        ].contains(
            loopStatus
        ) {
            let failedRunHandler = FailedRunHandler(
                runThreadResponse: currentRunResponse
            )
            try await failedRunHandler.handle()
            return MessageRunStepResult(
                message: failedRunHandler.lastError.localizedString
            ) // TODO: Anti-pattern. create FailedRunStepResult
        } else {
            let messageHandler = MessageRunHandler(
                runThreadResponse: currentRunResponse,
                runID: runId,
                threadID: threadId
            )
            try await messageHandler.handle()
            return MessageRunStepResult(
                message: messageHandler.message ?? ""
            )
        }
    }
    
    /// Cancel the current run manually
    /// This is useful for reducing processing time in the OpenAI API when the assistant doesn't need to know the results of a function call
    public static func cancelRun(
        threadId: String,
        runId: String
    ) async throws {
        let cancelRunRequest = CancelRunRequest()
        let _: CancelRunResponse? = try await requestManager
            .makeRequest(
                endpoint: .cancelRun(
                    threadId: threadId,
                    runId: runId
                ),
                method: .POST,
                requestData: cancelRunRequest
            )
    }
    
    /// Submits the outputs from a function call to the assistant and polls for the next step in the run, which could be another tool call or a final message.
    ///
    /// This function is used when your app requires the assistant to process the result of you processing its function call.
    ///
    /// - Parameters:
    ///   - threadId: The ID of the thread associated with the run.
    ///   - runId: The ID of the run.
    ///   - toolCallOutputs: The id of each function call and what you want the assistant to know about the result of the assistant's generated function
    ///     - Example: The assistant generated a prompt for an image.
    ///       - You sent this to a specialized image generation model that successfully generated an image.
    ///       - You might set this to "success" or "200" or the user's reply
    ///
    /// - Returns: An instance of `RunStepResult` representing the next step in the run. This could be a `FunctionRunStepResult` if the assistant requires another tool call, or a `MessageRunStepResult` if the assistant has generated a final message.
    ///
    /// - Throws: An error if there was a problem submitting the tool outputs or polling for the next step in the run.
    public static func submitToolOutputs(
        threadId: String,
        runId: String,
        toolCallOutputs: [ToolCallOutput]
    ) async throws -> RunStepResult {
        let endpoint = AssistantEndpoint.submitToolOutputs(
            threadId: threadId,
            runId: runId
        )
        let request = ToolCallRequest(
            toolOutputs: toolCallOutputs
        )
        let _: RunThreadResponse = try await requestManager
            .makeRequest(
                endpoint: endpoint,
                method: .POST,
                requestData: request
            )
        return try await pollRunStatus(
            threadId: threadId,
            runId: runId
        )
    }
    
    static func getMessageId(
        threadId: String,
        runId: String
    ) async throws -> String { // TODO: Move to MessageRunHandler
        let endpoint = AssistantEndpoint.getMessageId(
            threadId: threadId,
            runId: runId
        )
        let requestData: MessageIdRequest? = MessageIdRequest()
        let messageResponse: MessageResponse = try await requestManager.makeRequest(
            endpoint: endpoint,
            method: .GET,
            requestData: requestData
        )
        guard !messageResponse.data.isEmpty,
              let messageId = messageResponse.data[0].stepDetails.messageCreation?.messageId
        else {
            throw Error.emptyMessageResponseDate
        }
        return messageId
    }
    
    static func getMessageText(
        threadId: String,
        messageId: String
    ) async throws -> String { // TODO: Move to MessageRunHandler
        let endpoint = AssistantEndpoint.getMessageText(
            threadId: threadId,
            messageId: messageId
        )
        let requestData: MessageTextRequest? = MessageTextRequest()
        let messageTextResponse: MessageContent = try await requestManager.makeRequest(
            endpoint: endpoint,
            method: .GET,
            requestData: requestData
        )
        guard !messageTextResponse.content.isEmpty else {
            return "Unknown Error. Please try again"
        }
        return messageTextResponse.content[0].text.value
    }

}
