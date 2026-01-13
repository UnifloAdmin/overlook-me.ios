import SwiftUI

struct HabitCycleTracker: View {
    let logs: [HabitCompletionLogDTO]
    @State private var visibleMonthYear: String = ""
    
    // Generate days for infinite scrolling
    private var allDays: [WeekDay] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        // Generate 60 days before and 14 days after today
        return (-60...14).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: today) else {
                return nil
            }
            
            let dayLetter = Self.dayLetterFormatter.string(from: date)
            let dayNumber = Self.dayNumberFormatter.string(from: date)
            let isToday = calendar.isDateInToday(date)
            
            // Format dates as strings for stable comparison
            // UI Day -> Local YYYY-MM-DD
            let dayKey = Self.localDayKeyFormatter.string(from: date)
            
            // Check if this day is before habit started
            let isBeforeStart: Bool
            if let startLog = logs.compactMap({ Self.parseDate($0.date) }).min() {
                // Log -> UTC YYYY-MM-DD (to extract the intended date)
                let startKey = Self.utcDayKeyFormatter.string(from: startLog)
                isBeforeStart = dayKey < startKey
            } else {
                isBeforeStart = true
            }
            
            let status = isBeforeStart ? nil : findStatus(for: dayKey)
            
            return WeekDay(
                id: dayKey,
                date: date,
                dayLetter: dayLetter,
                dayNumber: dayNumber,
                isToday: isToday,
                isBeforeStart: isBeforeStart,
                status: status
            )
        }
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // Header with simple date context
            HStack {
                Text("History")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(visibleMonthYear.isEmpty ? dateHeaderText : visibleMonthYear)
                    .font(.caption)
                    .foregroundStyle(.secondary) // Changed from tertiary to secondary for better visibility
            }
            .padding(.horizontal, 4)
            
            // Horizontally scrolling timeline
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 10) {
                        ForEach(allDays) { day in
                            DayView(day: day)
                                .id(day.id)
                                .onAppear {
                                    updateVisibleMonth(from: day.date)
                                }
                        }
                    }
                    .padding(.horizontal, 4)
                }
                .scrollClipDisabled()
                .onAppear {
                    // Initialize with current month
                    visibleMonthYear = dateHeaderText
                    
                    // Scroll to today
                    if let todayDay = allDays.first(where: { $0.isToday }) {
                        // Small delay to ensure layout is ready
                        DispatchQueue.main.async {
                            withAnimation {
                                proxy.scrollTo(todayDay.id, anchor: .center)
                            }
                        }
                    }
                }
            }
        }
    }
    
    private var dateHeaderText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: Date())
    }
    
    private func updateVisibleMonth(from date: Date) {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        let newString = formatter.string(from: date)
        if visibleMonthYear != newString {
            visibleMonthYear = newString
        }
    }
    
    // MARK: - Helper Logic
    
    private func findStatus(for dayKey: String) -> CycleStatus? {
        // dayKey is already in Local YYYY-MM-DD format
        
        guard let log = logs.first(where: { log in
            guard let logDate = Self.parseDate(log.date) else { return false }
            // Log dates are stored as UTC midnight, so we extract the date part using UTC formatter
            let logKey = Self.utcDayKeyFormatter.string(from: logDate)
            return logKey == dayKey
        }) else {
            // If we don't see a date in logs, that means the user missed that date.
            // We compare the dayKey to today's key.
            let todayKey = Self.localDayKeyFormatter.string(from: Date())
            if dayKey < todayKey {
                return .missed
            }
            return nil
        }
        
        return Self.status(for: log)
    }
    
    private static func status(for log: HabitCompletionLogDTO) -> CycleStatus {
        if log.completed {
            return .checkIn
        } else if log.wasSkipped ?? false {
            return .skipped
        } else {
            return .missed
        }
    }
    
    private static func parseDate(_ string: String) -> Date? {
        if let date = isoFormatterWithFractional.date(from: string) {
            return date
        }
        if let date = isoFormatter.date(from: string) {
            return date
        }
        if let date = isoNoTimezoneDateTimeFormatter.date(from: string) {
            return date
        }
        return isoDateOnlyFormatter.date(from: string)
    }
    
    // MARK: - Models
    
    struct WeekDay: Identifiable {
        let id: String
        let date: Date
        let dayLetter: String
        let dayNumber: String
        let isToday: Bool
        let isBeforeStart: Bool
        let status: CycleStatus?
    }
    
    enum CycleStatus: String {
        case checkIn
        case skipped
        case missed
        
        var color: Color {
            switch self {
            case .checkIn: return .green
            case .skipped: return .orange
            case .missed: return .red
            }
        }
    }
    
    // MARK: - Formatters
    
    private static let isoFormatterWithFractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()
    
    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()

    // Backend may send `"2026-01-12T00:00:00"` (no timezone). Assume UTC.
    private static let isoNoTimezoneDateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return formatter
    }()

    private static let isoDateOnlyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
    
    private static let dayLetterFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEEE" // Single letter
        return formatter
    }()
    
    private static let dayNumberFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter
    }()
    
    // Formatter for UI dates (Local Timezone)
    // Used to generate keys for the days displayed in the tracker
    private static let localDayKeyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.calendar = .current
        formatter.timeZone = .current
        return formatter
    }()
    
    // Formatter for Log dates (UTC)
    // Used to parse/match the YYYY-MM-DD part from the stored UTC logs
    private static let utcDayKeyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()
}

// MARK: - Day View

private struct DayView: View {
    let day: HabitCycleTracker.WeekDay
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(spacing: 6) {
            // Day Letter
            Text(day.dayLetter)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
            
            // Status Circle
            ZStack {
                Circle()
                    .fill(backgroundColor)
                    .frame(width: 36, height: 36)
                
                if shouldShowRing {
                    Circle()
                        .strokeBorder(day.status?.color ?? .clear, lineWidth: 2)
                        .frame(width: 36, height: 36)
                }

                Text(day.dayNumber)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(foregroundColor)
            }
            
            // Indicator dot for today
            if day.isToday {
                Circle()
                    .fill(Color.primary)
                    .frame(width: 4, height: 4)
            } else {
                Spacer().frame(height: 4)
            }
        }
        .frame(width: 44)
        .opacity(day.isBeforeStart ? 0.3 : 1.0)
    }
    
    private var backgroundColor: Color {
        if let status = day.status {
            switch status {
            case .checkIn:
                return .green
            case .skipped:
                return .orange
            case .missed:
                return .red.opacity(0.18) // missed = red tint
            }
        }
        
        // If it's today and no status yet, highlight it slightly
        if day.isToday {
            return Color.primary.opacity(0.1)
        }
        
        return Color(.secondarySystemFill)
    }
    
    private var foregroundColor: Color {
        if let status = day.status {
            switch status {
            case .checkIn, .skipped:
                return .white
            case .missed:
                return .red
            }
        }
        return .primary
    }
    
    private var shouldShowRing: Bool {
        day.status == .missed
    }
}
