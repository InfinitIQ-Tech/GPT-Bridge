//
//  FunctionRunHandlerTests.swift
//  
//
//  Created by Kenneth Dubroff on 2/27/24.
//

import XCTest
@testable import GPTBridge

//typealias TestableResponse = DecodableResponse & EncodableRequest & Equatable
//
//struct DallE3FunctionArguments: TestableResponse {
//    let prompt: String
//    let photoName: String
//}

final class FunctionRunHandlerTests: XCTestCase {

    let testArgs = AssistantFunction(name: "Test", arguments: ["argument1": AnyDecodable("foo"), "argument2": AnyDecodable(2)])

    func testFunctionArguments_areDecodable() throws {
        let jsonString = """
                         {
                         "name": "Test",
                         "arguments": "{\\"argument1\\": \\"foo\\", \\"argument2\\": 2}"
                         }
                         """
        let function = try toInstance(from: jsonString, to: AssistantFunction.self)
        XCTAssertEqual(function.name, testArgs.name)
        for argument in testArgs.arguments {
            XCTAssert(function.arguments[argument.key]?.value as? String == argument.value.value as? String)
        }

    }

}
