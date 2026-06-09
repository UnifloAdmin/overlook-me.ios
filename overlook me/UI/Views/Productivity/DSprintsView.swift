import SwiftUI
import Observation
import Combine

// MARK: - Hour Slot

struct HourSlot: Identifiable, Equatable {
    let hourSlot: Int
    var label: String
    var note: String
    var status: DSprintStatus
    var moodScore: Int?
    var entryId: String?
    var hashtags: [DSprintHashtagDTO]
    var isCurrentHour: Bool

    var id: Int { hourSlot }
}

// MARK: - ViewModel

@Observable
@MainActor
final class DSprintsViewModel {
    var config: DSprintConfigDTO?
    var slots: [HourSlot] = []
    var selectedDate: String = DSprintsViewModel.todayString()
    var dayTabs: [DayTabItem] = []

    var isLoading = false
    var isSaving = false
    var errorMessage: String?
    var showConfigSheet = false
    var editStartHour: Int = 6
    var editEndHour: Int = 18

    // Hashtag picker
    var hashtagPickerSlot: Int? = nil
    var hashtagQuery: String = ""
    var hashtagResults: [DSprintHashtagDTO] = []
    var hashtagLoading = false

    private let api = DSprintsAPI(client: AppAPIClient.live())
    let pomodoro = PomodoroTimerController(habitId: "dsprints_focus", habitName: "D-Sprints")

    // MARK: Stats

    var filledCount: Int { slots.filter { $0.status != .unfilled }.count }
    var productiveCount: Int { slots.filter { $0.status == .productive }.count }
    var fillPct: Int { slots.isEmpty ? 0 : Int(Double(filledCount) / Double(slots.count) * 100) }
    var moodAvg: String {
        let rated = slots.filter { $0.moodScore != nil }
        guard !rated.isEmpty else { return "—" }
        let avg = Double(rated.compactMap(\.moodScore).reduce(0, +)) / Double(rated.count)
        return String(format: "%.1f", avg)
    }

    var isSelectedToday: Bool { selectedDate == Self.todayString() }
    var currentHour: Int { Calendar.current.component(.hour, from: Date()) }

    /// Slots reordered for display: current hour first, then future ascending, then past descending.
    /// Falls back to chronological order for non-today dates.
    var sortedSlots: [HourSlot] {
        guard isSelectedToday else { return slots }
        let cur = currentHour
        let current = slots.filter { $0.isCurrentHour }
        let future  = slots.filter { $0.hourSlot > cur }.sorted { $0.hourSlot < $1.hourSlot }
        let past    = slots.filter { $0.hourSlot < cur }.sorted { $0.hourSlot > $1.hourSlot }
        return current + future + past
    }

    // MARK: Setup

    func setup(userId: String) async {
        dayTabs = buildDayTabs()
        await loadConfig(userId: userId)
    }

    private func loadConfig(userId: String) async {
        isLoading = true
        do {
            let cfg = try await api.getConfig()
            config = cfg
            editStartHour = cfg.workDayStartHour
            editEndHour = cfg.workDayEndHour
            await loadEntries()
        } catch {
            isLoading = false
        }
    }

    func loadEntries() async {
        isLoading = true
        let start = config?.workDayStartHour ?? 6
        let end = config?.workDayEndHour ?? 18
        do {
            let entries = try await api.getEntries(date: selectedDate)
            let entryMap = Dictionary(uniqueKeysWithValues: entries.map { ($0.hourSlot, $0) })
            let currentH = currentHour
            let isToday = isSelectedToday
            slots = (start..<end).map { h in
                let e = entryMap[h]
                return HourSlot(
                    hourSlot: h,
                    label: "\(fmtHour(h)) – \(fmtHour(h + 1))",
                    note: e?.note ?? "",
                    status: e?.status ?? .unfilled,
                    moodScore: e?.moodScore,
                    entryId: e?.id,
                    hashtags: e?.hashtags ?? [],
                    isCurrentHour: isToday && h == currentH
                )
            }
        } catch {
            let start2 = config?.workDayStartHour ?? 6
            let end2 = config?.workDayEndHour ?? 18
            let currentH = currentHour
            let isToday = isSelectedToday
            slots = (start2..<end2).map { h in
                HourSlot(
                    hourSlot: h,
                    label: "\(fmtHour(h)) – \(fmtHour(h + 1))",
                    note: "", status: .unfilled, moodScore: nil,
                    entryId: nil, hashtags: [],
                    isCurrentHour: isToday && h == currentH
                )
            }
        }
        isLoading = false
    }

