//
//  AsyncStreamManager.swift
//  GPTBridge
//
//  Created by Kenneth Dubroff on 2/9/25.
//

import Foundation

/// Represents the various run status events that can be streamed.
public enum RunStatusEvent {
    case threadCreated(String)
    case runStepCreated(RunStepResult)
    case runStepInProgress(RunStepResult)
    case runStepCompleted(RunStepResult)
    case messageDelta(String)
    case messageCompleted(ChatMessage)
    /// The assistant has used a function and returned the parameters
    /// If it's important in your app for the assistant to know the result of the function generation,
    /// call `GPTBridge.submitToolOutputs(...`
    /// otherwise, call `GPTBridge.cancelRun(...` as a cost-savings measure
    case runRequiresAction(AssistantFunctionResponse) // the assistant generated values using one of its functions
    case runCompleted(RunStepResult)
    case runFailed(RunStepResult)
    case runCancelled(RunStepResult)
    case runExpired(RunStepResult)
    case errorOccurred(OpenAIJSONError)     // Represents an error event from the stream
    case done               // Indicates the stream has finished (completion marker)
    case unknown(event: String, data: String)  // Fallback for unrecognized events

    static let threadCreatedKey = "thread.created"
    static let runStepCreatedKey = "thread.run.step.created"
    static let runStepCompletedKey = "thread.run.step.completed"
    static let runStepInProgressKey = "thread.run.step.in_progress"
    static let messageDeltaKey = "thread.message.delta"
    static let messageCompletedKey = "thread.message.completed"
    static let runRequiresActionKey = "thread.run.requires_action"
    static let runCompletedKey = "thread.run.completed"
    static let runFailedKey = "thread.run.failed"
    static let runCancelledKey = "thread.run.cancelled"
    static let runExpiredKey = "thread.run.expired"
    static let errorOccurredKey = "error"
    static let doneKey = "done"
    static let unknownThreadStatusKey = "thread.unknown"
}

struct StreamingRequestManager: RequestManageable {
    var baseURL: URL

    init(baseURL: URL = URL(string: Self.baseURLString)!) {
        self.baseURL = baseURL
    }

    func streamThreadRun<U>(
        endpoint: AssistantEndpoint,
        method: HttpMethod,
        timeout: TimeInterval = 30.0,
        requestData: U?
    ) async throws -> AsyncThrowingStream<RunStatusEvent, any Error>
    where U : EncodableRequest {

        var request = URLRequest(url: makeURL(fromEndpoint: endpoint))
        request.httpMethod = method.rawValue
        request.allHTTPHeaderFields = requestData?.jsonPayloadHeaders
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")

        if let requestData = requestData, method != .GET {
            request.httpBody = try requestData.encodeInstance()
        }

        return ThreadRunStreamHandler().streamRunStatusEvents(with: request, inactivityTimeout: timeout)
    }
}

public class AssistantFunctionResponse {
    let runId: String
    let toolCalls: [ToolCall]
    let streamingRequestManager = StreamingRequestManager()
    /// [ToolCall.id: AssistantFunction]
    public let assistantFunctions: [String: AssistantFunction]

    init(runId: String, toolCalls: [ToolCall]) {
        self.runId = runId
        self.toolCalls = toolCalls
        self.assistantFunctions = toolCalls.reduce(into: [:]) {
            $0[$1.id] = $1.function
        }
    }

    public func sendToolCallResponse(threadId: String, function: AssistantFunction, withMessage message: String = "200 OK") async throws -> AsyncThrowingStream<RunStatusEvent, Error>{
        let responseMessage = """
                              Received arguments: \(function.arguments)
                              Message: \(message)
                              """
        let toolCallfunctions = toolCalls.filter { $0.function == function }
        let id = toolCallfunctions.first?.id ?? ""
        let outputs = [ToolCallOutput(toolCallId: id, output: responseMessage)]

        let request = ToolCallRequest(toolOutputs: outputs, stream: true)

        return try await streamingRequestManager.streamThreadRun(endpoint: .submitToolOutputs(threadId: threadId, runId: runId), method: .POST, requestData: request)
    }

    public func cancelRun(threadId: String) async throws {
        try await GPTBridge.cancelRun(threadId: threadId, runId: runId)
    }
}
