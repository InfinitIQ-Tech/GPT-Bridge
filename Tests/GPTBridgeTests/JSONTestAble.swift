//
//  File.swift
//
//
//  Created by Kenneth Dubroff on 2/25/24.
//

import XCTest

protocol JSONTestAble {
    func toJSONString(from instance: Encodable, using keyEncodingStrategy: JSONEncoder.KeyEncodingStrategy, file: StaticString, line: UInt) throws -> String
    func toJSONData<T: Decodable>(from jsonString: String, to targetType: T.Type, usingKeyDecodingStrategy keyStrategy: JSONDecoder.KeyDecodingStrategy, file: StaticString, line: UInt) throws -> T
}

enum JSONError: Error {
    case invalidJSONString
    case invalidJSONData
}

extension JSONTestAble {
    func toJSONData<T: Decodable>(from jsonString: String, to targetType: T.Type, usingKeyDecodingStrategy keyStrategy: JSONDecoder.KeyDecodingStrategy = .convertFromSnakeCase, file: StaticString = #file, line: UInt = #line) throws -> T {
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

    func toJSONString(from instance: Encodable, using keyEncodingStrategy: JSONEncoder.KeyEncodingStrategy = .convertToSnakeCase, file: StaticString = #file, line: UInt = #line) throws -> String {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = keyEncodingStrategy
        let data = try encoder.encode(instance)
        return String(data: data, encoding: .utf8) ?? ""
    }
}

extension XCTestCase: JSONTestAble {}

struct JSONTest: Equatable, Codable {
    let num: Int
    let aString: String

    static func ==(lhs: JSONTest, rhs: JSONTest) -> Bool {
        lhs.num == rhs.num && lhs.aString == rhs.aString
    }
}

class JSONTestAbleTests: XCTestCase {
    let testInstance = JSONTest(num: 1, aString: "test")
    let validJSON = """
                    { "a_string":"test","num":1 }
                    """
    let invalidJSON = """
                    "num": 1,"a_string": "test"
                    """

    func testToJSONData() throws {
        let testInstance = try toJSONData(from: validJSON, to: JSONTest.self)
        XCTAssertEqual(testInstance, self.testInstance)
    }

    func testToJSONString() throws {
        let string = try toJSONString(from: testInstance, using: .convertToSnakeCase)
        XCTAssert(string.contains("\"a_string\":\"test\""))
        XCTAssert(string.contains("\"num\":1"))
    }
}

