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
                AssistantListView()
                    .tabItem {
                        Label("Assistants", systemImage: "person.2.badge.gearshape.fill")
                    }
                    .task {
                        GPTBridge.appLaunch(openAIAPIKey: "", assistantKey: "my_assistant_key")
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
