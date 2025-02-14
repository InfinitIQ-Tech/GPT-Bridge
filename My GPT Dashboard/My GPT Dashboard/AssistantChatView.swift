//
//  AssistantChatView.swift
//  GPTBridge
//
//  Created by Kenneth Dubroff on 2/12/25.
//

import GPTBridge
import SwiftUI

class AssistantChatViewModel: ObservableObject {
    enum Error: Swift.Error {
        case noActiveThread
        case noMessageFromRun
        case threadAlreadyActive
    }


    private var threadId: String? = nil

    @Published
    var activeAssistant: Assistant
    @Published
    var messages: [ChatMessage] = []

    init(activeAssistant: Assistant) {
        self._activeAssistant = .init(wrappedValue: activeAssistant)
    }

    func createThread() async throws {
        guard threadId == nil else { throw Error.threadAlreadyActive }
        let thread = try await GPTBridge.createThread()
        self.threadId = thread
    }

    func addMessageToThread(withContent text: String) async throws {
        if self.threadId == nil {
            try await createThread()
        }
        guard let threadId else { throw Error.noActiveThread }

        try await GPTBridge.addMessageToThread(message: text, threadId: threadId)
        let chatMessage = ChatMessage(content: text, role: .user)
        self.messages.append(chatMessage)

        let runId = try await GPTBridge.createRun(threadId: threadId, assistantId: activeAssistant.id)

        let result = try await GPTBridge.pollRunStatus(threadId: threadId, runId: runId)
        guard let text = result.message else { throw Error.noMessageFromRun }
        let assistantResponse = ChatMessage(content: text, role: .assistant)
        self.messages.append(assistantResponse)
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
                            try await viewModel.addMessageToThread(withContent: userInput)
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
        .navigationTitle(viewModel.activeAssistant.id)
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
            } else {
                // User on the right
                Spacer()
                VStack(alignment: .trailing) {
                    Text(message.content)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.green)
                        .cornerRadius(12)
                }
            }
        }
    }
}
