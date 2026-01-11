import Foundation
import Combine
import SwiftUI

// MARK: - Draft + Options

struct HabitFormDraft {
    var name: String = ""
    var description: String = ""
    var category: HabitCategoryOption = .default
    var icon: HabitIconOption = .default
    var color: HabitColorOption = .default
    var frequency: HabitFrequency = .daily
    var targetValue: Double = 1
    var selectedWeekdays: Set<HabitWeekday> = []
    var remindersEnabled: Bool = false
    var isPinned: Bool = false
    var priority: HabitPriority = .medium
    var isPositive: Bool = true
    var isIndefinite: Bool = true
    var expiryDate: Date?
    var startDate: Date?
    var endDate: Date?
    var scheduledTime: Date?
    var preferredTime: HabitPreferredTime = .unspecified
    var goalType: HabitGoalType = .boolean
    var dailyGoal: String = ""
    var unit: String = ""
    var motivation: String = ""
    var reward: String = ""
    var tags: String = ""
    
    var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    var trimmedDescription: String {
        description.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    var trimmedMotivation: String {
        motivation.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    var trimmedReward: String {
        reward.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    var trimmedDailyGoal: String {
        dailyGoal.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    var trimmedUnit: String {
        unit.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    var trimmedTags: String {
        tags.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    var isNameValid: Bool {
        !trimmedName.isEmpty
    }
    
    func expiryValidationError(asOf today: Date = Date()) -> HabitFormError? {
        guard !isIndefinite, let expiryDate else { return nil }
        let startOfToday = Calendar.current.startOfDay(for: today)
        let startOfExpiry = Calendar.current.startOfDay(for: expiryDate)
        return startOfExpiry < startOfToday ? .expiryInPast : nil
    }
    
    func makeRequest(
        formatter: ISO8601DateFormatter,
        timeZone: TimeZone = .current
    ) throws -> CreateDailyHabitRequestDTO {
        if !isNameValid {
            throw HabitFormError.missingName
        }
        if let expiryError = expiryValidationError() {
            throw expiryError
        }
        
        let categoryValue = category.id
        let dailyGoalValue = trimmedDailyGoal.isEmpty ? nil : trimmedDailyGoal
        let unitValue = trimmedUnit.isEmpty ? nil : trimmedUnit
        let tagsValue = trimmedTags.isEmpty ? nil : trimmedTags
        let motivationValue = trimmedMotivation.isEmpty ? nil : trimmedMotivation
        let rewardValue = trimmedReward.isEmpty ? nil : trimmedReward
        let preferredTimeValue = preferredTime.apiValue
        
        return CreateDailyHabitRequestDTO(
            name: trimmedName,
            description: trimmedDescription.isEmpty ? nil : trimmedDescription,
            category: categoryValue,
            color: color.hex,
            icon: icon.materialName,
            frequency: frequency.rawValue,
            targetDays: targetDaysPayload(),
            dailyGoal: dailyGoalValue,
            goalType: goalType.rawValue,
            targetValue: goalType.supportsTargetValue ? targetValue : nil,
            unit: goalType.supportsUnit ? unitValue : nil,
            preferredTime: preferredTimeValue,
            scheduledTime: scheduledTimePayload(),
            startDate: isoString(for: startDate, formatter: formatter),
            endDate: isoString(for: endDate, formatter: formatter),
            expiryDate: isIndefinite ? nil : expiryISO(with: formatter),
            isIndefinite: isIndefinite,
            remindersEnabled: remindersEnabled,
            priority: priority.displayValue,
            isPinned: isPinned,
            isPositive: isPositive,
            tags: tagsValue,
            motivation: motivationValue,
            reward: rewardValue,
            timeZone: timeZone.identifier
        )
    }
    
    private func targetDaysPayload() -> [String]? {
        switch frequency {
        case .daily:
            return nil
        case .weekdays:
            return HabitWeekday.preset(.weekdays)
        case .weekends:
            return HabitWeekday.preset(.weekends)
        case .custom:
            let sortedDays = selectedWeekdays
                .sorted(by: { $0.sortIndex < $1.sortIndex })
                .map(\.rawValue)
            return sortedDays.isEmpty ? nil : sortedDays
        }
    }
    
    private func expiryISO(with formatter: ISO8601DateFormatter) -> String? {
        isoString(for: expiryDate, formatter: formatter)
    }
    
    private func isoString(for date: Date?, formatter: ISO8601DateFormatter) -> String? {
        guard let date else { return nil }
        return formatter.string(from: date)
    }
    
    private func scheduledTimePayload() -> String? {
        guard let scheduledTime else { return nil }
        return HabitFormDraft.timeFormatter.string(from: scheduledTime)
    }
    
    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()
}

enum HabitFormError: LocalizedError, Equatable {
    case missingUser
    case missingName
    case expiryInPast
    case network(String)
    
    var errorDescription: String? {
        switch self {
        case .missingUser:
            return "We could not determine who is creating this habit."
        case .missingName:
            return "Please enter a habit name."
        case .expiryInPast:
            return "Expiry date cannot be in the past."
        case .network(let message):
            return message
        }
    }
}

enum HabitFrequency: String, CaseIterable, Identifiable {
    case daily
    case weekdays
    case weekends
    case custom
    
    var id: String { rawValue }
    
    var label: String {
        switch self {
        case .daily:
            return "Every Day"
        case .weekdays:
            return "Weekdays"
        case .weekends:
            return "Weekends"
        case .custom:
            return "Custom Days"
        }
    }
}

enum HabitPriority: String, CaseIterable, Identifiable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
    
    var id: String { rawValue }
    var displayValue: String { rawValue }
}

enum HabitWeekday: String, CaseIterable, Identifiable {
    case monday
    case tuesday
    case wednesday
    case thursday
    case friday
    case saturday
    case sunday
    
    var id: String { rawValue }
    
    var shortLabel: String {
        String(rawValue.prefix(3)).capitalized
    }
    
    var sortIndex: Int {
        Self.allCases.firstIndex(of: self) ?? 0
    }
    
    static let weekdayPresetSet: Set<HabitWeekday> = [.monday, .tuesday, .wednesday, .thursday, .friday]
    static let weekendPresetSet: Set<HabitWeekday> = [.saturday, .sunday]
    
    static func preset(_ frequency: HabitFrequency) -> [String]? {
        switch frequency {
        case .weekdays:
            return weekdayPresetSet
                .sorted(by: { $0.sortIndex < $1.sortIndex })
                .map(\.rawValue)
        case .weekends:
            return weekendPresetSet
                .sorted(by: { $0.sortIndex < $1.sortIndex })
                .map(\.rawValue)
        default:
            return nil
        }
    }
}

enum HabitGoalType: String, CaseIterable, Identifiable {
    case boolean
    case numeric
    case duration
    case text
    
    var id: String { rawValue }
    
    var label: String {
        switch self {
        case .boolean:
            return "Yes / No"
        case .numeric:
            return "Count / Quantity"
        case .duration:
            return "Time Spent"
        case .text:
            return "Journal / Notes"
        }
    }
    
    var supportsTargetValue: Bool {
        switch self {
        case .boolean, .text:
            return false
        case .numeric, .duration:
            return true
        }
    }
    
    var supportsUnit: Bool {
        self == .numeric || self == .duration
    }
}

enum HabitPreferredTime: String, CaseIterable, Identifiable {
    case unspecified = ""
    case morning
    case afternoon
    case evening
    case night
    
    var id: String { rawValue.isEmpty ? "any" : rawValue }
    
    var label: String {
        switch self {
        case .unspecified:
            return "Anytime"
        default:
            return rawValue.capitalized
        }
    }
    
    var apiValue: String? {
        rawValue.isEmpty ? nil : rawValue
    }
}

struct HabitCategoryOption: Identifiable, Hashable {
    let id: String
    let label: String
    let icon: String
    let color: String
    
    static let all: [HabitCategoryOption] = [
        .init(id: "Health", label: "Health", icon: "cross.case", color: "#4CAF50"),
        .init(id: "Fitness", label: "Fitness", icon: "figure.run", color: "#2196F3"),
        .init(id: "Learning", label: "Learning", icon: "book", color: "#FF9800"),
        .init(id: "Productivity", label: "Productivity", icon: "chart.bar.fill", color: "#607D8B"),
        .init(id: "Personal", label: "Personal", icon: "person.fill", color: "#9C27B0"),
        .init(id: "Social", label: "Social", icon: "person.3.fill", color: "#E91E63"),
        .init(id: "Finance", label: "Finance", icon: "dollarsign.circle", color: "#00BCD4"),
        .init(id: "Spiritual", label: "Spiritual", icon: "sparkles", color: "#8BC34A")
    ]
    
    static var `default`: HabitCategoryOption {
        all.first { $0.id == "Personal" } ?? all.first!
    }
}

struct HabitIconOption: Identifiable, Hashable {
    let id: UUID = UUID()
    let materialName: String
    let systemImage: String
    
    static let all: [HabitIconOption] = [
        .init(materialName: "fitness_center", systemImage: "dumbbell"),
        .init(materialName: "directions_run", systemImage: "figure.run"),
        .init(materialName: "self_improvement", systemImage: "figure.mind.and.body"),
        .init(materialName: "local_cafe", systemImage: "cup.and.saucer"),
        .init(materialName: "menu_book", systemImage: "book"),
        .init(materialName: "edit", systemImage: "pencil"),
        .init(materialName: "palette", systemImage: "paintpalette"),
        .init(materialName: "music_note", systemImage: "music.note"),
        .init(materialName: "water_drop", systemImage: "drop"),
        .init(materialName: "bedtime", systemImage: "moon.zzz"),
        .init(materialName: "wb_sunny", systemImage: "sun.max"),
        .init(materialName: "restaurant", systemImage: "fork.knife"),
        .init(materialName: "local_hospital", systemImage: "cross.case"),
        .init(materialName: "spa", systemImage: "leaf"),
        .init(materialName: "favorite", systemImage: "heart"),
        .init(materialName: "psychology", systemImage: "brain.head.profile"),
        .init(materialName: "emoji_events", systemImage: "trophy"),
        .init(materialName: "star", systemImage: "star.fill")
    ]
    
    static var `default`: HabitIconOption {
        all.first!
    }
}

struct HabitColorOption: Identifiable, Hashable {
    let id: UUID = UUID()
    let hex: String
    let label: String
    
    var color: Color {
        Color(hex: hex)
    }
    
    static let all: [HabitColorOption] = [
        .init(hex: "#2196F3", label: "Blue"),
        .init(hex: "#4CAF50", label: "Green"),
        .init(hex: "#FF9800", label: "Orange"),
        .init(hex: "#F44336", label: "Red"),
        .init(hex: "#9C27B0", label: "Purple"),
        .init(hex: "#00BCD4", label: "Cyan"),
        .init(hex: "#FFC107", label: "Amber"),
        .init(hex: "#607D8B", label: "Blue Gray")
    ]
    
    static var `default`: HabitColorOption {
        all.first!
    }
}

// MARK: - View Model

@MainActor
final class AddNewHabitViewModel: ObservableObject {
    @Published var draft = HabitFormDraft()
    @Published private(set) var isSaving: Bool = false
    @Published private(set) var lastError: HabitFormError?
    
    private let api: DailyHabitsAPI
    private let isoFormatter: ISO8601DateFormatter
    
    init(
        api: DailyHabitsAPI = DailyHabitsAPI(
            client: LoggingAPIClient(base: AppAPIClient.live())
        )
    ) {
        self.api = api
        self.isoFormatter = ISO8601DateFormatter()
        self.isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    }
    
    func save(userId: String, oauthId: String? = nil) async throws -> DailyHabitDTO {
        guard !isSaving else {
            throw HabitFormError.network("Already saving…")
        }
        
        let request = try draft.makeRequest(formatter: isoFormatter)
#if DEBUG
        logRequest(request, userId: userId, oauthId: oauthId)
#endif
        isSaving = true
        defer { isSaving = false }
        
        do {
            let habit = try await api.createHabit(userId: userId, habit: request, oauthId: oauthId)
#if DEBUG
            print("✅ Create habit succeeded (id: \(habit.id))")
#endif
            lastError = nil
            return habit
        } catch {
#if DEBUG
            print("❌ Create habit failed: \(error)")
#endif
            let message = (error as? LocalizedError)?.errorDescription ?? "Failed to save habit."
            let wrapped = HabitFormError.network(message)
            lastError = wrapped
            throw wrapped
        }
    }
    
#if DEBUG
    private func logRequest(_ request: CreateDailyHabitRequestDTO, userId: String, oauthId: String?) {
        var payload: [String: Any] = [
            "userId": userId,
            "oauthId": oauthId as Any,
            "name": request.name,
            "category": request.category as Any,
            "frequency": request.frequency as Any,
            "goalType": request.goalType as Any,
            "isIndefinite": request.isIndefinite as Any,
            "remindersEnabled": request.remindersEnabled as Any,
            "priority": request.priority as Any,
            "isPinned": request.isPinned as Any
        ]
        
        payload["targetDays"] = request.targetDays as Any
        payload["dailyGoal"] = request.dailyGoal as Any
        payload["targetValue"] = request.targetValue as Any
        payload["unit"] = request.unit as Any
        payload["preferredTime"] = request.preferredTime as Any
        payload["scheduledTime"] = request.scheduledTime as Any
        payload["startDate"] = request.startDate as Any
        payload["endDate"] = request.endDate as Any
        payload["expiryDate"] = request.expiryDate as Any
        payload["tags"] = request.tags as Any
        payload["motivation"] = request.motivation as Any
        payload["reward"] = request.reward as Any
        payload["timeZone"] = request.timeZone as Any
        
        if let jsonData = try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted]),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            print("📤 Create habit payload:\n\(jsonString)")
        } else {
            print("📤 Create habit payload (raw): \(payload)")
        }
    }
#endif
}
