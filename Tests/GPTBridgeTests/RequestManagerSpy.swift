//
//  RequestManagerSpy.swift
//
//
//  Created by Kenneth Dubroff on 6/2/24.
//

import Foundation
@testable import GPTBridge

struct RequestManagerSpy: RequestManageable {
    let baseURL: URL = URL(string: Self.baseURLString)!
    var mockRequest: EncodableRequest!
}
