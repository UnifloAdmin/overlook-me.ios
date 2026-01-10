import Foundation

struct CalendarAPI: Sendable {
    let client: any APIClient

    init(client: any APIClient) {
        self.client = client
    }
}

struct CalendarEventDTO: Codable, Sendable, Identifiable {
    let id: String
    let userId: String
    let title: String
    let description: String?
    let location: String?
    let startDateTime: String
    let endDateTime: String?
    let isAllDay: Bool
    let timeZone: String?
    let eventType: String?
    let color: String?
    let isRecurring: Bool?
    let recurrenceRule: String?
    let status: String?
    let privacy: String?
    let isCompleted: Bool?
    let notificationsEnabled: Bool?
    let createdAt: String?
    let updatedAt: String?
}

struct CreateCalendarEventRequestDTO: Codable, Sendable {
    let userId: String
    let title: String
    let description: String?
    let location: String?
    let startDateTime: String
    let endDateTime: String?
    let isAllDay: Bool
    let timeZone: String?
    let eventType: String?
    let color: String?
    let priority: Int?
    let tags: [String]?
    let isRecurring: Bool
    let recurrenceRule: String?
    let recurrenceEndDate: String?
    let status: String?
    let privacy: String
    let notificationsEnabled: Bool?
    let relatedTransactionId: String?
    let relatedBudgetId: String?
}

struct UpdateCalendarEventRequestDTO: Codable, Sendable {
    let userId: String
    let title: String?
    let description: String?
    let location: String?
    let startDateTime: String?
    let endDateTime: String?
    let isAllDay: Bool?
    let timeZone: String?
    let eventType: String?
    let color: String?
    let priority: Int?
    let tags: [String]?
    let isRecurring: Bool?
    let recurrenceRule: String?
    let recurrenceEndDate: String?
    let status: String?
    let privacy: String?
    let isCompleted: Bool?
    let notificationsEnabled: Bool?
}

extension CalendarAPI {
    /// GET `/calendarevents`
    func getEvents(params: [String: String?]) async throws -> [CalendarEventDTO] {
        try await client.request(.get, path: "calendarevents", query: params, headers: [:], body: nil)
    }

    /// POST `/calendarevents`
    func createEvent(_ request: CreateCalendarEventRequestDTO) async throws -> CalendarEventDTO {
        try await client.request(.post, path: "calendarevents", query: [:], headers: [:], body: request)
    }

    /// PUT `/calendarevents/{id}`
    func updateEvent(id: String, request: UpdateCalendarEventRequestDTO) async throws -> CalendarEventDTO {
        try await client.request(.put, path: "calendarevents/\(id)", query: [:], headers: [:], body: request)
    }

    /// DELETE `/calendarevents/{id}?userId=...`
    func deleteEvent(id: String, userId: String) async throws -> EmptyResponse {
        try await client.request(.delete, path: "calendarevents/\(id)", query: ["userId": userId], headers: [:], body: nil)
    }

    /// PATCH `/calendarevents/{id}/complete?userId=...`
    func markAsCompleted(id: String, userId: String) async throws -> JSONValue {
        try await client.request(
            .patch,
            path: "calendarevents/\(id)/complete",
            query: ["userId": userId],
            headers: [:],
            body: JSONValue.object([:])
        )
    }
}

