import Foundation

struct DSprintsAPI: Sendable {
    let client: any APIClient

    init(client: any APIClient) {
        self.client = client
    }
}

// MARK: - DTOs

enum DSprintStatus: String, Codable, Sendable, CaseIterable {
    case unfilled
    case productive
    case `break`
    case meeting
    case blocked

    var label: String {
        switch self {
        case .unfilled:   return "Unfilled"
        case .productive: return "Productive"
        case .break:      return "Break"
        case .meeting:    return "Meeting"
        case .blocked:    return "Blocked"
        }
    }

    var emoji: String {
        switch self {
        case .unfilled:   return "○"
        case .productive: return "⚡"
        case .break:      return "☕"
        case .meeting:    return "👥"
        case .blocked:    return "⛔"
        }
    }
}

struct DSprintHashtagDTO: Codable, Sendable, Identifiable, Equatable {
    let id: String
    let name: String
    let color: String?
    let usageCount: Int
}

struct DSprintEntryDTO: Codable, Sendable, Identifiable {
    let id: String?
    let userId: String?
    let entryDate: String
    let hourSlot: Int
    let note: String?
    let status: DSprintStatus
    let moodScore: Int?
    let hashtags: [DSprintHashtagDTO]?
}

struct DSprintConfigDTO: Codable, Sendable {
    let id: String?
    let userId: String?
    let workDayStartHour: Int
    let workDayEndHour: Int
    let timeZone: String
}

struct SaveConfigRequest: Codable, Sendable {
    let workDayStartHour: Int
    let workDayEndHour: Int
    let timeZone: String
}

struct UpsertEntryRequest: Codable, Sendable {
    let entryDate: String
    let hourSlot: Int
    let note: String?
    let status: String
    let moodScore: Int?
}

struct AttachHashtagRequest: Codable, Sendable {
    let entryId: String
    let hashtagId: String
}

struct CreateHashtagRequest: Codable, Sendable {
    let name: String
}

// MARK: - API Calls

extension DSprintsAPI {

    func getConfig() async throws -> DSprintConfigDTO {
        try await client.request(.get, path: "dsprints/config", query: [:], headers: [:], body: nil)
    }

    func saveConfig(_ body: SaveConfigRequest) async throws -> DSprintConfigDTO {
        try await client.request(.post, path: "dsprints/config", query: [:], headers: [:], body: body)
    }

    func getEntries(date: String) async throws -> [DSprintEntryDTO] {
        try await client.request(.get, path: "dsprints/entries", query: ["date": date], headers: [:], body: nil)
    }

    func upsertEntry(_ body: UpsertEntryRequest) async throws -> DSprintEntryDTO {
        try await client.request(.post, path: "dsprints/entries", query: [:], headers: [:], body: body)
    }

    func searchHashtags(query: String = "") async throws -> [DSprintHashtagDTO] {
        let q: [String: String?] = query.isEmpty ? [:] : ["search": query]
        return try await client.request(.get, path: "hashtags", query: q, headers: [:], body: nil)
    }

    func createHashtag(name: String) async throws -> DSprintHashtagDTO {
        try await client.request(.post, path: "hashtags", query: [:], headers: [:], body: CreateHashtagRequest(name: name))
    }

    func attachHashtag(entryId: String, hashtagId: String) async throws -> DSprintHashtagDTO {
        try await client.request(.post, path: "hashtags/attach", query: [:], headers: [:], body: AttachHashtagRequest(entryId: entryId, hashtagId: hashtagId))
    }

    func detachHashtag(entryId: String, hashtagId: String) async throws {
        let _: EmptyResponse = try await client.request(.delete, path: "hashtags/detach", query: [:], headers: [:], body: AttachHashtagRequest(entryId: entryId, hashtagId: hashtagId))
    }
}
