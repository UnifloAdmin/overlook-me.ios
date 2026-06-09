import SwiftUI

struct QuitVapeTile: View {
    @Environment(\.injected) private var container: DIContainer
    @StateObject private var service = HomeQuitVapeService()
    @State private var quickPuffs = 0
    @State private var submitting = false
    @State private var showSuccess = false

    private var userId: String {
        container.appState.state.auth.user?.oauthId ?? ""
    }

    var body: some View {
        Group {
            if service.state.isLoading {
                kalshiShimmer("Quit Vape")
            } else if service.state.failed {
                kalshiErrorState("Quit Vape") {
                    _Concurrency.Task { await service.refresh(userId: userId) }
                }
            } else if !service.state.hasProfile {
                emptyCard
            } else {
                card
            }
        }
        .task {
            guard !userId.isEmpty else { return }
            await service.load(userId: userId)
        }
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - Empty / No Profile
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private var emptyCard: some View {
        HStack(spacing: 10) {
            Image(systemName: "lungs.fill")
                .font(.system(size: 16))
                .foregroundStyle(Kalshi.textMuted)
            VStack(alignment: .leading, spacing: 2) {
                Text("Quit Vape")
                    .kalshiCardTitle()
                Text("Track cravings and watch your health recover")
                    .kalshiSecondary()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Kalshi.cardPadH)
        .kalshiCard()
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - Main Card
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private var card: some View {
        VStack(spacing: 0) {
            // ── Header ──
            headerRow
                .padding(.horizontal, Kalshi.cardPadH)
                .padding(.top, Kalshi.cardPadTop)
                .padding(.bottom, 6)

            // ── Hero number: Days Quit ──
            heroSection
                .padding(.horizontal, Kalshi.cardPadH)
                .padding(.bottom, 10)

            KalshiDivider().padding(.horizontal, Kalshi.cardPadH)

            // ── Quick Log ──
            quickLogSection
                .padding(.horizontal, Kalshi.cardPadH)
                .padding(.vertical, 12)

            KalshiDivider().padding(.horizontal, Kalshi.cardPadH)

            // ── Mini Bar Chart — last 7 days ──
            miniChartSection
                .padding(.horizontal, Kalshi.cardPadH)
                .padding(.vertical, 12)

            KalshiDivider().padding(.horizontal, Kalshi.cardPadH)

            // ── Stats Row ──
            metricsRow
                .padding(.horizontal, Kalshi.cardPadH)
                .padding(.vertical, 10)

            KalshiDivider().padding(.horizontal, Kalshi.cardPadH)

            // ── Insight ──
            insightFooter
                .padding(.horizontal, Kalshi.cardPadH)
                .padding(.vertical, 10)
        }
        .kalshiCard()
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - Header
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private var headerRow: some View {
        HStack(spacing: 4) {
            Image(systemName: "lungs.fill")
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .foregroundStyle(Kalshi.textMuted)
            Text("QUIT VAPE")
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.6)
                .foregroundStyle(Kalshi.textMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - Hero Section (like Kalshi's price)
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private var heroSection: some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            // Big number: Today's puffs
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text("\(service.state.puffsToday)")
                    .font(.system(size: 32, weight: .bold))
                    .tracking(-1.28)
                    .foregroundStyle(service.state.puffsToday == 0 ? Kalshi.green : Kalshi.red)
                    .contentTransition(.numericText(value: Double(service.state.puffsToday)))

                Text("PUFFS TODAY")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(0.6)
                    .foregroundStyle(Kalshi.textMuted)
            }

            Spacer()

            // Right: Resist rate
            VStack(alignment: .trailing, spacing: 0) {
                Text("\(service.state.resistRate)%")
                    .font(.system(size: 14, weight: .bold))
                    .tracking(-0.28)
                    .foregroundStyle(service.state.resistRate >= 50 ? Kalshi.green : Kalshi.red)
                Text("RESISTED")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(0.6)
                    .foregroundStyle(Kalshi.textMuted)
            }
        }
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - Quick Log
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private var quickLogSection: some View {
        VStack(spacing: 10) {
            // Success banner
            if showSuccess {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 10))
                    Text("LOGGED")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(0.6)
                }
                .foregroundStyle(Kalshi.green)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Kalshi.greenBg, in: Capsule())
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            HStack(spacing: 12) {
                // Puff counter
                HStack(spacing: 8) {
                    Button {
                        if quickPuffs > 0 { quickPuffs -= 1 }
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        Image(systemName: "minus")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Kalshi.red)
                            .frame(width: 28, height: 28)
                            .background(Kalshi.redBg, in: Circle())
                    }
                    .buttonStyle(.plain)

                    Text("\(quickPuffs)")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .tracking(-0.44)
                        .foregroundStyle(quickPuffs > 0 ? Kalshi.red : Kalshi.textPrimary)
                        .contentTransition(.numericText())
                        .animation(.spring(duration: 0.25), value: quickPuffs)
                        .frame(width: 32)

                    Button {
                        quickPuffs += 1
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Kalshi.red)
                            .frame(width: 28, height: 28)
                            .background(Kalshi.redBg, in: Circle())
                    }
                    .buttonStyle(.plain)
                }

                // Log puffs button
                Button {
                    _Concurrency.Task { await logPuffs() }
                } label: {
                    Text(submitting ? "…" : "Log")
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(-0.11)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(Kalshi.red, in: Capsule())
                }
                .disabled(submitting || quickPuffs == 0)
                .opacity(quickPuffs == 0 ? 0.45 : 1)
                .buttonStyle(.plain)

                Spacer(minLength: 0)

                // Resisted button
                Button {
                    _Concurrency.Task { await logResisted() }
                } label: {
                    Text("I Resisted")
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(-0.11)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(Kalshi.green, in: Capsule())
                }
                .disabled(submitting)
                .buttonStyle(.plain)
            }
        }
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - Mini Bar Chart (7-day puffs)
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private var miniChartSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("PUFFS — 7 DAYS")
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.6)
                .foregroundStyle(Kalshi.textMuted)

