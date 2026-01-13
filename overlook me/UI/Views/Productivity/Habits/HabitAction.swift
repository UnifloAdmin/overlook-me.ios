import Foundation
import SwiftUI

enum HabitAction {
    case checkIn(DailyHabitDTO)
    case skipDay(DailyHabitDTO)
    case resisted(DailyHabitDTO)
    case failedToResist(DailyHabitDTO)
    
    var habit: DailyHabitDTO {
        switch self {
        case .checkIn(let habit),
             .skipDay(let habit),
             .resisted(let habit),
             .failedToResist(let habit):
            return habit
        }
    }
    
    func makeRequest(selectedDate: Date, isoFormatter: ISO8601DateFormatter) -> LogHabitCompletionRequestDTO {
        // Get start of day in LOCAL timezone (the user's "today")
        let localCalendar = Calendar.current
        let dayStartLocal = localCalendar.startOfDay(for: selectedDate)
        
        // Create a date formatter that uses LOCAL timezone for the date part
        let localDateFormatter = DateFormatter()
        localDateFormatter.dateFormat = "yyyy-MM-dd"
        localDateFormatter.timeZone = localCalendar.timeZone
        let dateString = localDateFormatter.string(from: dayStartLocal) + "T00:00:00.000Z"
        
        let completedAt = isoFormatter.string(from: Date())
        
        let payload: (Bool, Bool) = {
            switch self {
            case .checkIn:
                return (true, false)
            case .skipDay:
                return (false, true)
            case .resisted:
                return (true, false)
            case .failedToResist:
                return (false, false)
            }
        }()
        
        let reason: CompletionReasonDTO? = {
            switch self {
            case .skipDay:
                return CompletionReasonDTO(
                    reasonType: "skip",
                    reasonText: "Skipped from iOS",
                    triggerCategory: "manual",
                    sentiment: nil
                )
            case .failedToResist:
                return CompletionReasonDTO(
                    reasonType: "failure",
                    reasonText: "Marked as failed from iOS",
                    triggerCategory: "manual",
                    sentiment: nil
                )
            default:
                return nil
            }
        }()
        
        return LogHabitCompletionRequestDTO(
            habitId: habit.id,
            date: dateString,
            completed: payload.0,
            value: nil,
            notes: nil,
            wasSkipped: payload.1,
            completedAt: completedAt,
            metrics: [],
            reason: reason,
            generalNotes: nil
        )
    }
}
