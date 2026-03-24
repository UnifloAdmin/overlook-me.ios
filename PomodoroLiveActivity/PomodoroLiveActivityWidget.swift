import ActivityKit
import SwiftUI
import WidgetKit

struct PomodoroLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PomodoroActivityAttributes.self) { context in
            // Lock Screen / Banner
            HStack(spacing: 10) {
                Image("AppLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 28, height: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(context.state.title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(timerInterval: Date()...context.state.endDate, countsDown: true)
                        .font(.system(size: 11, weight: .medium))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(remainingMinutes(until: context.state.endDate))
                    .font(.system(size: 14, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded — appears when user taps the island
                DynamicIslandExpandedRegion(.leading) {
                    Image("AppLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 32, height: 32)
                        .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(timerInterval: Date()...context.state.endDate, countsDown: true)
                        .font(.system(size: 13, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(.primary)
                        .padding(.trailing, 4)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.state.title)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Focus session in progress")
                        .font(.system(size: 10, weight: .regular))
                        .foregroundStyle(.tertiary)
                }

            } compactLeading: {
                // Left side of compact Dynamic Island — logo instead of clock
                Image("AppLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 16, height: 16)

            } compactTrailing: {
                Text(remainingMinutes(until: context.state.endDate))
                    .font(.system(size: 12, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(.primary)

            } minimal: {
                // Minimal — shown when two Live Activities compete for space
                Image("AppLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 14, height: 14)
            }
        }
    }

    private func remainingMinutes(until endDate: Date) -> String {
        let remaining = max(0, Int(endDate.timeIntervalSinceNow / 60))
        return "\(remaining)m"
    }
}
