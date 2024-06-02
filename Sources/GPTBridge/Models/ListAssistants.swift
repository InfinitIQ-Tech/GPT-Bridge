//
//  File.swift
//  
//
//  Created by Kenneth Dubroff on 3/22/24.
//

import Foundation

public enum PaginationOrder: String, Encodable {
    case ascending = "asc"
    case createdAt = "created_at"
    case descending = "desc"
}
/// Parameters for paginated requests
public struct PaginatedRequestParameters {
    /// A limit on the number of objects to be returned. Limit can range between 1 and 100, and the default is 20.
    private(set) var limit: Int? = nil
    /// Sort order by the created_at timestamp of the objects. asc for ascending order and desc for descending order.
    private(set) var order: PaginationOrder = .createdAt
    /// A cursor for use in pagination. after is an object ID that defines your place in the list. For instance, if you make a list request and receive 100 objects, ending with obj_foo, your subsequent call can include after=obj_foo in order to fetch the next page of the list.
    private(set) var startAfter: String? = nil
    /// A cursor for use in pagination. before is an object ID that defines your place in the list. For instance, if you make a list request and receive 100 objects, ending with obj_foo, your subsequent call can include before=obj_foo in order to fetch the previous page of the list.
    private(set) var startBefore: String? = nil
    /// fetch the next page after the ID in `startAfter`
    public init(
        limit: Int,
        startAfter: String,
        order: PaginationOrder = .createdAt
    ) {
        sharedInit(limit: limit, order: order)
        self.startAfter = startAfter
    }
    /// fetch the previous page before the ID in `startBefore`
    public init(
        limit: Int,
        startBefore: String,
        order: PaginationOrder = .createdAt
    ) {
        sharedInit(limit: limit, order: order)
        self.startBefore = startBefore
    }
    /// fetch the initial request given a limit
    public init(
        limit: Int,
        order: PaginationOrder = .createdAt
    ) {
        sharedInit(limit: limit, order: order)
    }

    mutating
    private func sharedInit(
        limit: Int,
        order: PaginationOrder
    ) {
        self.limit = limit
        self.order = order
    }
}

/// Use this request to list assistants and paginate
/// - NOTE: Leave all options nil if pagination is not required
/// # Usage Example
/// ```swift
/// let request = ListAssistantsRequest(limit: 1)
/// // get the response here <placeholder>
/// if response.hasMore {
///     let lastId = response.lastId
///     // make the next paginated request
///     let request = ListAssistantsRequest(after: lastId, limit: 1)
/// }
/// ```
struct ListAssistantsRequest: EncodableRequest {
    /// A cursor for use in pagination. after is an object ID that defines your place in the list. For instance, if you make a list request and receive 100 objects, ending with obj_foo, your subsequent call can include after=obj_foo in order to fetch the next page of the list.
    let after: String?
    /// A cursor for use in pagination. before is an object ID that defines your place in the list. For instance, if you make a list request and receive 100 objects, ending with obj_foo, your subsequent call can include before=obj_foo in order to fetch the previous page of the list.
    let before: String?
    /// A limit on the number of objects to be returned. Limit can range between 1 and 100, and the default is 20.
    let limit: Int?
    /// Sort order by the created_at timestamp of the objects. asc for ascending order and desc for descending order.
    let order: PaginationOrder?

    init(
        after: String? = nil,
        before: String? = nil,
        limit: Int? = nil,
        order: PaginationOrder? = nil
    ) {
        self.after = after
        self.before = before
        self.limit = limit
        self.order = order
    }
}

public struct ListAssistantsResponse: DecodableResponse {
    public let firstId: String
    public let lastId: String
    public let hasMore: Bool
    public let data: [Assistant]
}

public struct Assistant: Codable, Equatable {
    public let id: String
    public let name: String
    public let description: String?
    public let model: String
    public let instructions: String?

    public init(
        id: String,
        name: String,
        description: String?,
        model: String,
        instructions: String?
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.model = model
        self.instructions = instructions
    }
}
