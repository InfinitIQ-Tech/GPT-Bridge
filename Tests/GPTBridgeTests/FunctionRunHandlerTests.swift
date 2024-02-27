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

    private let prompt = "An Image or something"
    private let photoName = "An Image"

    private var dalle3Args: DallE3FunctionArguments {
        DallE3FunctionArguments(prompt: prompt, 
                                photoName: photoName)
    }

    func testDallE3Arguments_areDecodable() throws {
        let jsonString = try toJSONString(from: dalle3Args)
        let instance = try toInstance(from: jsonString, to: DallE3FunctionArguments.self, usingKeyDecodingStrategy: .useDefaultKeys) // useDefaultKeys because struct is using snake_case in CodingKeys
        XCTAssertEqual(instance.prompt, prompt)
        XCTAssertEqual(instance.photoName, photoName)
    }

}