    func selectDay(_ date: String) async {
        guard date != selectedDate else { return }
        selectedDate = date
        await loadEntries()
    }

    func saveConfig(userId: String) async {
        guard editStartHour < editEndHour else { return }
        do {
            let tz = TimeZone.current.identifier
            let cfg = try await api.saveConfig(SaveConfigRequest(
                workDayStartHour: editStartHour,
                workDayEndHour: editEndHour,
                timeZone: tz
            ))
            config = cfg
            showConfigSheet = false
            await loadEntries()
        } catch {}
    }

    func saveEntry(slotIndex: Int) async {
        guard slots.indices.contains(slotIndex) else { return }
        let slot = slots[slotIndex]
        isSaving = true
        do {
            let saved = try await api.upsertEntry(UpsertEntryRequest(
                entryDate: selectedDate,
                hourSlot: slot.hourSlot,
                note: slot.note.isEmpty ? nil : slot.note,
                status: slot.status.rawValue,
                moodScore: slot.moodScore
            ))
            if slots.indices.contains(slotIndex) {
                slots[slotIndex].entryId = saved.id
            }
        } catch {}
        isSaving = false
    }

    // MARK: Status / Mood

    func setStatus(_ status: DSprintStatus, slotIndex: Int) async {
        guard slots.indices.contains(slotIndex) else { return }
        slots[slotIndex].status = status
        await saveEntry(slotIndex: slotIndex)
    }

    func toggleMood(_ mood: Int, slotIndex: Int) async {
        guard slots.indices.contains(slotIndex) else { return }
        slots[slotIndex].moodScore = slots[slotIndex].moodScore == mood ? nil : mood
        await saveEntry(slotIndex: slotIndex)
    }

    func updateNote(_ note: String, slotIndex: Int) {
        guard slots.indices.contains(slotIndex) else { return }
        slots[slotIndex].note = note
    }

    func commitNote(slotIndex: Int) async {
        await saveEntry(slotIndex: slotIndex)
    }

    // MARK: Hashtags

    func openHashtagPicker(slotIndex: Int) {
        let slot = slots[slotIndex]
        if hashtagPickerSlot == slot.hourSlot {
            closeHashtagPicker()
            return
        }
        hashtagPickerSlot = slot.hourSlot
        hashtagQuery = ""
        _Concurrency.Task { await fetchHashtags(query: "") }
    }

    func closeHashtagPicker() {
        hashtagPickerSlot = nil
        hashtagQuery = ""
        hashtagResults = []
    }

    func fetchHashtags(query: String) async {
        hashtagLoading = true
        do { hashtagResults = try await api.searchHashtags(query: query) } catch {}
        hashtagLoading = false
    }

    func selectHashtag(_ hashtag: DSprintHashtagDTO, slotIndex: Int) {
        closeHashtagPicker()
        _Concurrency.Task {
            var slot = slots[slotIndex]
            if slot.entryId == nil {
                await saveEntry(slotIndex: slotIndex)
                try? await _Concurrency.Task.sleep(for: .milliseconds(400))
            }
            guard slots.indices.contains(slotIndex), !slots[slotIndex].hashtags.contains(hashtag) else { return }
            guard let entryId = slots[slotIndex].entryId else { return }
            do {
                let attached = try await api.attachHashtag(entryId: entryId, hashtagId: hashtag.id)
                slots[slotIndex].hashtags.append(attached)
            } catch {}
        }
    }

