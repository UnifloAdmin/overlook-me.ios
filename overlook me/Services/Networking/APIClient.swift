import Foundation

protocol APIClient: Sendable {
    func request<T: Decodable>(
        _ method: HTTPMethod,
        path: String,
        query: [String: String?],
        headers: [String: String],
        body: (any Encodable)?
    ) async throws -> T
}

struct EmptyResponse: Decodable {}

