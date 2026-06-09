import SwiftUI
import Observation

// MARK: - Day Summary

struct DSprintDaySummary: Identifiable {
    let date: String          // "YYYY-MM-dd"
    let displayDate: String   // "Mon, May 12"
    let isToday: Bool
    let totalSlots: Int
    let filledSlots: Int
    let productiveSlots: Int
    let moodAvg: Double?
    let entries: [DSprintEntryDTO]

    var id: String { date }
    var fillPct: Int { totalSlots == 0 ? 0 : Int(Double(filledSlots) / Double(totalSlots) * 100) }
    var moodLabel: String {
        guard let m = moodAvg else { return "—" }
        return String(format: "%.1f", m)
    }
}

// MARK: - ViewModel

@Observable
@MainActor
final class DSprintsHistoryViewModel {
    var summaries: [DSprintDaySummary] = []
    var isLoading = false
    var selectedDate: String? = nil

    private let api = DSprintsAPI(client: AppAPIClient.live())

    func load(config: DSprintConfigDTO?) async {
        isLoading = true
        let start = config?.workDayStartHour ?? 6
        let end   = config?.workDayEndHour   ?? 18
        let totalSlots = end - start

        let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"
        let displayFmt = DateFormatter(); displayFmt.dateFormat = "EEE, MMM d"
        let today = fmt.string(from: Date())
        let todayDate = fmt.date(from: today) ?? Date()

        var results: [DSprintDaySummary] = []
        // Past 14 days including today
        for offset in 0..<14 {
            guard let date = Calendar.current.date(byAdding: .day, value: -offset, to: todayDate) else { continue }
            let dateStr = fmt.string(from: date)
            let display = offset == 0 ? "Today" : displayFmt.string(from: date)
            let entries = (try? await api.getEntries(date: dateStr)) ?? []
            let filled      = entries.filter { $0.status != .unfilled }.count
            let productive  = entries.filter { $0.status == .productive }.count
            let moods       = entries.compactMap(\.moodScore)
            let moodAvg     = moods.isEmpty ? nil : Double(moods.reduce(0, +)) / Double(moods.count)
            results.append(DSprintDaySummary(
                date: dateStr,
                displayDate: display,
                isToday: offset == 0,
                totalSlots: totalSlots,
                filledSlots: filled,
                productiveSlots: productive,
                moodAvg: moodAvg,
                entries: entries
            ))
        }
        summaries = results
        isLoading = false
    }
}

// MARK: - View

struct DSprintsHistoryView: View {
    @State private var viewModel = DSprintsHistoryViewModel()
    @State private var configViewModel = DSprintsViewModel()
    @State private var expandedDate: String? = nil

    var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 10) {
                if viewModel.isLoading {
                    ProgressView()
                        .padding(.top, 60)
                } else if viewModel.summaries.isEmpty {
                    emptyState
                } else {
                    ForEach(viewModel.summaries) { summary in
                        daySummaryTile(summary)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 60)
        }
        .scrollContentBackground(.hidden)
        .background(Kalshi.bg)
        .navigationTitle("History")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await configViewModel.setup(userId: "")
            await viewModel.load(config: configViewModel.config)
        }
        .refreshable {
            await viewModel.load(config: configViewModel.config)
        }
    }

    // MARK: Day tile

    private func daySummaryTile(_ summary: DSprintDaySummary) -> some View {
        let isExpanded = expandedDate == summary.date
        return VStack(spacing: 0) {
            // ── Header row ──
            Button {
                withAnimation(Kalshi.normal) {
                    expandedDate = isExpanded ? nil : summary.date
                }
            } label: {
                HStack(spacing: 10) {
                    // Date column
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 5) {
                            if summary.isToday {
                                Text("TODAY")
                                    .font(.system(size: 9, weight: .bold))
                                    .tracking(0.6)
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 5).padding(.vertical, 2)
                                    .background(Kalshi.blue, in: Capsule())
                            }
                            Text(summary.displayDate)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Kalshi.textPrimary)
                        }
                        fillBar(pct: summary.fillPct)
                    }

                    Spacer()

                    // Stats strip
                    HStack(spacing: 12) {
                        miniStat("\(summary.fillPct)%", "LOGGED")
                        miniStat("\(summary.productiveSlots)h", "FOCUS")
                        miniStat(summary.moodLabel, "MOOD")
                    }

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Kalshi.textMuted)
                }
                .padding(.horizontal, Kalshi.cardPadH)
                .padding(.vertical, 12)
            }
            .buttonStyle(KPressButtonStyle())

            // ── Expanded: hour breakdown ──
            if isExpanded {
                KalshiDivider().padding(.horizontal, Kalshi.cardPadH)
                hourBreakdown(summary)
                    .padding(.horizontal, Kalshi.cardPadH)
                    .padding(.bottom, 12)
            }
        }
        .kalshiCard()
    }

    private func hourBreakdown(_ summary: DSprintDaySummary) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if summary.entries.filter({ $0.status != .unfilled }).isEmpty {
                Text("Nothing logged this day.")
                    .font(.system(size: 12))
                    .foregroundStyle(Kalshi.textMuted)
                    .padding(.top, 10)
            } else {
                ForEach(summary.entries.filter { $0.status != .unfilled }) { entry in
                    HStack(spacing: 8) {
                        // Hour label
                        Text(hourLabel(entry.hourSlot))
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundStyle(Kalshi.textMuted)
                            .frame(width: 80, alignment: .leading)

                        // Status dot
                        Circle()
                            .fill(statusDotColor(entry.status))
                            .frame(width: 6, height: 6)

                        // Note
                        Text(entry.note?.isEmpty == false ? entry.note! : entry.status.label)
                            .font(.system(size: 12))
                            .foregroundStyle(entry.note?.isEmpty == false ? Kalshi.textPrimary : Kalshi.textSecondary)
                            .lineLimit(1)

                        Spacer()

                        if let mood = entry.moodScore {
                            let emojis = ["😞", "😐", "🙂", "😊", "🔥"]
                            Text(emojis[safe: mood - 1] ?? "")
                                .font(.system(size: 12))
                        }
                    }
                    .padding(.top, 6)
                }
            }
        }
    }

    // MARK: Helpers

    private func fillBar(pct: Int) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Kalshi.barUnfilled)
                Capsule()
                    .fill(pct >= 80 ? Kalshi.green : pct >= 40 ? Kalshi.amber : Kalshi.textMuted)
                    .frame(width: geo.size.width * CGFloat(pct) / 100)
            }
        }
        .frame(width: 80, height: 3)
    }

    private func miniStat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 12, weight: .bold))
                .tracking(-0.2)
                .foregroundStyle(Kalshi.textPrimary)
            Text(label)
                .kalshiMetricLabel()
        }
    }

    private func hourLabel(_ h: Int) -> String {
        var c = DateComponents(); c.hour = h; c.minute = 0
        let d = Calendar.current.date(from: c) ?? Date()
        let f = DateFormatter(); f.dateFormat = "h:mm a"
        return f.string(from: d)
    }

    private func statusDotColor(_ status: DSprintStatus) -> Color {
        switch status {
        case .productive: return Kalshi.green
        case .break:      return Kalshi.amber
        case .meeting:    return Kalshi.blue
        case .blocked:    return Kalshi.red
        case .unfilled:   return Kalshi.textMuted
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(Kalshi.textMuted)
            Text("No history yet")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Kalshi.textSecondary)
            Text("Start logging your hours in Journal")
                .font(.system(size: 12))
                .foregroundStyle(Kalshi.textMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }
}

// MARK: - Safe subscript

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
