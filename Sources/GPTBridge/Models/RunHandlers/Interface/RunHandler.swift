//
//  RunHandler.swift
//  SlackMojiChef
//
//  Created by Kenneth Dubroff on 12/16/23.
//

import Foundation

protocol RunHandler {
    /// The run's response, decoded
    var runThreadResponse: RunThreadResponse { get }
    /// Handle the run - implemented differently for different handlers
    func handle() async throws
}
