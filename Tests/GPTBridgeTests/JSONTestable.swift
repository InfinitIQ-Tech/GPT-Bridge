//
//  JSONTestable.swift
//
//
//  Created by Kenneth Dubroff on 2/25/24.
//

import XCTest

protocol JSONTestable {
    func toInstance<T: Decodable>(from jsonString: String, to targetType: T.Type, usingKeyDecodingStrategy keyStrategy: JSONDecoder.KeyDecodingStrategy, file: StaticString, line: UInt) throws -> T
}

enum JSONError: Error {
    case invalidJSONString
    case invalidJSONData
}

extension JSONTestable {
    func toInstance<T: Decodable>(from jsonString: String, to targetType: T.Type, usingKeyDecodingStrategy keyStrategy: JSONDecoder.KeyDecodingStrategy = .convertFromSnakeCase, file: StaticString = #file, line: UInt = #line) throws -> T {
        guard let data = jsonString.data(using: .utf8) else {
            XCTFail("The string couldn't be converted to data", file: file, line: line)
            throw JSONError.invalidJSONString
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = keyStrategy

        do {
            let object = try decoder.decode(targetType, from: data)
            return object
        } catch {
            XCTFail("The data was converted from String successfully but failed decoding to \(targetType).", file: file, line: line)
            throw error
        }
    }
}

extension XCTestCase: JSONTestable {}


class JSONTestAbleTests: XCTestCase {
    struct JSONTest: Equatable, Codable {
        let num: Int
        let aString: String

        static func ==(lhs: JSONTest, rhs: JSONTest) -> Bool {
            lhs.num == rhs.num && lhs.aString == rhs.aString
        }
    }

    let testInstance = JSONTest(num: 1, aString: "test")
    let validJSON = """
                    { "a_string":"test","num":1 }
                    """

    func testToJSONData() throws {
        let testInstance = try toInstance(from: validJSON, to: JSONTest.self)
        XCTAssertEqual(testInstance, self.testInstance)
    }
}
