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
            guard assistants.isEmpty else { return }
            do {
                assistants = try await GPTBridge.listAssistants()
                    .sorted(by: { $0.name < $1.name })
            } catch {
                print("Error loading assistants: \(error)")
            }
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
