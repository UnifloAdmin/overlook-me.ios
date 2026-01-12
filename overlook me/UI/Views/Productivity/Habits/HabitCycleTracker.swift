import SwiftUI

struct HabitCycleTracker: View {
    let logs: [HabitCompletionLogDTO]
    
    private var preparedLogs: [PreparedLog] {
        let sorted = logs.compactMap(Self.prepareLog).sorted { $0.date < $1.date }
        return Array(sorted.suffix(14))
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent check-ins")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(preparedLogs) { log in
                        pill(for: log)
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .padding(.top, 6)
    }
    
    private func pill(for log: PreparedLog) -> some View {
        VStack(spacing: 6) {
            Text(log.dayLabel.uppercased())
                .font(.caption2.weight(.heavy))
                .foregroundStyle(.secondary)
            
            Text(log.dayNumber)
                .font(.title3.monospacedDigit().weight(.semibold))
            
            Text(log.status.shortLabel)
                .font(.caption2.weight(.semibold))
        }
        .frame(width: 54, height: 96)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(log.status.tint.opacity(0.12))
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(log.status.tint.opacity(0.45), lineWidth: 1)
        )
        .foregroundStyle(log.status.tint)
    }
    
    private static func prepareLog(_ log: HabitCompletionLogDTO) -> PreparedLog? {
        guard let date = parseDate(log.date) else { return nil }
        let status = status(for: log)
        return PreparedLog(
            id: "\(log.date)_\(status.rawValue)",
            date: date,
            dayLabel: dayFormatter.string(from: date),
            dayNumber: dayNumberFormatter.string(from: date),
            status: status
        )
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
        return isoFormatter.date(from: string)
    }
    
    private struct PreparedLog: Identifiable {
        let id: String
        let date: Date
        let dayLabel: String
        let dayNumber: String
        let status: CycleStatus
    }
    
    private enum CycleStatus: String {
        case checkIn
        case skipped
        case missed
        
        var tint: Color {
            switch self {
            case .checkIn:
                return .green
            case .skipped:
                return .yellow
            case .missed:
                return .red
            }
        }
        
        var caption: String {
            switch self {
            case .checkIn:
                return "Check-in"
            case .skipped:
                return "Skipped"
            case .missed:
                return "Missed"
            }
        }
        
        var shortLabel: String {
            switch self {
            case .checkIn:
                return "Win"
            case .skipped:
                return "Skip"
            case .missed:
                return "Miss"
            }
        }
    }
    
    private static let isoFormatterWithFractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
    
    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
    
    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter
    }()
    
    private static let dayNumberFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter
    }()
}
