import SwiftUI

struct MoodTrackerView: View {
    @State private var todaysMood: MoodType?
    @State private var moodHistory: [MoodEntry] = []
    @State private var appeared = false
    @Namespace private var moodNamespace

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 16) {
                headerSection
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 16)

                todayCard
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 20)

                if todaysMood == nil {
                    moodPicker
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                weeklyGlass
                    .opacity(appeared ? 1 : 0)

                if !moodHistory.isEmpty {
                    historyGlass
                        .opacity(appeared ? 1 : 0)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 100)
        }
        .scrollContentBackground(.hidden)
        .background(Color(.systemBackground))
        .navigationTitle("Wellness")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            loadPersistedData()
            withAnimation(.spring(duration: 0.5, bounce: 0.12)) { appeared = true }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack {
            Text(Date().formatted(.dateTime.weekday(.wide).month().day()))
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            Image(systemName: "heart.fill")
                .font(.title3)
                .foregroundStyle(Color.wellnessGreen)
                .padding(10)
                .glassEffect(.regular, in: .circle)
        }
    }

    // MARK: - Today Card

    private var todayCard: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Today's Check-in")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .tracking(0.5)

                    Text(todaysMood?.label ?? "How are you feeling?")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(todaysMood != nil ? .primary : .secondary)
                        .contentTransition(.numericText())

                    if let mood = todaysMood {
                        moodIndicatorBar(level: mood.level)
                            .padding(.top, 4)
                            .transition(.scale.combined(with: .opacity))
                    }
                }

                Spacer()

                moodIcon(for: todaysMood, size: .large)
            }

            if todaysMood != nil {
                Divider()
                    .padding(.vertical, 14)
                    .transition(.opacity)

                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "clock")
                            .font(.caption)
                            .foregroundStyle(Color.wellnessGreen)
                        if let todayEntry = moodHistory.first(where: { Calendar.current.isDateInToday($0.date) }) {
                            Text("Logged at \(todayEntry.date.formatted(date: .omitted, time: .shortened))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    Button {
                        withAnimation(.spring(duration: 0.35, bounce: 0.2)) {
                            todaysMood = nil
                            removeTodayEntry()
                        }
                    } label: {
                        Text("Change")
                            .font(.caption.weight(.semibold))
                    }
                    .buttonStyle(.glass)
                    .tint(Color.wellnessGreen)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .padding(20)
        .glassEffect(.regular, in: .rect(cornerRadius: 22, style: .continuous))
        .animation(.spring(duration: 0.4, bounce: 0.15), value: todaysMood)
    }

    // MARK: - Mood Indicator Bar

    private func moodIndicatorBar(level: Int) -> some View {
        HStack(spacing: 5) {
            ForEach(1...5, id: \.self) { index in
                RoundedRectangle(cornerRadius: 3)
                    .fill(index <= level ? levelColor(for: level) : Color(.systemGray5))
                    .frame(width: 22, height: 6)
                    .scaleEffect(x: index <= level ? 1.0 : 0.85, y: 1.0)
                    .animation(.spring(duration: 0.3, bounce: 0.3).delay(Double(index) * 0.04), value: level)
            }
        }
    }

    private func levelColor(for level: Int) -> Color {
        switch level {
        case 5, 4: return Color.wellnessGreen
        case 3: return Color.wellnessGoldLight
        default: return Color.wellnessGold
        }
    }

    // MARK: - Mood Icon

    @ViewBuilder
    private func moodIcon(for mood: MoodType?, size: MoodIconSize) -> some View {
        let dimension: CGFloat = size == .large ? 60 : size == .medium ? 42 : 34
        let iconSize: CGFloat = size == .large ? 22 : size == .medium ? 16 : 13

        ZStack {
            Circle()
                .fill(mood?.iconBackground ?? Color(.systemGray6))
                .frame(width: dimension, height: dimension)

            if let mood = mood {
                Image(systemName: mood.iconName)
                    .font(.system(size: iconSize, weight: .medium))
                    .foregroundStyle(mood.iconColor)
                    .transition(.scale.combined(with: .opacity))
            } else {
                Image(systemName: "plus")
                    .font(.system(size: iconSize, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .animation(.spring(duration: 0.35, bounce: 0.25), value: mood)
    }

    // MARK: - Mood Picker

    private var moodPicker: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Log Your Mood")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.wellnessGreen)
                Text("Select how you're feeling right now")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            VStack(spacing: 8) {
                ForEach(MoodType.allCases) { mood in
                    Button {
                        withAnimation(.spring(duration: 0.4, bounce: 0.2)) {
                            todaysMood = mood
                            logMood(mood)
                        }
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        HStack(spacing: 14) {
                            moodIcon(for: mood, size: .medium)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(mood.label)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(.primary)
                                Text(mood.description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            moodIndicatorBar(level: mood.level)
                        }
                        .padding(14)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(MoodButtonStyle())
                }
            }
        }
        .padding(20)
        .glassEffect(.regular, in: .rect(cornerRadius: 22, style: .continuous))
    }

    // MARK: - Weekly Overview

    private var weeklyGlass: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Weekly Overview")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.wellnessGreen)

                Spacer()

                HStack(spacing: 5) {
                    Circle()
                        .fill(weeklyAverageColor)
                        .frame(width: 7, height: 7)
                    Text(weeklyAverageLabel)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 6) {
                ForEach(weekDays, id: \.0) { day, entry in
                    VStack(spacing: 8) {
                        Text(day)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(isToday(day) ? Color.wellnessGreen : .secondary)

                        ZStack {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(entry?.mood.iconBackground ?? Color(.systemGray6))
                                .frame(width: 38, height: 38)

                            if let entry = entry {
                                Image(systemName: entry.mood.iconName)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(entry.mood.iconColor)
                            } else {
                                Circle()
                                    .fill(Color(.systemGray4))
                                    .frame(width: 5, height: 5)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }

            Divider()

            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.caption)
                    .foregroundStyle(Color.wellnessGreen)
                Text("7-day trend")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Text(trendDescription)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(trendColor)
            }
        }
        .padding(20)
        .glassEffect(.regular, in: .rect(cornerRadius: 22, style: .continuous))
    }

    private var trendDescription: String {
        let entries = weekDays.compactMap { $0.1 }
        guard entries.count >= 2 else { return "Not enough data" }
        let recentAvg = entries.suffix(3).map { $0.mood.score }.reduce(0, +) / Double(min(3, entries.count))
        let olderAvg = entries.prefix(3).map { $0.mood.score }.reduce(0, +) / Double(min(3, entries.count))
        if recentAvg > olderAvg + 0.3 { return "Improving" }
        if recentAvg < olderAvg - 0.3 { return "Declining" }
        return "Stable"
    }

    private var trendColor: Color {
        switch trendDescription {
        case "Improving": return Color.wellnessGreen
        case "Declining": return Color.wellnessGold
        default: return .secondary
        }
    }

    // MARK: - History

    private var historyGlass: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Recent Entries")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.wellnessGreen)

            VStack(spacing: 0) {
                ForEach(Array(moodHistory.prefix(5).enumerated()), id: \.element.id) { index, entry in
                    HStack(spacing: 14) {
                        moodIcon(for: entry.mood, size: .medium)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.mood.label)
                                .font(.subheadline.weight(.medium))
                            Text(entry.date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        moodIndicatorBar(level: entry.mood.level)
                    }
                    .padding(.vertical, 12)

                    if index < min(4, moodHistory.count - 1) {
                        Divider().padding(.leading, 56)
                    }
                }
            }
        }
        .padding(20)
        .glassEffect(.regular, in: .rect(cornerRadius: 22, style: .continuous))
    }

    // MARK: - Helpers

    private var weekDays: [(String, MoodEntry?)] {
        let calendar = Calendar.current
        let today = Date()
        let symbols = calendar.shortWeekdaySymbols
        return (0..<7).map { offset in
            let day = calendar.date(byAdding: .day, value: -(6 - offset), to: today)!
            let symbol = symbols[calendar.component(.weekday, from: day) - 1]
            let entry = moodHistory.first { calendar.isDate($0.date, inSameDayAs: day) }
            return (String(symbol.prefix(1)), entry)
        }
    }

    private func isToday(_ dayInitial: String) -> Bool {
        let calendar = Calendar.current
        let todaySymbol = calendar.shortWeekdaySymbols[calendar.component(.weekday, from: Date()) - 1]
        return String(todaySymbol.prefix(1)) == dayInitial
    }

    private var weeklyAverageLabel: String {
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        let weekEntries = moodHistory.filter { $0.date >= weekAgo }
        guard !weekEntries.isEmpty else { return "No data" }
        let average = weekEntries.map { $0.mood.score }.reduce(0, +) / Double(weekEntries.count)
        if average >= 4 { return "Positive week" }
        if average >= 3 { return "Balanced" }
        if average >= 2 { return "Mixed" }
        return "Challenging"
    }

    private var weeklyAverageColor: Color {
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        let weekEntries = moodHistory.filter { $0.date >= weekAgo }
        guard !weekEntries.isEmpty else { return .gray }
        let average = weekEntries.map { $0.mood.score }.reduce(0, +) / Double(weekEntries.count)
        return average >= 3 ? Color.wellnessGreen : Color.wellnessGold
    }

    // MARK: - Persistence

    private static let storageKey = "com.overlookme.moodEntries"

    private func logMood(_ mood: MoodType) {
        removeTodayEntry()
        let entry = MoodEntry(id: UUID(), date: Date(), mood: mood, note: nil)
        moodHistory.insert(entry, at: 0)
        saveEntries()
    }

    private func removeTodayEntry() {
        moodHistory.removeAll { Calendar.current.isDateInToday($0.date) }
        saveEntries()
    }

    private func loadPersistedData() {
        guard let data = UserDefaults.standard.data(forKey: Self.storageKey),
              let entries = try? JSONDecoder().decode([MoodEntry].self, from: data) else { return }
        moodHistory = entries.sorted { $0.date > $1.date }
        todaysMood = moodHistory.first(where: { Calendar.current.isDateInToday($0.date) })?.mood
    }

    private func saveEntries() {
        let trimmed = Array(moodHistory.prefix(90))
        if let data = try? JSONEncoder().encode(trimmed) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }
}

// MARK: - Supporting Types

private enum MoodIconSize {
    case small, medium, large
}

private struct MoodButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.75 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(duration: 0.2, bounce: 0.3), value: configuration.isPressed)
    }
}

