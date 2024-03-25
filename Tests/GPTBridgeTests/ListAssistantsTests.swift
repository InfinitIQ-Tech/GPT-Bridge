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

    func testAssistantsResponse_canBeDecoded() throws {
        let testResponse = ListAssistantsResponse(data: [testAssistant, testAssistant])
        let responseJSONString = try toJSONString(from: testResponse)
        let decodedResponse = try toInstance(from: responseJSONString, to: ListAssistantsResponse.self)
        XCTAssertEqual(decodedResponse.data[0], testAssistant)
        XCTAssertEqual(decodedResponse.data[1], testAssistant)
    }
}
