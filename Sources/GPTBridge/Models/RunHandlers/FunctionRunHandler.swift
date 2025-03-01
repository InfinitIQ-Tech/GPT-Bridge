//
//  File.swift
//  
//
//  Created by Kenneth Dubroff on 2/27/24.
//

import Foundation

open class FunctionRunHandler: FunctionRunHandlable {
    public private(set) var functionParameters: [String : FunctionArgument]?
    private(set) var requiredAction: RequiredAction?
    var runThreadResponse: RunThreadResponse?
    /// set `functionParameters` when `runThreadResponse is non-nil `using `parse`
    func handle() async throws {
        self.functionParameters = try parse()
    }

    convenience init(functionParameters: [String: FunctionArgument]) {
        self.init(runThreadResponse: nil)
        self.functionParameters = functionParameters
    }

    init(runThreadResponse: RunThreadResponse?) {
        self.runThreadResponse = runThreadResponse
        self.requiredAction = runThreadResponse?.requiredAction
        if runThreadResponse != nil {
            Task {
                try await self.handle()
            }
        }
    }
}
