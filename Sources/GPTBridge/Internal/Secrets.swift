//
//  File.swift
//  
//
//  Created by Kenneth Dubroff on 2/11/24.
//

import Foundation

enum AppSecret: String {
    case openAIAPIKey
    case assistantKey
    /// convenience method to get string value from .xcscheme
    var bundleString: String {
        let value = Bundle.main.infoDictionary?[rawValue] as? String
        let errorStr = "The secret '\(rawValue)' is not defined.\nCreate a Secrets.xcconfig file in the bundle with \(rawValue)=<your_key_here>"
        assert(value != nil && value != "", errorStr)
        return value ?? errorStr
    }
}

struct Environment {
    static let openAIAPIKey = AppSecret.openAIAPIKey.bundleString
    static let assistantKey = AppSecret.assistantKey.bundleString
}
