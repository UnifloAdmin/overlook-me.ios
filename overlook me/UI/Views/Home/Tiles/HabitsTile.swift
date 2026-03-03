import SwiftUI

struct HabitsTile: View {
    @Environment(\.injected) private var container: DIContainer
    @StateObject private var service = HomeHabitsService()

    private var userId: String {
        container.appState.state.auth.user?.id ?? ""
    }

    var body: some View {
        Group {
            if service.state.isLoading {
                shimmer("Habits")
            } else if service.state.failed {
                errorState("Habits") {
                    _Concurrency.Task { await service.refresh(userId: userId) }
                }
            } else {
                card
            }
        }
        .task {
            guard !userId.isEmpty else { return }
            await service.load(userId: userId)
        }
    }

    private var card: some View {
        VStack(spacing: 0) {
            // Ring section
            VStack(spacing: 10) {
                ZStack {
                    Circle()
                        .stroke(Color(.systemFill), lineWidth: 6)
                    Circle()
                        .trim(from: 0, to: CGFloat(service.state.todayPct) / 100)
                        .stroke(Color.indigo, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: service.state.todayPct)

                    VStack(spacing: 0) {
                        Text("\(service.state.todayPct)%")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                        Text("today")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 80, height: 80)

                HStack(spacing: 4) {
                    Image(systemName: "repeat")
                        .font(.system(size: 9))
                        .foregroundStyle(.indigo)
                    Text("Habits")
                        .font(.system(size: 13, weight: .semibold))
                }
            }
            .padding(.top, 20)
            .padding(.bottom, 14)

            Divider().padding(.horizontal, 14)

            // Stats
            VStack(spacing: 8) {
                miniStat("checkmark.circle.fill", .green,
                         "\(service.state.todayCompleted)/\(service.state.todayCount)", "Done today")
                miniStat("flame.fill", .orange,
                         "\(service.state.currentStreaks) days", "Streak")
                miniStat("chart.line.uptrend.xyaxis", .blue,
                         "\(service.state.overallRate)%", "Overall rate")
                miniStat("square.stack.fill", .purple,
                         "\(service.state.activeHabits)", "Active")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)

            Divider().padding(.horizontal, 14)

            // Insight
            Text(service.state.headline)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .lineLimit(3)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func miniStat(_ icon: String, _ color: Color, _ value: String, _ label: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(color)
                .frame(width: 16)
            Text(value)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Spacer(minLength: 0)
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)
                .lineLimit(1)
        }
    }
}

// MARK: - Shared compact tile helpers

func shimmer(_ title: String) -> some View {
    VStack(spacing: 8) {
        ProgressView().tint(.secondary).scaleEffect(0.8)
        Text(title)
            .font(.caption)
            .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .frame(minHeight: 280)
    .background(Color(.secondarySystemGroupedBackground))
    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
}

func errorState(_ title: String, retry: @escaping () -> Void) -> some View {
    VStack(spacing: 8) {
        Image(systemName: "exclamationmark.triangle")
            .font(.title3)
            .foregroundStyle(.secondary)
        Text(title)
            .font(.caption)
            .foregroundStyle(.secondary)
        Button("Retry", action: retry)
            .font(.caption2.bold())
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .frame(minHeight: 280)
    .background(Color(.secondarySystemGroupedBackground))
    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
}

#Preview {
    ZStack {
        Color(.systemGroupedBackground).ignoresSafeArea()
        HStack(alignment: .top, spacing: 12) {
            HabitsTile()
            HabitsTile()
        }
        .padding(.horizontal, 20)
        .environment(\.injected, .previewAuthenticated)
    }
}
