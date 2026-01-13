import Foundation
import ActivityKit

struct PomodoroActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var endDate: Date
        var title: String
    }
    
    var habitId: String
}
