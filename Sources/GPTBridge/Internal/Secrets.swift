//
//  File.swift
//  
//
//  Created by Kenneth Dubroff on 2/11/24.
//

import Foundation

struct GPTSecretsConfig {
    private static var _openAIAPIKey: String?

    static var openAIAPIKey: String {
        get {
            assert(_openAIAPIKey != nil && !_openAIAPIKey!.isEmpty, "API Key must not be empty. Run `GPTBridge.applaunch` during your app's entry point")
            return _openAIAPIKey ?? ""
        }
        set(newAPIKey) {
            _openAIAPIKey = newAPIKey
        }
    }

    private static var _assistantKey: String?

    static var assistantKey: String {
        get {
            assert(_assistantKey != nil && !_assistantKey!.isEmpty, "Assistant Key must not be empty. Run `GPTBridge.applaunch` during your app's entry point")
            return _assistantKey ?? ""
        }
        set(newAssistantKey) {
            _assistantKey = newAssistantKey
        }
    }

    static var orgId: String?

    static func appLaunch(openAIAPIKey: String, assistantKey: String) {
        self.openAIAPIKey = openAIAPIKey
        self.assistantKey = assistantKey
    }

    static func setOrgId(orgId: String) {
        self.orgId = orgId
    }
}
