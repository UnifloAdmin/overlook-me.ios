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
            ProgressView().tint(.secondary).scaleEffect(0.85)
            Text("Bills")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 160)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    // MARK: - Error

    private var errorCard: some View {
        VStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("Couldn't load bills")
                .font(.caption)
                .foregroundStyle(.secondary)
            Button("Retry") {
                _Concurrency.Task { await service.refresh(userId: userId) }
            }
            .font(.caption.bold())
        }
        .frame(maxWidth: .infinity)
        .frame(height: 160)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    // MARK: - Main Card

    private var billsCard: some View {
        VStack(spacing: 0) {
            headerSection
            Divider().padding(.horizontal, 16)
            barChartSection
            Divider().padding(.horizontal, 16)
            insightBar
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center) {
                Label {
                    Text("Bills & Subscriptions")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                } icon: {
                    Image(systemName: "creditcard.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(accentColor)
                }

                Spacer()

                statusPill
            }

            Text(formatCurrency(service.state.totalUpcoming))
                .font(.system(size: 34, weight: .thin, design: .rounded))
                .foregroundStyle(.primary)
                .minimumScaleFactor(0.7)
                .lineLimit(1)

            Text("due in the next 4 weeks")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private var statusPill: some View {
        Group {
            if service.state.overdueBills.count > 0 {
                pill("\(service.state.overdueBills.count) overdue", systemImage: "exclamationmark.circle.fill", color: .red)
            } else if service.state.dueSoonCount > 0 {
                pill("\(service.state.dueSoonCount) due soon", systemImage: "clock.fill", color: .orange)
            } else {
                pill("All clear", systemImage: "checkmark.circle.fill", color: .green)
            }
        }
    }

    private func pill(_ text: String, systemImage: String, color: Color) -> some View {
        Label(text, systemImage: systemImage)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(color.opacity(0.12), in: Capsule())
    }

    // MARK: - Bar Chart

    private var barChartSection: some View {
        HStack(alignment: .bottom, spacing: 10) {
            ForEach(service.state.weekBuckets) { bucket in
                BillsWeekBar(
                    bucket: bucket,
                    maxTotal: service.state.maxWeekTotal,
                    accent: accentColor
                )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    // MARK: - Insight Bar

    private var insightBar: some View {
        Text(service.state.summaryHeadline)
            .font(.footnote)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
    }

    // MARK: - Accent

    private var accentColor: Color {
        if !service.state.overdueBills.isEmpty { return .red }
        if service.state.dueSoonCount > 0 { return .orange }
        return .blue
    }

    private func formatCurrency(_ value: Double) -> String {
        let fmt = NumberFormatter()
        fmt.numberStyle = .currency
        fmt.currencyCode = "USD"
        fmt.maximumFractionDigits = 0
        return fmt.string(from: NSNumber(value: value)) ?? "$0"
    }
}

// MARK: - Week Bar

private struct BillsWeekBar: View {
    let bucket: WeekBucket
    let maxTotal: Double
    let accent: Color

    private static let barHeight: CGFloat = 56
    private static let labelHeight: CGFloat = 14
    private static let amountHeight: CGFloat = 14

    private var fraction: CGFloat {
        guard maxTotal > 0, bucket.total > 0 else { return 0 }
        return CGFloat(bucket.total / maxTotal)
    }

    var body: some View {
        VStack(spacing: 3) {
            // Amount above bar — fixed height so bars align from the bottom
            Text(bucket.count > 0 ? formatCurrency(bucket.total) : "")
                .font(.system(size: 9, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary.opacity(0.7))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(height: Self.amountHeight)

            // Bar — grows from bottom, pinned via VStack + Spacer
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(
                        bucket.count > 0
                            ? AnyShapeStyle(LinearGradient(
                                colors: [accent, accent.opacity(0.55)],
                                startPoint: .top,
                                endPoint: .bottom
                              ))
                            : AnyShapeStyle(Color(.systemFill))
                    )
                    .frame(height: max(4, Self.barHeight * (bucket.count > 0 ? fraction : 0.05)))
            }
            .frame(height: Self.barHeight)

            // Week label below bar — fixed height
            Text(shortLabel(bucket.label))
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.secondary)
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
        Color(.systemGroupedBackground).ignoresSafeArea()
        BillsTile()
            .padding(.horizontal, 20)
            .environment(\.injected, .previewAuthenticated)
    }
}
