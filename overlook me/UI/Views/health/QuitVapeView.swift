import SwiftUI

// MARK: - Tab

enum QVTab: String, CaseIterable {
    case log       = "Log Craving"
    case progress  = "Progress"
    case health    = "Health"
}

// MARK: - QuitVapeView

struct QuitVapeView: View {
    @Environment(\.injected) private var container: DIContainer
    @Environment(\.colorScheme) private var cs

    @State private var loading = true
    @State private var hasProfile = false
    @State private var dashboard: QuitVapeDashboardDTO?
    @State private var allCravings: [VapeCravingLogDTO] = []
    @State private var userId = ""

    var activeTab: QVTab = .log
    @State private var appeared = false

    // Log form
    @State private var puffCount = 0
    @State private var intensity = 5
    @State private var selectedTrigger = "stress"
    @State private var selectedCoping = ""
    @State private var notes = ""
    @State private var submitting = false
    @State private var showSuccess = false

    private var api: QuitVapeAPI {
        QuitVapeAPI(client: AppAPIClient.live())
    }

    private var navTitle: String {
        switch activeTab {
        case .log:       return "Log Craving"
        case .progress:  return "Progress"
        case .health:    return "Health Recovery"
        }
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 14) {
                    if loading {
                        loadingState
                    } else if !hasProfile {
                        onboardingCard
                    } else if let dash = dashboard {
                        mainContent(dash)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 20)
                .padding(.bottom, 48)
                .background(Color.kalBackground)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.kalBackground)
        .navigationTitle(navTitle)
        .task { await bootstrap() }
        .refreshable { await loadDashboard() }
        .onAppear {
            withAnimation(.spring(duration: 0.5, bounce: 0.12)) { appeared = true }
        }
    }

    // ────────────────────────────────────────────
    // MARK: - Bootstrap
    // ────────────────────────────────────────────

    private func bootstrap() async {
        if let user = container.appState.state.auth.user {
            userId = user.oauthId
        }
        await loadDashboard()
    }

    private func loadDashboard() async {
        loading = true
        do {
            let dash = try await api.getDashboard(userId: userId)
            dashboard = dash
            hasProfile = true
            if !dash.profile.id.isEmpty {
                do {
                    allCravings = try await api.getCravings(profileId: dash.profile.id, userId: userId)
                } catch {
                    print("⚠️ [QuitVape] Failed to load cravings: \(error)")
                }
            }
        } catch APIError.httpStatus(let code, _) where code == 404 {
            hasProfile = false
        } catch {
            print("❌ [QuitVape] Dashboard load failed: \(error)")
            if dashboard != nil { hasProfile = true } else { hasProfile = false }
        }
        loading = false
    }

    // ────────────────────────────────────────────
    // MARK: - Loading
    // ────────────────────────────────────────────

    private var loadingState: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Loading habits…")
                .font(.system(size: 13))
                .foregroundStyle(Color.kalMuted)
        }
        .frame(maxWidth: .infinity, minHeight: 180)
    }

    // ────────────────────────────────────────────
    // MARK: - Onboarding
    // ────────────────────────────────────────────

    private var onboardingCard: some View {
        kalPanel {
            VStack(spacing: 12) {
                Image(systemName: "poweroff")
                    .font(.system(size: 32))
                    .foregroundStyle(Color.kalDone)

                Text("Track Your Vaping")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.kalPrimary)

                Text("Log daily puffs, resist cravings, watch your health recover.")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.kalMuted)
                    .multilineTextAlignment(.center)

                Button {
                    _Concurrency.Task { await createProfile() }
                } label: {
                    Text("Start Tracking")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.white)
                        .padding(.horizontal, 16).padding(.vertical, 8)
                        .background(Color.kalDone, in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func createProfile() async {
        do {
            _ = try await api.createProfile(userId: userId)
            await loadDashboard()
        } catch {
            print("❌ Create profile failed: \(error)")
        }
    }

    // ────────────────────────────────────────────
    // MARK: - Main Content
    // ────────────────────────────────────────────

    private func mainContent(_ dash: QuitVapeDashboardDTO) -> some View {
        VStack(spacing: 14) {
            switch activeTab {
            case .log:       logTab(dash)
            case .progress:  progressTab(dash)
            case .health:    healthTab(dash)
            }
        }
    }



    // ══════════════════════════════════════════════
    // MARK: - LOG TAB
    // ══════════════════════════════════════════════

    private func logTab(_ dash: QuitVapeDashboardDTO) -> some View {
        VStack(spacing: 14) {
            // Success banner
            if showSuccess {
                HStack(spacing: 5) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.kalDone)
                    Text("Logged")
                        .font(.system(size: 12, weight: .semibold))
                        .tracking(-0.12)
                        .foregroundStyle(Color.kalDone)
                }
                .padding(12)
                .frame(maxWidth: .infinity)
                .background(Color.kalDoneBg, in: Capsule())
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            puffCounterCard
            resistedCard
            todaySummaryCard(dash)

            if !todaysCravings.isEmpty {
                todayEntriesCard
            }
        }
    }

    private var puffCounterCard: some View {
        kalPanel {
            VStack(spacing: 16) {
                sectionLabel("LOG PUFFS")

                HStack(spacing: 20) {
                    Button {
                        if puffCount > 0 { puffCount -= 1 }
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        Image(systemName: "minus")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(Color.kalFail)
                            .frame(width: 48, height: 48)
                            .background(Color.kalFailBg, in: Circle())
                    }
                    .buttonStyle(.plain)

                    Text("\(puffCount)")
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                        .tracking(-1)
                        .foregroundStyle(puffCount > 0 ? Color.kalFail : Color.kalPrimary)
                        .contentTransition(.numericText())
                        .animation(.spring(duration: 0.25), value: puffCount)

                    Button {
                        puffCount += 1
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(Color.kalFail)
                            .frame(width: 48, height: 48)
                            .background(Color.kalFailBg, in: Circle())
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    _Concurrency.Task { await logPuffsOnly() }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .semibold))
                        Text(submitting ? "Logging…" : "Log Puffs")
                            .font(.system(size: 12, weight: .semibold))
                            .tracking(-0.12)
                    }
                    .foregroundStyle(Color.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.kalFail, in: Capsule())
                }
                .disabled(submitting)
                .buttonStyle(.plain)
            }
        }
    }

    private var resistedCard: some View {
        kalPanel {
            VStack(alignment: .leading, spacing: 16) {
                sectionLabel("RESISTED A CRAVING")

                // Trigger
                VStack(alignment: .leading, spacing: 8) {
                    subsectionLabel("WHAT TRIGGERED IT?")

                    FlowLayout(spacing: 6) {
                        ForEach(triggerOptions, id: \.value) { opt in
                            Button {
                                selectedTrigger = opt.value
                                UISelectionFeedbackGenerator().selectionChanged()
                            } label: {
                                Text(opt.label)
                                    .font(.system(size: 11, weight: .semibold))
                                    .tracking(-0.11)
                                    .foregroundStyle(selectedTrigger == opt.value ? .white : Color.kalMuted)
                                    .padding(.horizontal, 13).padding(.vertical, 6)
                                    .background(
                                        selectedTrigger == opt.value ? Color.kalDone : Color.kalInput,
                                        in: Capsule()
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                // Intensity
                VStack(alignment: .leading, spacing: 8) {
                    subsectionLabel("HOW STRONG WAS IT?")

                    HStack(spacing: 5) {
                        ForEach(1...10, id: \.self) { n in
                            Button {
                                intensity = n
                                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                            } label: {
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .fill(n <= intensity
                                          ? (n >= 8 ? Color.kalFail : Color.kalDone)
                                          : Color.kalInput)
                                    .frame(height: 10)
                            }
                            .buttonStyle(.plain)
                        }

                        Text("\(intensity)/10")
                            .font(.system(size: 9, weight: .semibold))
                            .tracking(0.54)
                            .foregroundStyle(Color.kalTertiary)
                            .frame(width: 32)
                    }
                }

                // Coping
                VStack(alignment: .leading, spacing: 8) {
                    subsectionLabel("WHAT HELPED?")

                    FlowLayout(spacing: 6) {
                        ForEach(copingOptions, id: \.value) { opt in
                            Button {
                                selectedCoping = opt.value
                                UISelectionFeedbackGenerator().selectionChanged()
                            } label: {
                                Text(opt.label)
                                    .font(.system(size: 11, weight: .semibold))
                                    .tracking(-0.11)
                                    .foregroundStyle(selectedCoping == opt.value ? .white : Color.kalMuted)
                                    .padding(.horizontal, 13).padding(.vertical, 6)
                                    .background(
                                        selectedCoping == opt.value ? Color.kalDone : Color.kalInput,
                                        in: Capsule()
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                // Notes
                VStack(alignment: .leading, spacing: 6) {
                    subsectionLabel("NOTES")

                    TextField("Optional", text: $notes, axis: .vertical)
                        .font(.system(size: 13))
                        .lineLimit(2...4)
                        .padding(12)
                        .background(Color.kalInput, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }

                // Submit
                Button {
                    _Concurrency.Task { await logResisted() }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "shield.checkered")
                            .font(.system(size: 11, weight: .semibold))
                        Text("I Resisted")
                            .font(.system(size: 12, weight: .semibold))
                            .tracking(-0.12)
                    }
                    .foregroundStyle(Color.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.kalDone, in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func todaySummaryCard(_ dash: QuitVapeDashboardDTO) -> some View {
        HStack(spacing: 0) {
            kalStatCell(value: puffsToday, label: "Puffs")
            kalStatSeparator
            kalStatCell(value: todaysCravings.count, label: "Entries")
            kalStatSeparator
            kalStatCell(value: Int(dash.resistRate), label: "Resisted %")
        }
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.kalSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.kalBorder, lineWidth: 1)
                )
        )
    }

    private var todayEntriesCard: some View {
        kalPanel {
            VStack(alignment: .leading, spacing: 10) {
                sectionLabel("TODAY'S ENTRIES")

                VStack(spacing: 0) {
                    ForEach(Array(todaysCravings.enumerated()), id: \.element.id) { idx, c in
                        cravingRow(c)
                        if idx < todaysCravings.count - 1 {
                            Rectangle().fill(Color.kalBorder).frame(height: 1).padding(.leading, 44)
                        }
                    }
                }
            }
        }
    }

    // ══════════════════════════════════════════════
    // MARK: - PROGRESS TAB
    // ══════════════════════════════════════════════

    private func progressTab(_ dash: QuitVapeDashboardDTO) -> some View {
        VStack(spacing: 14) {
            puffChartCard
            triggerBreakdownCard(dash)
            statsCard(dash)
            historyCard
        }
    }

    private var puffChartCard: some View {
        kalPanel {
            VStack(alignment: .leading, spacing: 12) {
                sectionLabel("PUFFS — LAST 7 DAYS")

                HStack(alignment: .bottom, spacing: 6) {
                    ForEach(last7DaysPuffs, id: \.label) { day in
                        VStack(spacing: 6) {
                            if day.puffs > 0 {
                                Text("\(day.puffs)")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(Color.kalMuted)
                            }

                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(day.puffs == 0 ? Color.kalDoneBg : Color.kalFail)
                                .frame(height: barHeight(day.puffs))

                            Text(day.label)
                                .font(.system(size: 9, weight: .semibold))
                                .tracking(0.54)
                                .foregroundStyle(Color.kalTertiary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: 120)
            }
        }
    }

    private func triggerBreakdownCard(_ dash: QuitVapeDashboardDTO) -> some View {
        kalPanel {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    sectionLabel("TRIGGER BREAKDOWN")
                    Spacer()
                    Text("This week")
                        .font(.system(size: 9, weight: .semibold))
                        .tracking(0.54)
                        .foregroundStyle(Color.kalTertiary)
                }

                let breakdown = triggerBreakdown(dash)
                if breakdown.isEmpty {
                    Text("Log cravings to see patterns")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.kalMuted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                } else {
                    VStack(spacing: 10) {
                        ForEach(breakdown, id: \.trigger) { tb in
                            HStack(spacing: 10) {
                                Text(triggerLabel(tb.trigger))
                                    .font(.system(size: 11, weight: .semibold))
                                    .tracking(-0.11)
                                    .foregroundStyle(Color.kalPrimary)
                                    .frame(width: 80, alignment: .leading)

                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        Capsule().fill(Color.kalInput)
                                        Capsule().fill(Color.kalDone)
                                            .frame(width: CGFloat(tb.pct) / 100.0 * geo.size.width)
                                    }
                                }
                                .frame(height: 6)
                                .clipShape(Capsule())

                                Text("\(tb.count)")
                                    .font(.system(size: 11, weight: .bold))
                                    .tracking(-0.11)
                                    .foregroundStyle(Color.kalMuted)
                                    .frame(width: 24, alignment: .trailing)
                            }
                        }
                    }
                }
            }
        }
    }

    private func statsCard(_ dash: QuitVapeDashboardDTO) -> some View {
        kalPanel {
            VStack(spacing: 0) {
                statsRow(label: "Total Cravings", value: "\(dash.totalCravings)")
                Rectangle().fill(Color.kalBorder).frame(height: 1)
                statsRow(label: "Resisted", value: "\(dash.profile.totalCravingsResisted)", color: Color.kalDone)
                Rectangle().fill(Color.kalBorder).frame(height: 1)
                statsRow(label: "Gave In", value: "\(dash.profile.totalCravingsGivenIn)", color: Color.kalFail)
                Rectangle().fill(Color.kalBorder).frame(height: 1)
                statsRow(label: "Resist Rate", value: "\(Int(dash.resistRate))%")
            }
        }
    }

    private func statsRow(label: String, value: String, color: Color = .kalPrimary) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(Color.kalMuted)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .tracking(-0.28)
                .foregroundStyle(color)
        }
        .padding(.vertical, 10)
    }

    private var historyCard: some View {
        kalPanel {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    sectionLabel("ALL ENTRIES")
                    Spacer()
                    Text("\(allCravings.count)")
                        .font(.system(size: 9, weight: .semibold))
                        .tracking(0.54)
                        .foregroundStyle(Color.kalTertiary)
                }

                if allCravings.isEmpty {
                    Text("No entries yet")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.kalMuted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(allCravings.prefix(20).enumerated()), id: \.element.id) { idx, c in
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(triggerLabel(c.trigger))
                                        .font(.system(size: 14, weight: .semibold))
                                        .tracking(-0.28)
                                        .foregroundStyle(Color.kalPrimary)
                                    Text("\(formatDate(c.occurredAt)) · \(formatTime(c.occurredAt))")
                                        .font(.system(size: 9, weight: .semibold))
                                        .tracking(0.54)
                                        .foregroundStyle(Color.kalTertiary)
                                }

                                Spacer()

                                if c.puffCount > 0 {
                                    Text("\(c.puffCount)p")
                                        .font(.system(size: 11, weight: .bold))
                                        .tracking(-0.11)
                                        .foregroundStyle(Color.kalMuted)
                                        .padding(.horizontal, 7).padding(.vertical, 3)
                                        .background(Color.kalInput, in: Capsule())
                                }

                                Text("\(c.intensity)/10")
                                    .font(.system(size: 11, weight: .bold))
                                    .tracking(-0.11)
                                    .foregroundStyle(Color.kalMuted)

                                cravingBadge(resisted: c.resisted)
                            }
                            .padding(.vertical, 8)

                            if idx < min(19, allCravings.count - 1) {
                                Rectangle().fill(Color.kalBorder).frame(height: 1)
                            }
                        }
                    }
                }
            }
        }
    }

    // ══════════════════════════════════════════════
    // MARK: - HEALTH TAB
    // ══════════════════════════════════════════════

    private func healthTab(_ dash: QuitVapeDashboardDTO) -> some View {
        VStack(spacing: 8) {
            ForEach(Array(dash.healthMilestones.enumerated()), id: \.offset) { _, m in
                milestoneCard(m)
            }
        }
    }

    private func milestoneCard(_ m: HealthMilestoneDTO) -> some View {
        HStack(alignment: .top, spacing: 14) {
            // Icon
            Image(systemName: m.isAchieved ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(m.isAchieved ? Color.kalDone : Color.kalTertiary)
                .frame(width: 26, height: 26)
                .background(
                    Circle().fill(m.isAchieved ? Color.kalDoneBg : Color.kalInput)
                )

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(m.title)
                        .font(.system(size: 14, weight: .semibold))
                        .tracking(-0.28)
                        .foregroundStyle(Color.kalPrimary)
                    Spacer()
                    Text(m.isAchieved ? "ACHIEVED" : milestoneTimeLabel(m.requiredMinutes))
                        .font(.system(size: 9, weight: .semibold))
                        .tracking(0.54)
                        .foregroundStyle(m.isAchieved ? Color.kalDone : Color.kalTertiary)
                        .padding(.horizontal, 7).padding(.vertical, 3)
                        .background(
                            m.isAchieved ? Color.kalDoneBg : Color.kalInput,
                            in: Capsule()
                        )
                }

                Text(m.description)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.kalMuted)
                    .lineLimit(3)

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.kalInput)
                        Capsule().fill(m.isAchieved ? Color.kalDone : Color.kalDone.opacity(0.6))
                            .frame(width: CGFloat(m.progressPercent) / 100.0 * geo.size.width)
                    }
                }
                .frame(height: 6)
                .clipShape(Capsule())

                Text("\(Int(m.progressPercent))%")
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(0.54)
                    .foregroundStyle(Color.kalTertiary)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(m.isAchieved ? Color.kalCardDone : Color.kalSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(m.isAchieved ? Color.kalDone.opacity(0.18) : Color.kalBorder, lineWidth: 1)
                )
        )
    }

    // ────────────────────────────────────────────
    // MARK: - Shared Components
    // ────────────────────────────────────────────

    private func kalStatCell(value: Int, label: String) -> some View {
        VStack(spacing: 3) {
            Text("\(value)")
                .font(.system(size: 20, weight: .bold))
                .tracking(-0.8)
                .foregroundStyle(Color.kalPrimary)
                .contentTransition(.numericText(value: Double(value)))
            Text(label.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .tracking(0.54)
                .foregroundStyle(Color.kalTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    private var kalStatSeparator: some View {
        Rectangle()
            .fill(Color.kalDivider)
            .frame(width: 1, height: 26)
    }

    private func cravingRow(_ c: VapeCravingLogDTO) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.kalMuted)
                .frame(width: 30, height: 30)
                .background(Color.kalInput, in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(triggerLabel(c.trigger))
                    .font(.system(size: 14, weight: .semibold))
                    .tracking(-0.28)
                    .foregroundStyle(Color.kalPrimary)
                Text(timeAgo(c.occurredAt))
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(0.54)
                    .foregroundStyle(Color.kalTertiary)
            }

            Spacer()

            if c.puffCount > 0 {
                Text("\(c.puffCount)p")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(-0.11)
                    .foregroundStyle(Color.kalMuted)
                    .padding(.horizontal, 7).padding(.vertical, 3)
                    .background(Color.kalInput, in: Capsule())
            }

            cravingBadge(resisted: c.resisted)
        }
        .padding(.vertical, 8)
    }

    private func cravingBadge(resisted: Bool) -> some View {
        HStack(spacing: 3) {
            Image(systemName: resisted ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 9))
            Text(resisted ? "RESISTED" : "GAVE IN")
                .font(.system(size: 9, weight: .bold))
                .tracking(0.5)
        }
        .foregroundStyle(resisted ? Color.kalDone : Color.kalFail)
        .padding(.horizontal, 7).padding(.vertical, 3)
        .background(
            resisted ? Color.kalDoneBg : Color.kalFailBg,
            in: Capsule()
        )
    }

    // ────────────────────────────────────────────
    // MARK: - Kalshi Card Helper
    // ────────────────────────────────────────────

    @ViewBuilder
    private func kalPanel<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 12) {
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.kalSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.kalBorder, lineWidth: 1)
                )
        )
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .semibold))
            .tracking(0.54)
            .foregroundStyle(Color.kalTertiary)
    }

    private func subsectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .semibold))
            .tracking(0.54)
            .foregroundStyle(Color.kalTertiary)
    }

    // ────────────────────────────────────────────
    // MARK: - Actions
    // ────────────────────────────────────────────

    private func logPuffsOnly() async {
        guard let profileId = dashboard?.profile.id else { return }
        submitting = true
        do {
            let req = LogCravingRequestDTO(
                intensity: intensity, trigger: selectedTrigger, resisted: false,
                durationSeconds: nil, notes: notes.isEmpty ? nil : notes,
                copingStrategy: selectedCoping.isEmpty ? nil : selectedCoping,
                location: nil, puffCount: puffCount, occurredAt: nil
            )
            _ = try await api.logCraving(profileId: profileId, userId: userId, request: req)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            withAnimation { showSuccess = true }
            resetForm()
            await loadDashboard()
            try? await _Concurrency.Task.sleep(nanoseconds: 3_000_000_000)
            withAnimation { showSuccess = false }
        } catch {
            print("❌ Log puffs failed: \(error)")
        }
        submitting = false
    }

    private func logResisted() async {
        guard let profileId = dashboard?.profile.id else { return }
        submitting = true
        do {
            let req = LogCravingRequestDTO(
                intensity: intensity, trigger: selectedTrigger, resisted: true,
                durationSeconds: nil, notes: notes.isEmpty ? nil : notes,
                copingStrategy: selectedCoping.isEmpty ? nil : selectedCoping,
                location: nil, puffCount: 0, occurredAt: nil
            )
            _ = try await api.logCraving(profileId: profileId, userId: userId, request: req)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            withAnimation { showSuccess = true }
            resetForm()
            await loadDashboard()
            try? await _Concurrency.Task.sleep(nanoseconds: 3_000_000_000)
            withAnimation { showSuccess = false }
        } catch {
            print("❌ Log resisted failed: \(error)")
        }
        submitting = false
    }

    private func resetForm() {
        puffCount = 0
        intensity = 5
        selectedTrigger = "stress"
        selectedCoping = ""
        notes = ""
    }

    // ────────────────────────────────────────────
    // MARK: - Computed
    // ────────────────────────────────────────────

    private var puffsToday: Int {
        let today = todayKey
        return allCravings
            .filter { $0.occurredAt.hasPrefix(today) }
            .reduce(0) { $0 + $1.puffCount }
    }

    private var todaysCravings: [VapeCravingLogDTO] {
        let today = todayKey
        return allCravings.filter { $0.occurredAt.hasPrefix(today) }
    }

    private var todayKey: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }

    private var last7DaysPuffs: [(label: String, puffs: Int)] {
        let dayNames = Calendar.current.shortWeekdaySymbols
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return (0..<7).reversed().map { offset in
            let d = Calendar.current.date(byAdding: .day, value: -offset, to: Date())!
            let key = f.string(from: d)
            let puffs = allCravings
                .filter { $0.occurredAt.hasPrefix(key) }
                .reduce(0) { $0 + $1.puffCount }
            let day = Calendar.current.component(.weekday, from: d)
            return (dayNames[day - 1], puffs)
        }.reversed().map { ($0.0, $0.1) }
    }

    private func barHeight(_ puffs: Int) -> CGFloat {
        let maxPuffs = max(last7DaysPuffs.map(\.puffs).max() ?? 1, 1)
        let ratio = CGFloat(puffs) / CGFloat(maxPuffs)
        return max(4, ratio * 80)
    }

    private func moneySaved(_ dash: QuitVapeDashboardDTO) -> String {
        let v = dash.moneySavedDollars
        return v >= 1000 ? "$\(String(format: "%.1f", v / 1000))k" : "$\(Int(v))"
    }

    private func streakProgress(_ dash: QuitVapeDashboardDTO) -> CGFloat {
        guard dash.profile.longestStreakDays > 0 else { return 0 }
        return CGFloat(dash.profile.currentStreakDays) / CGFloat(dash.profile.longestStreakDays)
    }

    private struct TriggerBreakdownItem {
        let trigger: String
        let count: Int
        let pct: Int
    }

    private func triggerBreakdown(_ dash: QuitVapeDashboardDTO) -> [TriggerBreakdownItem] {
        guard let byTrigger = dash.weeklyTrend?.byTrigger else { return [] }
        let total = byTrigger.values.reduce(0, +)
        return byTrigger
            .map { TriggerBreakdownItem(trigger: $0.key, count: $0.value, pct: total > 0 ? Int(Double($0.value) / Double(total) * 100) : 0) }
            .sorted { $0.count > $1.count }
    }

    // ────────────────────────────────────────────
    // MARK: - Formatters
    // ────────────────────────────────────────────

    private func timeAgo(_ iso: String) -> String {
        guard let date = isoDate(iso) else { return "" }
        let diff = Date().timeIntervalSince(date)
        let mins = Int(diff / 60)
        if mins < 1 { return "just now" }
        if mins < 60 { return "\(mins)m ago" }
        let hrs = mins / 60
        if hrs < 24 { return "\(hrs)h ago" }
        return "\(hrs / 24)d ago"
    }

    private func formatTime(_ iso: String) -> String {
        guard let date = isoDate(iso) else { return "" }
        let f = DateFormatter()
        f.dateStyle = .none
        f.timeStyle = .short
        return f.string(from: date)
    }

    private func formatDate(_ iso: String) -> String {
        guard let date = isoDate(iso) else { return "" }
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f.string(from: date)
    }

    private func isoDate(_ iso: String) -> Date? {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f.date(from: iso) ?? ISO8601DateFormatter().date(from: iso)
    }

    private func milestoneTimeLabel(_ mins: Int) -> String {
        if mins < 60 { return "\(mins)min" }
        if mins < 1440 { return "\(mins / 60)h" }
        if mins < 10080 { return "\(mins / 1440)d" }
        if mins < 43200 { return "\(mins / 10080)w" }
        if mins < 525600 { return "\(mins / 43200)mo" }
        return "\(mins / 525600)yr"
    }

    // ────────────────────────────────────────────
    // MARK: - Options
    // ────────────────────────────────────────────

    private let triggerOptions: [(value: String, label: String)] = [
        ("stress", "Stress"), ("social", "Social"), ("boredom", "Boredom"),
        ("habit", "Habit"), ("anxiety", "Anxiety"), ("after_meal", "After Meal"),
        ("morning", "Morning"), ("other", "Other")
    ]

    private let copingOptions: [(value: String, label: String)] = [
        ("deep_breathing", "Deep Breathing"), ("distraction", "Distraction"),
        ("water", "Drink Water"), ("exercise", "Exercise"), ("call_friend", "Call a Friend"),
        ("chew_gum", "Chew Gum"), ("meditation", "Meditation"), ("other", "Other")
    ]

    private func triggerLabel(_ value: String) -> String {
        triggerOptions.first { $0.value == value }?.label ?? value.capitalized
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        QuitVapeView()
            .environment(\.injected, .previewAuthenticated)
    }
}