            let data = service.state.last7DaysPuffs
            let maxVal = max(data.map(\.puffs).max() ?? 1, 1)

            HStack(alignment: .bottom, spacing: 4) {
                ForEach(Array(data.enumerated()), id: \.offset) { _, day in
                    VStack(spacing: 4) {
                        if day.puffs > 0 {
                            Text("\(day.puffs)")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(Kalshi.textMuted)
                        }

                        RoundedRectangle(cornerRadius: Kalshi.segRadius, style: .continuous)
                            .fill(day.puffs == 0 ? Kalshi.greenBg : Kalshi.red.opacity(0.65))
                            .frame(height: barHeight(day.puffs, max: maxVal))

                        Text(String(day.label.prefix(2)))
                            .font(.system(size: 8, weight: .semibold))
                            .tracking(0.4)
                            .foregroundStyle(Kalshi.textMuted)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 72)
        }
    }

    private func barHeight(_ puffs: Int, max maxVal: Int) -> CGFloat {
        let ratio = CGFloat(puffs) / CGFloat(maxVal)
        return Swift.max(3, ratio * 48)
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - Metrics Row
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private var metricsRow: some View {
        HStack(spacing: 0) {
            metricCell("RESISTED", "\(service.state.resistedCount)", Kalshi.green)
            metricDivider
            metricCell("RATE", "\(service.state.resistRate)%", Kalshi.blue)
            metricDivider
            metricCell("TODAY", "\(service.state.puffsToday)p", service.state.puffsToday == 0 ? Kalshi.green : Kalshi.red)
            metricDivider
            metricCell("BEST", "\(service.state.longestStreak)d", Kalshi.amber)
        }
    }

    private func metricCell(_ label: String, _ value: String, _ color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 14, weight: .bold))
                .tracking(-0.28)
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.6)
                .foregroundStyle(Kalshi.textMuted)
        }
        .frame(maxWidth: .infinity)
    }

    private var metricDivider: some View {
        Rectangle()
            .fill(Kalshi.cardBorder)
            .frame(width: 1, height: 26)
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - Insight Footer
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private var insightFooter: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(insightDotColor)
                .frame(width: 4, height: 4)
            Text(service.state.headline)
                .font(.system(size: 12, weight: .medium))
                .tracking(-0.12)
                .foregroundStyle(Kalshi.textSecondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - Actions
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private func logPuffs() async {
        guard quickPuffs > 0 else { return }
        submitting = true
        let success = await service.quickLogPuffs(count: quickPuffs, userId: userId)
        if success {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            quickPuffs = 0
            withAnimation { showSuccess = true }
            try? await _Concurrency.Task.sleep(nanoseconds: 2_500_000_000)
            withAnimation { showSuccess = false }
        }
        submitting = false
    }

    private func logResisted() async {
        submitting = true
        let success = await service.quickLogResisted(userId: userId)
        if success {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            withAnimation { showSuccess = true }
            try? await _Concurrency.Task.sleep(nanoseconds: 2_500_000_000)
            withAnimation { showSuccess = false }
        }
        submitting = false
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - Colors
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━




    private var insightDotColor: Color {
        let rate = service.state.resistRate
        if rate >= 80 { return Kalshi.green }
        if rate >= 50 { return Kalshi.amber }
        if service.state.puffsToday == 0 { return Kalshi.green }
        return Kalshi.red
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Kalshi.bg.ignoresSafeArea()
        QuitVapeTile()
            .padding(.horizontal, 16)
            .environment(\.injected, .previewAuthenticated)
    }
}
