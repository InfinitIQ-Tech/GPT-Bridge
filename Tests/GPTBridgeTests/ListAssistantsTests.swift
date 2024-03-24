//
//  ListAssistantsTests.swift
//
//
//  Created by Kenneth Dubroff on 3/24/24.
//

import XCTest
@testable import GPTBridge

class ListAssistantsTests: XCTestCase {
    let testAssistant = Assistant(id: "id", name: "name", description: "description", model: "model", instructions: "instructions")
    private func assistantJSONString() throws -> String {
        try toJSONString(from: testAssistant)
    }

    func testAssistants_areDecodable() throws {
        let decodedAssistant = try toInstance(from: assistantJSONString(), to: Assistant.self)
        XCTAssertEqual(decodedAssistant, testAssistant)
    }

}
