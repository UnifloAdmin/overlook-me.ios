import SwiftUI

struct TasksTile: View {
    @Environment(\.injected) private var container: DIContainer
    @StateObject private var service = HomeTasksService()

    private var userId: String {
        container.appState.state.auth.user?.id ?? ""
    }

    var body: some View {
        Group {
            if service.state.isLoading {
                kalshiShimmer("Tasks")
            } else if service.state.failed {
                kalshiErrorState("Tasks") {
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

    /// Semantic accent: red if overdue, green otherwise.
    private var accentColor: Color {
        service.state.overdueTasks > 0 ? Kalshi.red : Kalshi.green
    }

    private var card: some View {
        VStack(spacing: 0) {
            // Ring section
            VStack(spacing: Kalshi.cardGap) {
                ZStack {
                    Circle()
                        .stroke(Kalshi.dividerBg, lineWidth: 5)
                    Circle()
                        .trim(from: 0, to: CGFloat(service.state.completionRate) / 100)
                        .stroke(accentColor, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(Kalshi.normal, value: service.state.completionRate)

                    VStack(spacing: 0) {
                        Text("\(service.state.completionRate)%")
                            .kalshiMetric()
                        Text("DONE")
                            .kalshiMetricLabel()
                    }
                }
                .frame(width: 76, height: 76)

                Text("Tasks")
                    .kalshiCardTitle()
            }
            .padding(.top, Kalshi.cardPadTop)
            .padding(.bottom, 12)

            KalshiDivider().padding(.horizontal, Kalshi.cardPadH)

            // Stats
            VStack(spacing: 7) {
                taskStat("calendar", Kalshi.blue,
                         "\(service.state.dueToday)", "DUE TODAY")
                taskStat("calendar.badge.clock", Kalshi.textSecondary,
                         "\(service.state.dueThisWeek)", "THIS WEEK")

                if service.state.overdueTasks > 0 {
                    taskStat("clock.arrow.circlepath", Kalshi.red,
                             "\(service.state.overdueTasks)", "OVERDUE")
                } else {
                    taskStat("arrow.triangle.2.circlepath", Kalshi.textSecondary,
                             "\(service.state.inProgress)", "IN PROGRESS")
                }

                taskStat("square.stack.fill", Kalshi.textSecondary,
                         "\(service.state.totalTasks)", "TOTAL")
            }
            .padding(.horizontal, Kalshi.cardPadH)
            .padding(.vertical, 12)

            KalshiDivider().padding(.horizontal, Kalshi.cardPadH)

            // Insight
            Text(service.state.headline)
                .kalshiSecondary()
                .lineLimit(3)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 10)
                .padding(.vertical, 10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .kalshiCard()
    }

    private func taskStat(_ icon: String, _ color: Color, _ value: String, _ label: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundStyle(color)
                .frame(width: 14)
            Text(value)
                .kalshiBody()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Spacer(minLength: 0)
            Text(label)
                .kalshiMetricLabel()
                .lineLimit(1)
        }
    }
}

#Preview {
    ZStack {
        Kalshi.bg.ignoresSafeArea()
        HStack(alignment: .top, spacing: 12) {
            TasksTile()
            TasksTile()
        }
        .padding(.horizontal, 16)
        .environment(\.injected, .previewAuthenticated)
    }
}
