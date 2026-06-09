import SwiftUI

// MARK: - Feature Model

private struct EarlyAccessFeature: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let description: String
    let status: FeatureStatus
    let eta: String?

    enum FeatureStatus: String {
        case beta = "Beta"
        case comingSoon = "Coming Soon"
        case live = "Live"

        var color: Color {
            switch self {
            case .beta:     Color(red: 0.88, green: 0.42, blue: 0.10)
            case .comingSoon: Kalshi.textMuted
            case .live:     Color.green
            }
        }
    }
}

// MARK: - Early Access Sheet

struct EarlyAccessSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var joinedFeatures: Set<String> = []
    @State private var appeared = false

    private let features: [EarlyAccessFeature] = [
        .init(icon: "sparkles", title: "AI Insights",
              description: "Automated financial pattern detection powered by machine learning. Personalized spending insights, anomaly alerts, and predictive cash-flow forecasts.",
              status: .beta, eta: "Public launch Q2 2026"),
        .init(icon: "bell.badge.fill", title: "Smart Alerts",
              description: "Intelligent, context-aware notifications. Budget warnings, bill reminders, unusual activity flags — delivered at the right time.",
              status: .comingSoon, eta: "Expected May 2026"),
        .init(icon: "arrow.triangle.2.circlepath", title: "Portfolio Sync",
              description: "Connect brokerage and retirement accounts for a unified net-worth view. Real-time holdings and diversification analysis.",
              status: .comingSoon, eta: "Expected June 2026"),
        .init(icon: "doc.text.viewfinder", title: "Receipt Scanner",
              description: "Snap a photo of any receipt and auto-categorize the expense. OCR-powered extraction of merchant, amount, and line items.",
              status: .comingSoon, eta: "Expected July 2026"),
        .init(icon: "person.2.fill", title: "Shared Budgets",
              description: "Collaborative budgets for couples, families, or roommates. Shared visibility and split tracking in one place.",
              status: .comingSoon, eta: "Expected Q3 2026"),
        .init(icon: "chart.line.uptrend.xyaxis", title: "Goal Planner",
              description: "Set savings goals with target dates and auto-calculated contributions. Visual runway charts show exactly where you stand.",
              status: .comingSoon, eta: "Expected Q3 2026")
    ]

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Kalshi.bg.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    heroSection
                    featureGrid
                    ctaSection
                }
            }

            // Big X close button
            closeButton
        }
    }

    // MARK: - Close Button

    private var closeButton: some View {
        Button { dismiss() } label: {
            Image(systemName: "xmark")
                .font(.system(size: 17, weight: .bold))
        }
        .buttonBorderShape(.circle)
        .glassEffect(.regular.interactive())
        .padding(.top, 18)
        .padding(.trailing, 20)
    }

    // MARK: - Hero Section

    private var heroSection: some View {
        VStack(spacing: 16) {
            Spacer().frame(height: 50)

            // Badge
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 12, weight: .semibold))
                Text("Early Access Program")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(Color(red: 0.88, green: 0.42, blue: 0.10))
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(
                Capsule()
                    .fill(Color(red: 0.88, green: 0.42, blue: 0.10).opacity(0.12))
            )

            // Title
            VStack(spacing: 6) {
                Text("Shape the future of")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(Kalshi.textPrimary)
                Text("Uniflo")
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color(red: 0.88, green: 0.42, blue: 0.10))
            }

            // Subtitle
            Text("Get first access to upcoming features before anyone else. Join the waitlist, try beta releases, and help us build the tools you actually want.")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Kalshi.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            // Stats row
            HStack(spacing: 0) {
                statItem(value: "6", label: "Features")
                statDivider
                statItem(value: "1", label: "In Beta")
                statDivider
                statItem(value: "5", label: "Coming Soon")
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 20)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(.systemGray6))
            )
            .padding(.horizontal, 24)
            .padding(.top, 8)

            Spacer().frame(height: 8)
        }
    }

    private func statItem(value: String, label: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(Kalshi.textPrimary)
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Kalshi.textMuted)
        }
        .frame(maxWidth: .infinity)
    }

    private var statDivider: some View {
        Rectangle()
            .fill(Color(.separator))
            .frame(width: 1, height: 32)
    }

    // MARK: - Feature Grid

    private var featureGrid: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("UPCOMING FEATURES")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .tracking(0.8)
                .foregroundStyle(Kalshi.textMuted)
                .padding(.horizontal, 20)
                .padding(.top, 8)

            LazyVStack(spacing: 12) {
                ForEach(features) { feature in
                    featureCard(feature)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func featureCard(_ feature: EarlyAccessFeature) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Top row: icon + status
            HStack {
                Image(systemName: feature.icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Color(red: 0.88, green: 0.42, blue: 0.10))
                    .frame(width: 40, height: 40)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color(red: 0.88, green: 0.42, blue: 0.10).opacity(0.1))
                    )

                Spacer()

                Text(feature.status.rawValue)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .tracking(0.3)
                    .foregroundStyle(feature.status.color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(feature.status.color.opacity(0.1))
                    )
            }

            // Title
            Text(feature.title)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(Kalshi.textPrimary)

            // Description
            Text(feature.description)
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(Kalshi.textSecondary)
                .lineSpacing(3)

            // ETA
            if let eta = feature.eta {
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.system(size: 11))
                    Text(eta)
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundStyle(Kalshi.textMuted)
            }

            // Join button
            Button {
                withAnimation(.spring(response: 0.3)) {
                    if joinedFeatures.contains(feature.title) {
                        joinedFeatures.remove(feature.title)
                    } else {
                        joinedFeatures.insert(feature.title)
                    }
                }
            } label: {
                let isJoined = joinedFeatures.contains(feature.title)
                HStack(spacing: 6) {
                    Image(systemName: isJoined ? "checkmark.circle.fill" : "plus.circle")
                        .font(.system(size: 14, weight: .semibold))
                    Text(isJoined ? "Joined" : "Join Waitlist")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                }
                .foregroundStyle(isJoined ? .white : Color(red: 0.88, green: 0.42, blue: 0.10))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(isJoined ? Color(red: 0.88, green: 0.42, blue: 0.10) : Color(red: 0.88, green: 0.42, blue: 0.10).opacity(0.1))
                )
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Kalshi.bg)
                .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
        )
    }

    // MARK: - CTA Section

    private var ctaSection: some View {
        HStack(spacing: 14) {
            Image(systemName: "megaphone.fill")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(Color(red: 0.88, green: 0.42, blue: 0.10))

            VStack(alignment: .leading, spacing: 3) {
                Text("Have a feature idea?")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(Kalshi.textPrimary)
                Text("We build what you need. Drop a suggestion and it might land in the next release.")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(Kalshi.textSecondary)
                    .lineSpacing(2)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Kalshi.bg)
                .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
        )
        .padding(.horizontal, 16)
        .padding(.vertical, 24)
        .padding(.bottom, 40)
    }
}

#Preview {
    EarlyAccessSheet()
}
