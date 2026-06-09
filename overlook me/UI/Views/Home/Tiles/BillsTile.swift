import SwiftUI

// MARK: - Tile

struct BillsTile: View {
    @Environment(\.injected) private var container: DIContainer
    @StateObject private var service = HomeBillsService()

    private var userId: String {
        container.appState.state.auth.user?.id ?? ""
    }

    var body: some View {
        Group {
            if service.state.isLoading {
                loadingCard
            } else if service.state.failed {
                errorCard
            } else {
                billsCard
            }
        }
        .task {
            guard !userId.isEmpty else { return }
            await service.load(userId: userId)
        }
    }

    // MARK: - Loading

    private var loadingCard: some View {
        HStack(spacing: 8) {
            ProgressView().tint(Kalshi.textMuted).scaleEffect(0.85)
            Text("BILLS")
                .kalshiEyebrow()
        }
        .frame(maxWidth: .infinity)
        .frame(height: 160)
        .kalshiCard()
    }

    // MARK: - Error

    private var errorCard: some View {
        VStack(spacing: Kalshi.cardGap) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 18))
                .foregroundStyle(Kalshi.textMuted)
            Text("Couldn't load bills")
                .kalshiSecondary()
            Button("Retry") {
                _Concurrency.Task { await service.refresh(userId: userId) }
            }
            .buttonStyle(KalshiPillButtonStyle(isPrimary: false))
        }
        .frame(maxWidth: .infinity)
        .frame(height: 160)
        .kalshiCard()
    }

    // MARK: - Main Card

    private var billsCard: some View {
        VStack(spacing: 0) {
            headerSection
            KalshiDivider().padding(.horizontal, Kalshi.cardPadH)
            barChartSection
            KalshiDivider().padding(.horizontal, Kalshi.cardPadH)
            insightBar
        }
        .kalshiCard()
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: Kalshi.cardGap) {
            HStack(alignment: .center) {
                HStack(spacing: 4) {
                    Image(systemName: "creditcard.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(Kalshi.textMuted)
                    Text("BILLS & SUBSCRIPTIONS")
                        .kalshiEyebrow()
                }

                Spacer()

                statusPill
            }

            // Hero amount — Kalshi metric (23px bold)
            Text(formatCurrency(service.state.totalUpcoming))
                .kalshiMetric()
                .minimumScaleFactor(0.7)
                .lineLimit(1)

            Text("DUE IN THE NEXT 4 WEEKS")
                .kalshiMetricLabel()
        }
        .padding(.horizontal, Kalshi.cardPadH)
        .padding(.top, Kalshi.cardPadTop)
        .padding(.bottom, Kalshi.cardPadBot)
    }

    private var statusPill: some View {
        Group {
            if service.state.overdueBills.count > 0 {
                KalshiStatusBadge(text: "\(service.state.overdueBills.count) OVERDUE", variant: .fail)
            } else if service.state.dueSoonCount > 0 {
                KalshiStatusBadge(text: "\(service.state.dueSoonCount) DUE SOON", variant: .pending)
            } else {
                KalshiStatusBadge(text: "ALL CLEAR", variant: .done)
            }
        }
    }

    // MARK: - Bar Chart

    private var barChartSection: some View {
        HStack(alignment: .bottom, spacing: Kalshi.cardGap) {
            ForEach(service.state.weekBuckets) { bucket in
                BillsWeekBar(
                    bucket: bucket,
                    maxTotal: service.state.maxWeekTotal,
                    accent: semanticAccent
                )
            }
        }
        .padding(.horizontal, Kalshi.cardPadH)
        .padding(.vertical, Kalshi.cardPadTop)
    }

    // MARK: - Insight Bar

    private var insightBar: some View {
        Text(service.state.summaryHeadline)
            .kalshiSecondary()
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Kalshi.cardPadH)
            .padding(.vertical, 10)
    }

    // MARK: - Accent — Semantic only

    private var semanticAccent: Color {
        if !service.state.overdueBills.isEmpty { return Kalshi.red }
        if service.state.dueSoonCount > 0 { return Kalshi.amber }
        return Kalshi.green
    }

    private func formatCurrency(_ value: Double) -> String {
        let fmt = NumberFormatter()
        fmt.numberStyle = .currency
        fmt.currencyCode = "USD"
        fmt.maximumFractionDigits = 0
        return fmt.string(from: NSNumber(value: value)) ?? "$0"
    }
}

// MARK: - Week Bar (Kalshi flat, no gradient)

private struct BillsWeekBar: View {
    let bucket: WeekBucket
    let maxTotal: Double
    let accent: Color

    private static let barHeight: CGFloat = 52
    private static let labelHeight: CGFloat = 14
    private static let amountHeight: CGFloat = 14

    private var fraction: CGFloat {
        guard maxTotal > 0, bucket.total > 0 else { return 0 }
        return CGFloat(bucket.total / maxTotal)
    }

    var body: some View {
        VStack(spacing: 3) {
            // Amount above bar
            Text(bucket.count > 0 ? formatCurrency(bucket.total) : "")
                .font(.system(size: 9, weight: .semibold))
                .tracking(-0.09)
                .foregroundStyle(Kalshi.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(height: Self.amountHeight)

            // Bar — flat fill, no gradient
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                RoundedRectangle(cornerRadius: Kalshi.segRadius, style: .continuous)
                    .fill(bucket.count > 0 ? accent : Kalshi.dividerBg)
                    .frame(height: max(4, Self.barHeight * (bucket.count > 0 ? fraction : 0.05)))
                    .animation(Kalshi.normal, value: fraction)
            }
            .frame(height: Self.barHeight)

            // Week label
            Text(shortLabel(bucket.label))
                .font(.system(size: 9, weight: .medium))
                .tracking(0.4)
                .textCase(.uppercase)
                .foregroundStyle(Kalshi.textMuted)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(height: Self.labelHeight)
        }
        .frame(maxWidth: .infinity)
    }

    private func shortLabel(_ label: String) -> String {
        switch label {
        case "This week":  return "This wk"
        case "Next week":  return "Next wk"
        case "In 2 weeks": return "2 wks"
        case "In 3 weeks": return "3 wks"
        default:           return label
        }
    }

    private func formatCurrency(_ value: Double) -> String {
        let fmt = NumberFormatter()
        fmt.numberStyle = .currency
        fmt.currencyCode = "USD"
        fmt.maximumFractionDigits = 0
        return fmt.string(from: NSNumber(value: value)) ?? "$0"
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Kalshi.bg.ignoresSafeArea()
        BillsTile()
            .padding(.horizontal, 16)
            .environment(\.injected, .previewAuthenticated)
    }
}
