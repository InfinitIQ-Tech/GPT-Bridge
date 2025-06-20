//
//  AssistantChatView.swift
//  GPTBridge
//
//  Created by Kenneth Dubroff on 2/12/25.
//

import GPTBridge
import SwiftUI

@MainActor
class AssistantChatViewModel: ObservableObject {
    enum Error: Swift.Error {
        case noActiveThread
        case noMessageFromRun
        // - NOTE: This is only an error in the demo app. Your app can have multiple threads with different topics and assistants running them.
        case threadAlreadyActive
    }

    private var threadId: String? = nil
    @Published
    var streamingText: String = ""

    @Published
    var activeAssistant: Assistant
    @Published
    var messages: [ChatMessage] = []

    init(activeAssistant: Assistant) {
        self._activeAssistant = .init(wrappedValue: activeAssistant)
    }

    func createAndRunThread(stream: Bool = true) async throws {
        if self.threadId != nil {
            throw Error.threadAlreadyActive
        }
        let thread = Thread(messages: messages)

        let result = try await GPTBridge.createAndStreamThreadRun(assistantId: activeAssistant.id, thread: thread)
        // handle the async stream
        for try await event in result {
            switch event {
            case .threadCreated(let threadId):
                self.threadId = threadId
            case .messageDelta(let text):
                self.streamingText += text
            case .messageCompleted(let message):
                resetStream(usingChatMessage: message)
            case .runRequiresAction(let response):
                let functions = response.assistantFunctions
                
                for (toolCallId, function) in functions {
                    for argument in function.arguments {
                        let argumentKey = argument.key
                        streamingText += "Key: \(argumentKey)\n"

                        if let argumentValue = argument.value.asString {
                            streamingText += "Value: \(argumentValue)\n"
                        // You setup complex JSON that includes a dictionary of Key: Decodable/FunctionArgument
                        } else if let argumentValue = argument.value.asStringDecodableDictionary {
                            // TODO: Init your custom type with these keys and values
                            let myArgumentKey = "key"
                            if let value = argumentValue[myArgumentKey]?.asString {
                                streamingText += "Value: \(value)\n"
                            } else {
                                // just stream them
                                for (key, argument) in argumentValue {
                                    streamingText += "Custom Argument: \(key): \(argument)\n"
                                }
                            }
                            // your argument value is an array of some type
                        } else if let argumentValue = argument.value.asArray() {
                            // you will need to downcast from here
                            for value in argumentValue {
                                if let functionArgumentValue = value.asStringDecodableDictionary {
                                    for (key, value) in functionArgumentValue {
                                        streamingText += "Custom Argument: \(key): \(value.asString ?? "No Argument")\n"
                                    }
                                } else {
                                    streamingText += "Value: \(value)\n"
                                }
                            }
                        } else {
                            streamingText += "Value: \(argument.value)\n"
                        }
                        streamingText += "\n"
                    }
                    let message = ChatMessage(content: streamingText, role: .assistant)
                    resetStream(usingChatMessage: message)
                    let stream = try await response.sendToolCallResponse(threadId: threadId ?? "", function: function)
                    try await handleStream(stream)
                }
            default:
                let message = ChatMessage(content: streamingText, role: .assistant)
                resetStream(usingChatMessage: message)
            }
        }
        // Update UI
        let message = ChatMessage(content: streamingText, role: .assistant)
        resetStream(usingChatMessage: message)
    }


    fileprivate func handleStream(_ stream: AsyncThrowingStream<RunStatusEvent, Swift.Error>) async throws {
        for try await event in stream {
            switch event {
            case .messageDelta(let partialMessage):
                self.streamingText += partialMessage
            case .messageCompleted(let message):
                resetStream(usingChatMessage: message)
            case .done, .runFailed:
                self.streamingText = ""
            case .errorOccurred(let error):
                let message = ChatMessage(content: "Unknown Error. Please try again", role: .error)
                print("An Error occured while handling SSE events: \(error)")
                // stop streaming to UI, TODO: stop SSE/cancel run
                self.resetStream(usingChatMessage: message)
                return
                // TODO: decide to exit stream or continue until it ends (error may be recoverable, but this may result in undesired behavior such as missed bytes/text resulting in a garbled stream)
            default:
                break
            }
        }
    }
    
    /// Add a message to an existing thread and stream the run
    /// - Parameters:
    ///   - assistantId: If nil, the activeAssistantId (if set) will be used
    ///   - text: The message to add to the thread
    func addMessageToThreadAndRun(assistantId: String? = nil, withContent text: String) async throws {
        if self.threadId == nil {
            let message = ChatMessage(content: text, role: .user)
            messages.append(message)
            try await createAndRunThread()
            return
        }

        guard let threadId else {
            throw Error.noActiveThread
        }

        let assistantId = assistantId ?? self.activeAssistant.id
        let stream = try await GPTBridge.addMessageAndStreamThreadRun(text: text, threadId: threadId, assistantId: assistantId)
        try await handleStream(stream)
    }

    private func resetStream(usingChatMessage chatMessage: ChatMessage) {
        if !self.streamingText.isEmpty {
            self.streamingText = ""
        }
        if !chatMessage.content.isEmpty {
            self.messages.append(chatMessage)
        }
    }

    func createThread() async throws {
        guard threadId == nil else { throw Error.threadAlreadyActive }
        let thread = try await GPTBridge.createThread()
        self.threadId = thread
    }
    
    @MainActor
    func addMessageToThread(withContent text: String) async throws {
        // TODO: Implement non-streaming method
    }
}

struct AssistantChatView: View {
    @ObservedObject var viewModel: AssistantChatViewModel

    @State private var userInput: String = ""

    var body: some View {
        VStack {
            // Message list
            ScrollView {
                ScrollViewReader { scrollProxy in
                    VStack(spacing: 12) {
                        ForEach(viewModel.messages.indices, id: \.self) { index in
                            let message = viewModel.messages[index]
                            MessageBubbleView(message: message)
                                .id(index) // For scrolling
                        }
                        if !viewModel.streamingText.isEmpty {
                            MessageBubbleView(message: ChatMessage(content: viewModel.streamingText, role: .assistant))
                        }
                    }
                    .padding()
                    .onChange(of: viewModel.messages.count) { _ in
                        // Scroll to the last message whenever a new one arrives
                        withAnimation {
                            scrollProxy.scrollTo(viewModel.messages.count - 1, anchor: .bottom)
                        }
                    }
                }
            }

            // Input area
            HStack {
                TextField("Type a message…", text: $userInput, axis: .vertical)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .lineLimit(1...4)

                Button("Send") {
                    Task {
                        do {
                            try await viewModel.addMessageToThreadAndRun(withContent: userInput)
                            userInput = ""
                        } catch {
                            // You might handle or display errors here
                            print("Error sending message: \(error)")
                        }
                    }
                }
                .disabled(userInput.isEmpty)
            }
            .padding()
        }
        .navigationTitle(viewModel.activeAssistant.name ?? "Chat with assistant")
    }
}

fileprivate struct MessageBubbleView: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.role == .assistant {
                // Assistant on the left
                VStack(alignment: .leading) {
                    Text(message.content)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                }
                Spacer()
            } else if message.role == .user {
                // User on the right
                Spacer()
                VStack(alignment: .trailing) {
                    Text(message.content)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.green)
                        .cornerRadius(12)
                }
            } else if message.role == .error {
                // error on the left
                VStack(alignment: .leading) {
                    Text(message.content)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.red)
                        .cornerRadius(12)
                }
                Spacer()
            }
        }
    }
}

extension Role {
    static let error: Role = .assistant
}
