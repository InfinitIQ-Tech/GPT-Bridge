//
//  AsyncStreamManager.swift
//  GPTBridge
//
//  Created by Kenneth Dubroff on 2/9/25.
//

import Foundation

protocol StreamingRequestManageable: RequestManageable {
//    func makeRequest<U: EncodableRequest>(
//        endpoint: AssistantEndpoint,
//        method: HttpMethod,
//        requestData: U?
//    ) async throws -> AsyncThrowingStream<MessageDeltaEvent, any Error> where U: EncodableRequest
}

/// Represents the various run status events that can be streamed.
public enum RunStatusEvent {
    case threadCreated(String)
    case runStepCreated(RunStepResult)
    case runStepInProgress(RunStepResult)
    case runStepCompleted(RunStepResult)
    case messageDelta(MessageRunStepResult)
    case messageCompleted(ChatMessage)
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
    static let runCompletedKey = "thread.run.completed"
    static let runFailedKey = "thread.run.failed"
    static let runCancelledKey = "thread.run.cancelled"
    static let runExpiredKey = "thread.run.expired"
    static let errorOccurredKey = "error"
    static let doneKey = "[DONE]"
    static let unknownThreadStatusKey = "thread.unknown"

}

struct StreamingRequestManager: StreamingRequestManageable {
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

        // Simply call your SSEStreamer
        return ThreadRunStatusStreamer().streamRunStatusEvents(with: request, inactivityTimeout: timeout)
    }
}
