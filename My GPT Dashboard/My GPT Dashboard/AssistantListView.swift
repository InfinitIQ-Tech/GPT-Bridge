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
            List(assistants, id: \.id) { assistant in
                Text(assistant.name)
            }
            .listStyle(SidebarListStyle())
        }
        .padding()
        .task {
            GPTBridge.appLaunch(openAIAPIKey: "sk-myOpenAI_API_Key", assistantKey: "my_assistant_key")

            // list assistants
            guard assistants.isEmpty else { return }
            do {
                let response = try await GPTBridge.listAssistants(
                    paginatedBy: PaginatedRequestParameters(
                        limit: 10,
                        order: .descending
                    )
                )
                var hasMore = response.hasMore
                assistants += response.data

                while hasMore {
                    let lastId = assistants.last?.id
                    let paginationRequest = PaginatedRequestParameters(
                        limit: 10,
                        startAfter: lastId ?? "",
                        order: .descending
                    )
                    let response = try await GPTBridge.listAssistants(paginatedBy: paginationRequest)
                    hasMore = response.hasMore
                    assistants += response.data
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
