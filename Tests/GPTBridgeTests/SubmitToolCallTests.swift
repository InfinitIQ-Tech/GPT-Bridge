//
//  File.swift
//  
//
//  Created by Kenneth Dubroff on 4/6/24.
//

@testable import GPTBridge
import XCTest

class SubmitToolCallTests: XCTestCase {
    private let testOutput = ToolCallOutput(toolCallId: "1", output: "Test")
    private func testOutputJSONString() throws -> String {
        try toJSONString(from: testOutput)
    }

    func testEncodedToolCallOutputs_areEqual() throws {
        // test decoding returns equatable instance
        let testInstance = try XCTUnwrap(
            toInstance(
                from: testOutputJSONString(),
                to: ToolCallOutput.self
            )
        )
        XCTAssertEqual(testOutput, testInstance)
    }
}

extension ToolCallOutput: Decodable {
    enum CodingKeys: String, CodingKey {
        case toolCallId
        case output
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let toolCallId = try container.decode(String.self, forKey: .toolCallId)
        let output = try container.decode(String.self, forKey: .output)
        self.init(toolCallId: toolCallId, output: output)
    }
}

extension ToolCallOutput: Equatable {
    public static func == (lhs: ToolCallOutput, rhs: ToolCallOutput) -> Bool {
        lhs.toolCallId == rhs.toolCallId &&
        lhs.output == rhs.output
    }
}
