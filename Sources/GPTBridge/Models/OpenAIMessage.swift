//
//  OpenAIMessage.swift
//  SlackMojiChef
//
//  Created by Kenneth Dubroff on 12/16/23.
//

import Foundation
/// represents messages sent to/from OpenAI
protocol OpenAIMessageable {
    var role: Role { get }
    var content: String { get }
}
/// represents messages sent to/from OpenAI
struct OpenAIMessage: OpenAIMessageable {
    var role: Role
    var content: String
}
