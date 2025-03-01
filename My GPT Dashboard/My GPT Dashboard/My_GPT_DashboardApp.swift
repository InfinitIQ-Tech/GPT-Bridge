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
                        GPTBridge.appLaunch(openAIAPIKey: "sk-proj-h4HAvJMKS2ySpdH2S7JBT3BlbkFJ5akijNhgf27WkRVuzeeM")
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
