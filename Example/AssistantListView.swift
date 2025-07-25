//
//  AssistantListView.swift
//  My GPT Dashboard
//
//  Created by Kenneth Dubroff on 4/5/24.
//

import GPTBridge
import SwiftUI

struct AssistantListView: View {
    @State
    var assistants: [Assistant] = []

    var body: some View {
        VStack {
            if assistants.isEmpty {
                Text(
"""
No assistants found for the org associated with this API key. \
Create an API key for an org with assistants or create an assistant for this account at [OpenAI settings](https://platform.openai.com/settings/organization/api-keys)
""")
                    .font(.largeTitle)
                    .padding()
            } else {
                List(assistants, id: \.id) { assistant in
                    NavigationLink(destination: AssistantChatView(viewModel: AssistantChatViewModel(activeAssistant: assistant))) {
                        Text(assistant.name ?? "Name Not Defined")
                    }
                }
                .listStyle(SidebarListStyle())
            }
        }
        .padding()
        .task {
            // list assistants
            guard assistants.isEmpty else { return }
            do {
                let response = try await GPTBridge.listAssistants(
                    paginatedBy: PaginatedRequestParameters(
                        limit: 10,
                        order: .descending
                    )
                )
                if var hasMore = response.hasMore {
                    assistants += response.data

                    while hasMore {
                        let lastId = assistants.last?.id
                        let paginationRequest = PaginatedRequestParameters(
                            limit: 10,
                            startAfter: lastId ?? "",
                            order: .descending
                        )
                        let response = try await GPTBridge.listAssistants(paginatedBy: paginationRequest)
                        hasMore = response.hasMore ?? false
                        assistants += response.data
                    }
                }

            } catch {
                print("Error loading assistants: \(error)")
            }

            // Tool Call Output submission test
//            let threadId = try! await GPTBridge.createThread()
//
//            let message = "What is the weather unit for United States?"
//
//            try? await GPTBridge.addMessageToThread(message: message, threadId: threadId)
//
//            let runId = try! await GPTBridge.createRun(threadId: threadId)
//
//            let result = try! await GPTBridge.pollRunStatus(threadId: threadId, runId: runId) as? FunctionRunStepResult
//
//            let function = result?.functions?[0]
//
//            print("The weather unit for America is \(function?.arguments["unit"])")
//            do {
//                let assistantReply = try await GPTBridge.submitToolOutputs(threadId: threadId, runId: runId, functionCallId: result?.toolCallId ?? "", toolOutput: "200")
//
//                print(assistantReply.message)
//                print(assistantReply.functions)
//            } catch {
//                print("Error with assistant reply after tool output submission: \(error)")
//            }
        }
    }
}

#Preview {
    let previewAssistants: [Assistant] = [
        Assistant(id: "1",
                  name: "Foo Assistant",
                  description: "Bar",
                  model: "gpt-9001-turbo",
                  instructions: "I am an assistant who foos the bar"),
        Assistant(id: "2",
                  name: "Bar Assistant",
                  description: "Foo",
                  model: "gpt-9001-turbo",
                  instructions: "I am an assistant who bars the foo")

    ]

    return AssistantListView(assistants: previewAssistants)
}
