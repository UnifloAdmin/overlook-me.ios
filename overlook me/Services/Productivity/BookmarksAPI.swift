import Foundation

struct BookmarksAPI: Sendable {
    let client: any APIClient

    init(client: any APIClient) {
        self.client = client
    }
}

enum ReadingStatus: Int, Codable, Sendable {
    case unread = 0
    case inProgress = 1
    case completed = 2
    case archived = 3
}

struct BookmarkTagDTO: Codable, Sendable, Identifiable {
    let id: String
    let name: String
    let color: String
}

struct BookmarkCollectionDTO: Codable, Sendable, Identifiable {
    let id: String
    let name: String
    let description: String?
    let color: String?
    let icon: String?
    let isFavorite: Bool?
    let sortOrder: Int?
    let parentCollectionId: String?
    let bookmarkCount: Int?
}

struct BookmarkDTO: Codable, Sendable, Identifiable {
    let id: String
    let userId: String
    let url: String
    let title: String
    let description: String?
    let domain: String?
    let readingStatus: ReadingStatus?
    let isFavorite: Bool?
    let isArchived: Bool?
    let priority: String?
    let notes: String?
    let color: String?
    let sortOrder: Int?
    let tags: [BookmarkTagDTO]?
    let collections: [BookmarkCollectionDTO]?
    let createdAt: String?
    let updatedAt: String?
}

struct CreateBookmarkRequestDTO: Codable, Sendable {
    let url: String
    let title: String?
    let description: String?
    let thumbnailUrl: String?
    let faviconUrl: String?
    let readingStatus: ReadingStatus?
    let readingTimeMinutes: Int?
    let isFavorite: Bool?
    let priority: String?
    let notes: String?
    let addedFrom: String?
    let color: String?
    let tags: [String]?
    let collectionIds: [String]?
}

struct UpdateBookmarkRequestDTO: Codable, Sendable {
    let url: String?
    let title: String?
    let description: String?
    let thumbnailUrl: String?
    let faviconUrl: String?
    let readingStatus: ReadingStatus?
    let readingTimeMinutes: Int?
    let isFavorite: Bool?
    let isArchived: Bool?
    let priority: String?
    let notes: String?
    let color: String?
    let sortOrder: Int?
}

struct CreateCollectionRequestDTO: Codable, Sendable {
    let name: String
    let description: String?
    let parentCollectionId: String?
    let color: String?
    let icon: String?
    let isFavorite: Bool?
    let sortOrder: Int?
}

struct LinkBookmarkRequestDTO: Codable, Sendable {
    let entityType: String
    let entityId: String
    let purpose: String?
    let isResearch: Bool?
    let isResource: Bool?
}

extension BookmarksAPI {
    /// GET `/bookmarks`
    func getBookmarks(params: [String: String?]) async throws -> [BookmarkDTO] {
        try await client.request(.get, path: "bookmarks", query: params, headers: [:], body: nil)
    }

    /// POST `/bookmarks?userId=...`
    func createBookmark(userId: String, bookmark: CreateBookmarkRequestDTO) async throws -> BookmarkDTO {
        try await client.request(.post, path: "bookmarks", query: ["userId": userId], headers: [:], body: bookmark)
    }

    /// PUT `/bookmarks/{id}?userId=...`
    func updateBookmark(id: String, userId: String, bookmark: UpdateBookmarkRequestDTO) async throws -> BookmarkDTO {
        try await client.request(.put, path: "bookmarks/\(id)", query: ["userId": userId], headers: [:], body: bookmark)
    }

    /// DELETE `/bookmarks/{id}?userId=...`
    func deleteBookmark(id: String, userId: String) async throws -> [String: JSONValue] {
        try await client.request(.delete, path: "bookmarks/\(id)", query: ["userId": userId], headers: [:], body: nil)
    }

    /// PATCH `/bookmarks/{id}/favorite?userId=...`
    func toggleFavorite(id: String, userId: String) async throws -> BookmarkDTO {
        try await client.request(.patch, path: "bookmarks/\(id)/favorite", query: ["userId": userId], headers: [:], body: JSONValue.object([:]))
    }

    /// POST `/bookmarks/{id}/tags?userId=...&tagName=...&color=...`
    func addTag(id: String, userId: String, tagName: String, color: String? = nil) async throws -> BookmarkDTO {
        try await client.request(
            .post,
            path: "bookmarks/\(id)/tags",
            query: ["userId": userId, "tagName": tagName, "color": color],
            headers: [:],
            body: JSONValue.object([:])
        )
    }

    /// POST `/bookmarks/{id}/collections?userId=...&collectionId=...`
    func addToCollection(id: String, userId: String, collectionId: String) async throws -> BookmarkDTO {
        try await client.request(
            .post,
            path: "bookmarks/\(id)/collections",
            query: ["userId": userId, "collectionId": collectionId],
            headers: [:],
            body: collectionId
        )
    }

    /// POST `/bookmarks/{id}/link/goal?userId=...`
    func linkToGoal(id: String, userId: String, linkRequest: LinkBookmarkRequestDTO) async throws -> BookmarkDTO {
        try await client.request(.post, path: "bookmarks/\(id)/link/goal", query: ["userId": userId], headers: [:], body: linkRequest)
    }

    /// GET `/bookmarks/collections?userId=...&includeHierarchy=...&includeCount=...`
    func getCollections(userId: String, includeHierarchy: Bool = false, includeCount: Bool = true) async throws -> [BookmarkCollectionDTO] {
        try await client.request(
            .get,
            path: "bookmarks/collections",
            query: ["userId": userId, "includeHierarchy": String(includeHierarchy), "includeCount": String(includeCount)],
            headers: [:],
            body: nil
        )
    }

    /// POST `/bookmarks/collections?userId=...`
    func createCollection(userId: String, collection: CreateCollectionRequestDTO) async throws -> BookmarkCollectionDTO {
        try await client.request(.post, path: "bookmarks/collections", query: ["userId": userId], headers: [:], body: collection)
    }
}

