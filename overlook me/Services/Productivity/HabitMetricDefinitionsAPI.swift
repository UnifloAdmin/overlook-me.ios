import Foundation

struct HabitMetricDefinitionsAPI: Sendable {
    let client: any APIClient

    init(client: any APIClient) {
        self.client = client
    }
}

typealias HabitMetricDefinitionDTO = [String: JSONValue]
typealias CreateMetricDefinitionRequestDTO = [String: JSONValue]
typealias UpdateMetricDefinitionRequestDTO = [String: JSONValue]

struct HabitMetricDefinitionResponseDTO: Codable, Sendable {
    let message: String
    let definition: HabitMetricDefinitionDTO
}

extension HabitMetricDefinitionsAPI {
    /// GET `/HabitMetricDefinitions/{habitId}`
    func getMetricDefinitions(habitId: String, userId: String? = nil, oauthId: String? = nil, isActive: Bool? = nil) async throws -> [HabitMetricDefinitionDTO] {
        try await client.request(
            .get,
            path: "HabitMetricDefinitions/\(habitId)",
            query: ["userId": userId, "oauthId": oauthId, "isActive": isActive.map(String.init)],
            headers: [:],
            body: nil
        )
    }

    /// POST `/HabitMetricDefinitions/{habitId}`
    func createMetricDefinition(habitId: String, definition: CreateMetricDefinitionRequestDTO, userId: String? = nil, oauthId: String? = nil) async throws -> HabitMetricDefinitionResponseDTO {
        try await client.request(
            .post,
            path: "HabitMetricDefinitions/\(habitId)",
            query: ["userId": userId, "oauthId": oauthId],
            headers: [:],
            body: definition
        )
    }

    /// PUT `/HabitMetricDefinitions/{habitId}/{definitionId}`
    func updateMetricDefinition(habitId: String, definitionId: String, definition: UpdateMetricDefinitionRequestDTO, userId: String? = nil, oauthId: String? = nil) async throws -> HabitMetricDefinitionResponseDTO {
        try await client.request(
            .put,
            path: "HabitMetricDefinitions/\(habitId)/\(definitionId)",
            query: ["userId": userId, "oauthId": oauthId],
            headers: [:],
            body: definition
        )
    }

    /// DELETE `/HabitMetricDefinitions/{habitId}/{definitionId}`
    func deleteMetricDefinition(habitId: String, definitionId: String, userId: String? = nil, oauthId: String? = nil) async throws -> [String: String] {
        try await client.request(
            .delete,
            path: "HabitMetricDefinitions/\(habitId)/\(definitionId)",
            query: ["userId": userId, "oauthId": oauthId],
            headers: [:],
            body: nil
        )
    }
}

