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
                shimmer("Tasks")
            } else if service.state.failed {
                errorState("Tasks") {
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

    private var accentColor: Color {
        service.state.overdueTasks > 0 ? .red : .green
    }

    private var card: some View {
        VStack(spacing: 0) {
            // Ring section
            VStack(spacing: 10) {
                ZStack {
                    Circle()
                        .stroke(Color(.systemFill), lineWidth: 6)
                    Circle()
                        .trim(from: 0, to: CGFloat(service.state.completionRate) / 100)
                        .stroke(accentColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: service.state.completionRate)

                    VStack(spacing: 0) {
                        Text("\(service.state.completionRate)%")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                        Text("done")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 80, height: 80)

                HStack(spacing: 4) {
                    Image(systemName: "checklist")
                        .font(.system(size: 9))
                        .foregroundStyle(.green)
                    Text("Tasks")
                        .font(.system(size: 13, weight: .semibold))
                }
            }
            .padding(.top, 20)
            .padding(.bottom, 14)

            Divider().padding(.horizontal, 14)

            // Stats
            VStack(spacing: 8) {
                miniStat("calendar", .blue,
                         "\(service.state.dueToday)", "Due today")
                miniStat("calendar.badge.clock", .cyan,
                         "\(service.state.dueThisWeek)", "This week")

                if service.state.overdueTasks > 0 {
                    miniStat("clock.arrow.circlepath", .red,
                             "\(service.state.overdueTasks)", "Overdue")
                } else {
                    miniStat("arrow.triangle.2.circlepath", .teal,
                             "\(service.state.inProgress)", "In progress")
                }

                miniStat("square.stack.fill", .purple,
                         "\(service.state.totalTasks)", "Total")
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

#Preview {
    ZStack {
        Color(.systemGroupedBackground).ignoresSafeArea()
        HStack(alignment: .top, spacing: 12) {
            TasksTile()
            TasksTile()
        }
        .padding(.horizontal, 20)
        .environment(\.injected, .previewAuthenticated)
    }
}