    func createAndAttachHashtag(slotIndex: Int) {
        let name = hashtagQuery.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "#", with: "")
        guard !name.isEmpty else { return }
        closeHashtagPicker()
        _Concurrency.Task {
            do {
                let created = try await api.createHashtag(name: name)
                if slots.indices.contains(slotIndex) {
                    selectHashtag(created, slotIndex: slotIndex)
                }
            } catch {}
        }
    }

    func removeHashtag(_ hashtag: DSprintHashtagDTO, slotIndex: Int) {
        guard slots.indices.contains(slotIndex),
              let entryId = slots[slotIndex].entryId else { return }
        slots[slotIndex].hashtags.removeAll { $0.id == hashtag.id }
        _Concurrency.Task {
            try? await api.detachHashtag(entryId: entryId, hashtagId: hashtag.id)
        }
    }

    // MARK: Helpers

    func fmtHour(_ h: Int) -> String {
        var comps = DateComponents()
        comps.hour = h; comps.minute = 0
        let date = Calendar.current.date(from: comps) ?? Date()
        let fmt = DateFormatter()
        fmt.dateFormat = "h:mm a"
        return fmt.string(from: date)
    }

    private func buildDayTabs() -> [DayTabItem] {
        let today = Self.todayString()
        let fmt = DateFormatter(); fmt.dateFormat = "YYYY-MM-dd"
        let dayFmt = DateFormatter(); dayFmt.dateFormat = "EEE"
        let shortFmt = DateFormatter(); shortFmt.dateFormat = "MMM d"
        let todayDate = fmt.date(from: today) ?? Date()

        return (-3...3).map { offset in
            let date = Calendar.current.date(byAdding: .day, value: offset, to: todayDate) ?? todayDate
            let dateStr = fmt.string(from: date)
            return DayTabItem(
                date: dateStr,
                label: offset == 0 ? "Today" : dayFmt.string(from: date),
                sublabel: shortFmt.string(from: date),
                isToday: offset == 0
            )
        }
    }

    static func todayString() -> String {
        let fmt = DateFormatter(); fmt.dateFormat = "YYYY-MM-dd"
        return fmt.string(from: Date())
    }
}

struct DayTabItem: Identifiable {
    let date: String
    let label: String
    let sublabel: String
    let isToday: Bool
    var id: String { date }
}

// MARK: - Main View

struct DSprintsView: View {
    @SwiftUI.Environment(\.injected) private var container: DIContainer
    @State private var viewModel = DSprintsViewModel()
    @State private var clockTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    @State private var saveTimer: AnyCancellable?
    @State private var now = Date()
    @State private var showFocusSheet = false
    @State private var scrollProxy: ScrollViewProxy?
    @State private var borderPulse = false

