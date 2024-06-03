//
//  JSONDecoderTests.swift
//
//
//  Created by Kenneth Dubroff on 6/2/24.
//

import Foundation
import XCTest
@testable import GPTBridge

class JSONDecoderTests: XCTestCase {
    let jsonDecoder = JSONTestData.jsonDecoder
    let now = Date()
    var testJSON: String {
        """
          {
            "a_variable": 1,
            "a_date": \(now.timeIntervalSince1970)
          }
        """
    }



    func testJSONDecoder_decodesSnakeCase() throws {
        let (aTestVarInstance, aMockTestVar) = try sut()
        XCTAssertEqual(aTestVarInstance.aVariable, aMockTestVar.aVariable)
    }

    func testJSONDecoder_decodesTimeIntervalSince1970() throws {
        let (aTestVarInstance, _) = try sut()
        XCTAssertEqual(aTestVarInstance.aDate.timeIntervalSince1970, now.timeIntervalSince1970)
    }

    private func sut() throws -> (testInstance: JSONTestData, mockInstance: JSONTestData) {
        let data = testJSON.data(using: .utf8) ?? Data()

        let aTestVarInstance = try jsonDecoder.decode(
            JSONTestData.self,
            from: data
        )

        let aMockTestVar = JSONTestData(aVariable: 1, aDate: now)
        return (aTestVarInstance, aMockTestVar)
    }
}

struct JSONTestData: DecodableResponse {
    let aVariable: Int
    let aDate: Date
}
