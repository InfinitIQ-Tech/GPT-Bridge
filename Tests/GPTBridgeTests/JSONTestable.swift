//
//  JSONTestable.swift
//
//
//  Created by Kenneth Dubroff on 2/25/24.
//

import XCTest

protocol JSONTestable {
    func toJSONString(from instance: Any, file: StaticString, line: UInt) throws -> String
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

    private func toSnakeCaseDictionary(_ instance: Any) -> [String: Any] {
        let mirror = Mirror(reflecting: instance)
        var dict = [String: Any]()
        for child in mirror.children {
            if let key = child.label {
                var convertedKey = ""
                for char in key {
                    if char.isUppercase {
                        convertedKey.append("_" + char.lowercased())
                    } else {
                        convertedKey.append(char)
                    }
                }
                dict[convertedKey] = child.value
            }
        }
        return dict
    }

    func toJSONString(from instance: Any, file: StaticString = #file, line: UInt = #line) throws -> String {
        var dict = toSnakeCaseDictionary(instance)
        var data: Data
        if JSONSerialization.isValidJSONObject(dict) {
            data = try JSONSerialization.data(withJSONObject: dict, options: [])
        } else {
            let mirror = Mirror(reflecting: dict)
            dict = [:]
            var returnKey = ""

            for child in mirror.children {
                // value should be a tuple due to prior conversion to dictionary
                if let valueDict = child.value as? (String, Any) {
                    returnKey = valueDict.0
                    // this is a Swift type and fails serialization
                    let swiftTypeInstance = valueDict.1
                    let valueMirror = Mirror(reflecting: swiftTypeInstance)
                    var propertyDict: [String: Any] = [:]

                    for child in valueMirror.children {
                        // property is directly serializable, add to propertyDict
                        if let key = child.label,
                           JSONSerialization.isValidJSONObject([key: child.value]) {
                            propertyDict[key] = child.value
                        } else {
                            // property is not directly serializable, maybe another Swift type
                            let swiftObjectJSONMirror = Mirror(reflecting: child.value)
                            // put each property in a dictionary
                            for child in swiftObjectJSONMirror.children {
                                if let key = child.label {
                                    // make sure data is still serializable
                                    if JSONSerialization.isValidJSONObject([key: child.value]) {
                                        propertyDict[key] = child.value
                                    }
                                }
                            }
                        }
                        // Note: Assumes property is an array
                        if dict[returnKey] != nil,
                           var array = dict[returnKey] as? [Any] {
                            array.append(propertyDict)
                            dict[returnKey] = array
                        } else {
                            dict[returnKey] = [propertyDict]
                        }
                        propertyDict = [:]
                    }
                }
            }

            data = try JSONSerialization.data(withJSONObject: dict, options: [])

        }
        guard let jsonString = String(data: data, encoding: .utf8) else {
            XCTFail("The instance couldn't be converted to data", file: file, line: line)
            throw JSONError.invalidJSONData
        }
        return jsonString
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
    let invalidJSON = """
                    "num": 1,"a_string": "test"
                    """

    func testToJSONData() throws {
        let testInstance = try toInstance(from: validJSON, to: JSONTest.self)
        XCTAssertEqual(testInstance, self.testInstance)
    }

    func testToJSONString() throws {
        let string = try toJSONString(from: testInstance)
        XCTAssert(string.contains("\"a_string\":\"test\""))
        XCTAssert(string.contains("\"num\":1"))
    }
}
