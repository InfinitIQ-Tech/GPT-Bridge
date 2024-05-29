//
//  CreateRunTests.swift
//
//
//  Created by Kenneth Dubroff on 5/28/24.
//

import XCTest
@testable import GPTBridge

class CreateRunTests: XCTestCase {
    func testCanDecodeRunObject() throws {
        let instance = try XCTUnwrap(
            toInstance(
                from: runThreadResponseJSONString,
                to: RunThreadResponse.self
            )
        )
        XCTAssertEqual(instance.id, testRunThreadResponse.id)
    }
}
