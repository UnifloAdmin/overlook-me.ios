import ActivityKit
import SwiftUI
import WidgetKit

struct PomodoroLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PomodoroActivityAttributes.self) { context in
            // Lock Screen / Banner
            HStack(spacing: 8) {
                Image(systemName: "timer")
                    .foregroundStyle(.orange)
                Text(timerInterval: Date()...context.state.endDate, countsDown: true)
                    .monospacedDigit()
            }
            .padding(12)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "timer")
                        .foregroundStyle(.orange)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(remainingMinutes(until: context.state.endDate))
                        .foregroundStyle(.orange)
                }
            } compactLeading: {
                Image(systemName: "timer")
                    .foregroundStyle(.orange)
            } compactTrailing: {
                Text(remainingMinutes(until: context.state.endDate))
                    .foregroundStyle(.orange)
            } minimal: {
                Image(systemName: "timer")
                    .foregroundStyle(.orange)
            }
        }
    }
    
    private func remainingMinutes(until endDate: Date) -> String {
        let remaining = max(0, Int(endDate.timeIntervalSinceNow / 60))
        return "\(remaining)m"
    }
}

