//
//  My_GPT_DashboardApp.swift
//  My GPT Dashboard
//
//  Created by Kenneth Dubroff on 4/5/24.
//

import GPTBridge
import SwiftUI

@main
struct My_GPT_DashboardApp: App {
    var body: some Scene {
        WindowGroup {
            TabView {
                NavigationStack {
                AssistantListView()
                    .tabItem {
                        Label("Assistants", systemImage: "person.2.badge.gearshape.fill")
                    }
                    .task {
                        GPTBridge.appLaunch(openAIAPIKey: "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", assistantKey: "asst_d0BQB2EEIOnFZJrlT6drCR5D")
                    }
                }
            }
        }
    }
}

#Preview {
    TabView {
        AssistantListView()
            .tabItem {
                Text("Assistants")
            }
    }
}