// MARK: - Models

enum MoodType: String, CaseIterable, Identifiable, Codable {
    case great, good, okay, low, bad

    var id: String { rawValue }

    var label: String {
        switch self {
        case .great: return "Excellent"
        case .good: return "Good"
        case .okay: return "Neutral"
        case .low: return "Low"
        case .bad: return "Difficult"
        }
    }

    var description: String {
        switch self {
        case .great: return "Feeling energized and positive"
        case .good: return "Generally feeling well"
        case .okay: return "Neither good nor bad"
        case .low: return "Feeling down or tired"
        case .bad: return "Struggling today"
        }
    }

    var iconName: String {
        switch self {
        case .great: return "arrow.up.circle.fill"
        case .good: return "checkmark.circle.fill"
        case .okay: return "minus.circle.fill"
        case .low: return "arrow.down.circle"
        case .bad: return "exclamationmark.circle"
        }
    }

    var iconColor: Color {
        switch self {
        case .great: return Color(red: 0.18, green: 0.55, blue: 0.34)
        case .good: return Color(red: 0.22, green: 0.65, blue: 0.42)
        case .okay: return Color(red: 0.78, green: 0.60, blue: 0.18)
        case .low: return Color(red: 0.70, green: 0.52, blue: 0.15)
        case .bad: return Color(red: 0.60, green: 0.45, blue: 0.12)
        }
    }

    var iconBackground: Color {
        switch self {
        case .great: return Color(red: 0.92, green: 0.96, blue: 0.93)
        case .good: return Color(red: 0.93, green: 0.97, blue: 0.94)
        case .okay: return Color(red: 0.98, green: 0.96, blue: 0.90)
        case .low: return Color(red: 0.97, green: 0.95, blue: 0.88)
        case .bad: return Color(red: 0.96, green: 0.93, blue: 0.86)
        }
    }

    var level: Int {
        switch self {
        case .great: return 5
        case .good: return 4
        case .okay: return 3
        case .low: return 2
        case .bad: return 1
        }
    }

    var score: Double { Double(level) }
}

struct MoodEntry: Identifiable, Codable {
    let id: UUID
    let date: Date
    let mood: MoodType
    let note: String?
}

#Preview {
    NavigationStack {
        MoodTrackerView()
    }
}
