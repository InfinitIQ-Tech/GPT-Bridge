//
//  FailedRunHandler.swift
//  GPTBridge
//
//  Created by Kenneth Dubroff on 12/16/23.
//

import Foundation

class FailedRunHandler: RunHandler {
    enum Error {
        case cancelled(reason: String)
        case expired
        case someError(reason: String)

        var localizedString: String {
            switch self {
            case .cancelled(let reason):
                return reason
            case .expired:
                return "expired"
            case .someError(let reason):
                return reason
            }
        }
    }
    
    /// The Thread Run's status
    /// Used to determine if run was cancelled or failed
    var status: RunThreadResponse.Status
    var runThreadResponse: RunThreadResponse

    /// Swift Error4 describing what happened
    /// will be `runThreadResponse.lastError` if non-nil
    var lastError: Error

    init(runThreadResponse: RunThreadResponse) {
        self.status = runThreadResponse.status
        self.runThreadResponse = runThreadResponse
        if [RunThreadResponse.Status.cancelled, .cancelling].contains(status) {
            self.lastError = Error.cancelled(reason: "cancelled")
        } else {
            self.lastError = Error.someError(reason: runThreadResponse.lastError ?? "An unkown error occurred. Please try again.")
        }
    }

    func handle() async throws {
        // TODO: present error to user via dispatch
    }
}
