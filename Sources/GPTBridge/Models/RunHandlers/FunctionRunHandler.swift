//
//  File.swift
//  
//
//  Created by Kenneth Dubroff on 2/27/24.
//

import Foundation

class FunctionRunHandler: FunctionRunHandlable {
    var functionParameters: [String : AnyDecodable]?
    
    var requiredAction: RequiredAction?
    
    var runThreadResponse: RunThreadResponse
    
    func handle() async throws {
        self.functionParameters = try parse()
    }

    init(runThreadResponse: RunThreadResponse) {
        self.runThreadResponse = runThreadResponse
        self.requiredAction = runThreadResponse.requiredAction
    }
}
