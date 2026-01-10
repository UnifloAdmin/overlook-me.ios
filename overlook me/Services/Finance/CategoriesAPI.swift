import Foundation

struct CategoriesAPI: Sendable {
    let client: any APIClient

    init(client: any APIClient) {
        self.client = client
    }
}

typealias SystemCategoryDTO = [String: JSONValue]
typealias SubcategoryDTO = [String: JSONValue]
typealias UserCategoryDTO = [String: JSONValue]
typealias CategorySpendingDTO = [String: JSONValue]

struct CreateUserCategoryRequestDTO: Codable, Sendable {
    let name: String
    let icon: String
    let color: String
    let parentCategoryId: Int?
}

extension CategoriesAPI {
    /// GET `/categories` (unified endpoint; varies by `type`)
    func getCategories(query: [String: String?]) async throws -> JSONValue {
        try await client.request(.get, path: "categories", query: query, headers: [:], body: nil)
    }

    /// POST `/categories/user/{userId}`
    func createUserCategory(userId: String, category: CreateUserCategoryRequestDTO) async throws -> UserCategoryDTO {
        try await client.request(.post, path: "categories/user/\(userId)", query: [:], headers: [:], body: category)
    }

    /// PUT `/categories/user/{userId}/{categoryId}`
    func updateUserCategory(userId: String, categoryId: Int, category: [String: JSONValue]) async throws -> EmptyResponse {
        try await client.request(.put, path: "categories/user/\(userId)/\(categoryId)", query: [:], headers: [:], body: category)
    }

    /// DELETE `/categories/user/{userId}/{categoryId}`
    func deleteUserCategory(userId: String, categoryId: Int) async throws -> EmptyResponse {
        try await client.request(.delete, path: "categories/user/\(userId)/\(categoryId)", query: [:], headers: [:], body: nil)
    }
}