    private var userId: String {
        container.appState.state.auth.user?.id ?? ""
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    headerTile
                    focusEntryTile
                    if viewModel.isLoading {
                        loadingState
                    } else if viewModel.slots.isEmpty {
                        emptyState
                    } else {
                        timelineTiles
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 60)
            }
            .onAppear { scrollProxy = proxy }
            .scrollContentBackground(.hidden)
            .background(Kalshi.bg)
            .navigationTitle("D-Sprints")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        viewModel.showConfigSheet = true
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Kalshi.textSecondary)
                    }
                }
            }
            .sheet(isPresented: $viewModel.showConfigSheet) { configSheet }
            .sheet(isPresented: $showFocusSheet) {
                PomodoroSheet(name: "D-Sprints", controller: viewModel.pomodoro)
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
                    .presentationBackground(.regularMaterial)
            }
            .onReceive(clockTimer) { t in now = t }
            .onReceive(viewModel.pomodoro.$isRunning) { running in
                guard running else { return }
                let hour = clampedScrollTarget()
                _Concurrency.Task {
                    try? await _Concurrency.Task.sleep(for: .milliseconds(300))
                    withAnimation(.easeInOut(duration: 0.45)) {
                        scrollProxy?.scrollTo(hour, anchor: .top)
                    }
                }
            }
            .task {
                await viewModel.setup(userId: userId)
                let hour = clampedScrollTarget()
                try? await _Concurrency.Task.sleep(for: .milliseconds(400))
                withAnimation(.easeInOut(duration: 0.45)) {
                    scrollProxy?.scrollTo(hour, anchor: .top)
                }
                withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                    borderPulse = true
                }
            }
            .refreshable { await viewModel.loadEntries() }
        }
    }

    // MARK: - Focus Entry Tile

    @ViewBuilder
    private var focusEntryTile: some View {
        Button { showFocusSheet = true } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(viewModel.pomodoro.isRunning ? Kalshi.green.opacity(0.12) : Kalshi.dividerBg)
                        .frame(width: 36, height: 36)
                    Image(systemName: viewModel.pomodoro.isRunning ? "timer" : "play.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(viewModel.pomodoro.isRunning ? Kalshi.green : Kalshi.textSecondary)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("FOCUS TIMER")
                        .font(.system(size: 9, weight: .semibold))
                        .tracking(0.6)
                        .foregroundStyle(Kalshi.textMuted)
                    if viewModel.pomodoro.isRunning, let end = viewModel.pomodoro.endDate {
                        Text(timerInterval: Date()...end, countsDown: true)
                            .font(.system(size: 14, weight: .bold))
                            .monospacedDigit()
                            .foregroundStyle(Kalshi.textPrimary)
                    } else {
                        Text("\(viewModel.pomodoro.focusMinutes) min · tap to start")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Kalshi.textSecondary)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Kalshi.textMuted)
            }
            .padding(.horizontal, Kalshi.cardPadH)
            .padding(.vertical, 12)
            .kalshiCard()
        }
        .buttonStyle(KPressButtonStyle())
    }

    // MARK: - Header Tile (Kalshi card style)

    private var headerTile: some View {
        VStack(spacing: 0) {
            // ── Eyebrow + status badge ──
            HStack {
                Text("HOURLY JOURNAL")
                    .kalshiEyebrow()
                Spacer()
                if viewModel.isSaving {
                    Text("SAVING")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(0.6)
                        .foregroundStyle(Kalshi.textMuted)
                        .padding(.horizontal, 6).padding(.vertical, 1)
                        .background(Kalshi.dividerBg, in: Capsule())
                } else {
                    Text(statusBadgeLabel)
                        .font(.system(size: 10, weight: .bold))
                        .tracking(0.6)
                        .foregroundStyle(statusBadgeFg)
                        .padding(.horizontal, 6).padding(.vertical, 1)
                        .background(statusBadgeBg, in: Capsule())
                }
            }
            .padding(.horizontal, Kalshi.cardPadH)
            .padding(.top, Kalshi.cardPadTop)
            .padding(.bottom, 6)

            // ── Hero number ──
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text("\(viewModel.fillPct)%")
                    .font(.system(size: 32, weight: .bold))
                    .tracking(-1.28)
                    .foregroundStyle(Kalshi.textPrimary)
                Spacer()
                progressRing
            }
            .padding(.horizontal, Kalshi.cardPadH)
            .padding(.bottom, 10)

            // ── Metrics strip ──
            HStack(spacing: 0) {
                metricCell("\(viewModel.filledCount)/\(viewModel.slots.count)", "LOGGED", Kalshi.textPrimary)
                metricDivider
                metricCell("\(viewModel.productiveCount)h", "PRODUCTIVE", Kalshi.green)
                metricDivider
                metricCell(viewModel.moodAvg, "MOOD", Kalshi.amber)
            }
            .padding(.horizontal, Kalshi.cardPadH)
            .padding(.vertical, 10)
        }
        .kalshiCard()
    }

    private func metricCell(_ value: String, _ label: String, _ color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 14, weight: .bold))
                .tracking(-0.28)
                .foregroundStyle(color)
            Text(label)
                .kalshiMetricLabel()
        }
        .frame(maxWidth: .infinity)
    }

    private var metricDivider: some View {
        Rectangle().fill(Kalshi.cardBorder).frame(width: 1, height: 26)
    }

    private var progressRing: some View {
        ZStack {
            Circle().stroke(Kalshi.barUnfilled, lineWidth: 3)
            Circle()
                .trim(from: 0, to: CGFloat(viewModel.fillPct) / 100)
                .stroke(Kalshi.textPrimary, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(Kalshi.normal, value: viewModel.fillPct)
            Text("\(viewModel.fillPct)%")
                .font(.system(size: 7, weight: .bold))
                .foregroundStyle(Kalshi.textPrimary)
        }
        .frame(width: 30, height: 30)
    }

    // Status badge helpers
    private var statusBadgeLabel: String {
        let pct = viewModel.fillPct
        if pct == 100 { return "ALL LOGGED" }
        if pct >= 75  { return "ALMOST" }
        if pct > 0    { return "IN PROGRESS" }
        return "NOT STARTED"
    }
    private var statusBadgeFg: Color {
        let pct = viewModel.fillPct
        if pct == 100 { return Kalshi.greenDk }
        if pct >= 75  { return Kalshi.blue }
        if pct > 0    { return Kalshi.textSecondary }
        return Kalshi.textMuted
    }
    private var statusBadgeBg: Color {
        let pct = viewModel.fillPct
        if pct == 100 { return Kalshi.greenBg }
        if pct >= 75  { return Color(red: 0.87, green: 0.93, blue: 1.0) }
        return Kalshi.dividerBg
    }

    // MARK: - Hour Countdown

    @ViewBuilder
    private func hourCountdown(slot: HourSlot) -> some View {
        let cal = Calendar.current
        let currentH = cal.component(.hour, from: now)
        let minute   = cal.component(.minute, from: now)

        if viewModel.isSelectedToday {
            if slot.hourSlot == currentH {
                // Minutes left in this hour
                let minsLeft = 59 - minute
                Text("\(minsLeft)m left")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .tracking(-0.2)
                    .foregroundStyle(minsLeft <= 10 ? Kalshi.red : Kalshi.amber)
            } else if slot.hourSlot > currentH {
                // Hours (and minutes) until this slot starts
                let totalMins = (slot.hourSlot - currentH) * 60 - minute
                let label = totalMins >= 60
                    ? "in \(totalMins / 60)h"
                    : "in \(totalMins)m"
                Text(label)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(Kalshi.textMuted)
            }
            // Past hours: nothing
        }
    }

    // MARK: - Timeline Tiles

    private var timelineTiles: some View {
        VStack(spacing: 10) {
            ForEach(viewModel.sortedSlots) { slot in
                if let index = viewModel.slots.firstIndex(where: { $0.id == slot.id }) {
                    hourTile(slot: slot, index: index)
                }
            }
        }
    }

    private func hourTile(slot: HourSlot, index: Int) -> some View {
        VStack(alignment: .leading, spacing: Kalshi.cardGap) {
            // ── Header ──
            HStack(spacing: 6) {
                Text(slot.label)
                    .font(.system(
                        size: slot.isCurrentHour ? 12 : 11,
                        weight: slot.isCurrentHour ? .bold : .semibold,
                        design: .monospaced
                    ))
                    .tracking(0.1)
                    .foregroundStyle(slot.isCurrentHour ? Kalshi.blue : Kalshi.textSecondary)
                if slot.isCurrentHour {
                    Text("NOW")
                        .font(.system(size: 9, weight: .black))
                        .tracking(0.8)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Kalshi.blue, in: Capsule())
                }
                Spacer()
                hourCountdown(slot: slot)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, slot.isCurrentHour ? 5 : 0)
            .background(
                slot.isCurrentHour
                    ? RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Kalshi.blue.opacity(0.06))
                    : nil
            )

            // ── Status menu ──
            Menu {
                ForEach(DSprintStatus.allCases, id: \.self) { status in
                    Button {
                        _Concurrency.Task { await viewModel.setStatus(status, slotIndex: index) }
                    } label: {
                        Text("\(status.emoji) \(status.label)")
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(slot.status.emoji).font(.system(size: 10))
                    Text(slot.status.label)
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(0.1)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8, weight: .semibold))
                }
                .foregroundStyle(statusColor(slot.status))
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(statusColor(slot.status).opacity(0.08), in: Capsule())
                .overlay(Capsule().stroke(statusColor(slot.status).opacity(0.25), lineWidth: 1))
            }
            .animation(Kalshi.micro, value: slot.status)

            // ── Note editor ──
            noteEditor(slot: slot, index: index)

            // ── Mood ──
            moodRow(slot: slot, index: index)

            // ── Hashtags ──
            hashtagRow(slot: slot, index: index)
        }
        .padding(.horizontal, Kalshi.cardPadH)
        .padding(.top, slot.isCurrentHour ? Kalshi.cardPadTop + 4 : Kalshi.cardPadTop)
        .padding(.bottom, slot.isCurrentHour ? Kalshi.cardPadBot + 4 : Kalshi.cardPadBot)
        .kalshiCard()
        .overlay(
            slot.isCurrentHour
                ? RoundedRectangle(cornerRadius: Kalshi.cardRadius, style: .continuous)
                    .stroke(Kalshi.blue.opacity(borderPulse ? 0.7 : 0.3), lineWidth: 2)
                : nil
        )
        .id(slot.hourSlot)
    }

    private func noteEditor(slot: HourSlot, index: Int) -> some View {
        let binding = Binding<String>(
            get: { viewModel.slots.indices.contains(index) ? viewModel.slots[index].note : "" },
            set: { viewModel.updateNote($0, slotIndex: index) }
        )
        return TextEditor(text: binding)
            .font(.system(size: 13, weight: .regular))
            .tracking(-0.13)
            .foregroundStyle(Kalshi.textPrimary)
            .frame(minHeight: 38, maxHeight: 110)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .scrollContentBackground(.hidden)
            .background(Kalshi.inputBg, in: RoundedRectangle(cornerRadius: Kalshi.cardRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Kalshi.cardRadius, style: .continuous)
                    .stroke(Kalshi.inputBorder, lineWidth: 1)
            )
            .overlay(alignment: .topLeading) {
                if binding.wrappedValue.isEmpty {
                    Text(slot.isCurrentHour ? "What are you working on right now?" : "What did you work on this hour?")
                        .font(.system(size: 13))
                        .foregroundStyle(Kalshi.textPlaceholder)
                        .padding(.top, 10)
                        .padding(.leading, 14)
                        .allowsHitTesting(false)
                }
            }
            .onChange(of: binding.wrappedValue) { _, _ in scheduleSave(index: index) }
    }

    private func moodRow(slot: HourSlot, index: Int) -> some View {
        HStack(spacing: 5) {
            Text("MOOD")
                .kalshiMetricLabel()
                .padding(.trailing, 2)
            ForEach([1, 2, 3, 4, 5], id: \.self) { m in
                let emojis = ["😞", "😐", "🙂", "😊", "🔥"]
                Button {
                    _Concurrency.Task { await viewModel.toggleMood(m, slotIndex: index) }
                } label: {
                    Text(emojis[m - 1])
                        .font(.system(size: 16))
                        .opacity(slot.moodScore == nil ? 0.4 : (slot.moodScore == m ? 1.0 : 0.2))
                        .scaleEffect(slot.moodScore == m ? 1.1 : 1.0)
                        .animation(Kalshi.micro, value: slot.moodScore)
                }
                .buttonStyle(KPressButtonStyle())
            }
        }
    }

    private func hashtagRow(slot: HourSlot, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            FlowLayout(spacing: 5) {
                ForEach(slot.hashtags) { tag in
                    HStack(spacing: 3) {
                        Text("#\(tag.name)")
                            .font(.system(size: 10, weight: .semibold))
                            .tracking(0.1)
                            .foregroundStyle(tagColor(tag))
                        Button {
                            viewModel.removeHashtag(tag, slotIndex: index)
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 7, weight: .bold))
                                .foregroundStyle(tagColor(tag).opacity(0.6))
                        }
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(tagColor(tag).opacity(0.07), in: Capsule())
                    .overlay(Capsule().stroke(tagColor(tag).opacity(0.18), lineWidth: 1))
                }
                Button {
                    viewModel.openHashtagPicker(slotIndex: index)
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "plus")
                            .font(.system(size: 8, weight: .bold))
                        Text("tag")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundStyle(Kalshi.textMuted)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Kalshi.dividerBg, in: Capsule())
                    .overlay(Capsule().stroke(Kalshi.cardBorder, lineWidth: 1))
                }
                .buttonStyle(KPressButtonStyle())
            }

            if viewModel.hashtagPickerSlot == slot.hourSlot {
                hashtagPicker(slot: slot, index: index)
            }
        }
    }

    private func hashtagPicker(slot: HourSlot, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Kalshi.textMuted)
                TextField("#tag…", text: Binding(
                    get: { viewModel.hashtagQuery },
                    set: { q in
                        viewModel.hashtagQuery = q
                        _Concurrency.Task { await viewModel.fetchHashtags(query: q) }
                    }
                ))
                .font(.system(size: 12))
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .foregroundStyle(Kalshi.textPrimary)
                Button { viewModel.closeHashtagPicker() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Kalshi.textMuted)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)

            Rectangle().fill(Kalshi.cardBorder).frame(height: 1)

            if viewModel.hashtagLoading {
                HStack { Spacer(); ProgressView().scaleEffect(0.75); Spacer() }.padding(10)
            } else {
                let filtered = viewModel.hashtagResults.filter { !slot.hashtags.contains($0) }
                if filtered.isEmpty && !viewModel.hashtagQuery.isEmpty {
                    Button {
                        viewModel.createAndAttachHashtag(slotIndex: index)
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "plus").font(.system(size: 10, weight: .bold))
                            (Text("Create ") + Text("#\(viewModel.hashtagQuery.replacingOccurrences(of: "#", with: ""))").bold())
                                .font(.system(size: 12))
                        }
                        .foregroundStyle(Kalshi.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 9)
                    }
                } else if filtered.isEmpty {
                    Text("Type to search or create")
                        .font(.system(size: 11))
                        .foregroundStyle(Kalshi.textMuted)
                        .padding(10)
                } else {
                    ForEach(filtered.prefix(8)) { tag in
                        Button { viewModel.selectHashtag(tag, slotIndex: index) } label: {
                            HStack(spacing: 7) {
                                Circle().fill(tagColor(tag)).frame(width: 7, height: 7)
                                Text("#\(tag.name)")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(Kalshi.textPrimary)
                                Spacer()
                                if tag.usageCount > 0 {
                                    Text("\(tag.usageCount)")
                                        .font(.system(size: 10))
                                        .foregroundStyle(Kalshi.textMuted)
                                }
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                        }
                        Rectangle().fill(Kalshi.cardBorder).frame(height: 1).padding(.leading, 26)
                    }
                }
            }
        }
        .background(Kalshi.bg, in: RoundedRectangle(cornerRadius: Kalshi.cardRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Kalshi.cardRadius, style: .continuous)
                .stroke(Kalshi.cardBorder, lineWidth: 1)
        )
    }

    // MARK: - Loading / Empty

    private var loadingState: some View {
        VStack(spacing: 1) {
            ForEach(0..<6, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 0)
                    .fill(Kalshi.dividerBg.opacity(0.5))
                    .frame(height: 80)
            }
        }
        .padding(.top, 1)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "clock")
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(Kalshi.textMuted)
            Text("No work hours configured")
                .font(.system(size: 14, weight: .semibold))
                .tracking(-0.28)
                .foregroundStyle(Kalshi.textPrimary)
            Text("Set your working hours to start logging your day.")
                .font(.system(size: 12))
                .foregroundStyle(Kalshi.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button("Set Work Hours") { viewModel.showConfigSheet = true }
                .buttonStyle(KalshiPillButtonStyle(isPrimary: true))
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 56)
    }

    // MARK: - Config Sheet

    private var configSheet: some View {
        NavigationStack {
            Form {
                Section("Work Day Hours") {
                    Picker("Start Hour", selection: Binding(
                        get: { viewModel.editStartHour },
                        set: { viewModel.editStartHour = $0 }
                    )) {
                        ForEach(0..<23, id: \.self) { h in Text(viewModel.fmtHour(h)).tag(h) }
                    }
                    Picker("End Hour", selection: Binding(
                        get: { viewModel.editEndHour },
                        set: { viewModel.editEndHour = $0 }
                    )) {
                        ForEach(1..<24, id: \.self) { h in Text(viewModel.fmtHour(h)).tag(h) }
                    }
                }
                if viewModel.editStartHour >= viewModel.editEndHour {
                    Section {
                        Text("End hour must be after start hour.")
                            .font(.caption).foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Work Hours")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { viewModel.showConfigSheet = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        _Concurrency.Task { await viewModel.saveConfig(userId: userId) }
                    }
                    .disabled(viewModel.editStartHour >= viewModel.editEndHour)
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Helpers

    private func clampedScrollTarget() -> Int {
        let start = viewModel.config?.workDayStartHour ?? 6
        let end   = viewModel.config?.workDayEndHour   ?? 18
        return min(max(viewModel.currentHour, start), end - 1)
    }

    private func scheduleSave(index: Int) {
        saveTimer?.cancel()
        saveTimer = Just(index)
            .delay(for: .milliseconds(600), scheduler: RunLoop.main)
            .sink { i in _Concurrency.Task { await viewModel.commitNote(slotIndex: i) } }
    }

    private func statusColor(_ status: DSprintStatus) -> Color {
        switch status {
        case .unfilled:   return Kalshi.textMuted
        case .productive: return Kalshi.green
        case .break:      return Kalshi.amber
        case .meeting:    return Kalshi.blue
        case .blocked:    return Kalshi.red
        }
    }

    private func tagColor(_ tag: DSprintHashtagDTO) -> Color {
        guard let hex = tag.color else { return Kalshi.textPrimary }
        return Color(hex: hex)
    }
}


// MARK: - Shimmer modifier (reuse if already defined, else define locally)

private extension View {
    @ViewBuilder
    func shimmering() -> some View {
        self.overlay(
            LinearGradient(
                colors: [.clear, .white.opacity(0.4), .clear],
                startPoint: .leading,
                endPoint: .trailing
            )
            .rotationEffect(.degrees(20))
            .blendMode(.screen)
        )
    }
}
