import SwiftUI

// MARK: - Transactions Merchants View

struct TransactionsMerchantsView: View {
    @SwiftUI.Environment(\.injected) private var container: DIContainer
    @Bindable var viewModel: TransactionsViewModel
    @State private var searchText = ""

    private var userId: String {
        container.appState.state.auth.user?.id ?? ""
    }

    private var filteredMerchants: [MerchantSummary] {
        guard !searchText.isEmpty else { return viewModel.merchantSummaries }
        return viewModel.merchantSummaries.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.categories.contains { $0.localizedCaseInsensitiveContains(searchText) }
        }
    }

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.merchantSummaries.isEmpty {
                VStack(spacing: 8) {
                    ProgressView()
                    KLabel("Analyzing merchants")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.merchantSummaries.isEmpty {
                KEmptyState(
                    icon: "storefront",
                    title: "No Merchants",
                    message: "No merchant data available for this period."
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                merchantsList
            }
        }
        .background(Color.kSurface)
        .searchable(text: $searchText, prompt: "Search merchants...")
    }

    // MARK: - List

    private var merchantsList: some View {
        LazyVStack(spacing: 8) {
            summarySection
            sortBar
            merchantsSection
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 100)
    }

    // MARK: - Summary Strip

    private var summarySection: some View {
        KStatRow(items: [
            (label: "Merchants", value: "\(viewModel.merchantSummaries.count)", color: Color.kPrimary),
            (label: "Recurring", value: "\(viewModel.merchantRecurringCount)", color: Color.kPrimary),
            (label: "Avg / Merchant", value: compactCurrency(viewModel.merchantAvgPerMerchant), color: Color.kPrimary)
        ])
    }

    // MARK: - Sort Bar

    private var sortBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 5) {
                ForEach(MerchantSortField.allCases, id: \.self) { field in
                    Button {
                        viewModel.toggleMerchantSort(field)
                    } label: {
                        HStack(spacing: 3) {
                            Text(field.label.uppercased())
                                .font(.system(size: 10, weight: .semibold))
                                .tracking(0.4)

                            if viewModel.merchantSortField == field {
                                Image(systemName: viewModel.merchantSortAscending ? "chevron.up" : "chevron.down")
                                    .font(.system(size: 7, weight: .bold))
                            }
                        }
                        .padding(.horizontal, 11)
                        .padding(.vertical, 5)
                        .foregroundStyle(viewModel.merchantSortField == field ? .white : Color.kTertiary)
                        .background(
                            viewModel.merchantSortField == field ? Color.kPrimary : Color.kSurface,
                            in: Capsule()
                        )
                        .overlay(
                            viewModel.merchantSortField == field
                                ? nil
                                : Capsule().stroke(Color.kBorderMedium, lineWidth: 1)
                        )
                    }
                    .buttonStyle(KPressButtonStyle())
                }
            }
        }
        .scrollClipDisabled()
    }

    // MARK: - Merchants List

    private var merchantsSection: some View {
        VStack(spacing: 6) {
            ForEach(filteredMerchants) { merchant in
                VStack(spacing: 0) {
                    merchantRow(merchant: merchant)

                    if viewModel.expandedMerchantName == merchant.name {
                        merchantDetailView(merchant: merchant)
                    }
                }
            }
        }
    }

    private func merchantRow(merchant: MerchantSummary) -> some View {
        Button {
            let uid = userId
            let vm = viewModel
            let name = merchant.name
            _Concurrency.Task { await vm.toggleMerchantExpand(name, userId: uid) }
        } label: {
            HStack(spacing: 12) {
                // Avatar initial
                Text(String(merchant.name.prefix(1)).uppercased())
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.kSecondary)
                    .frame(width: 38, height: 38)
                    .background(Color.kDividerBg, in: Circle())

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(merchant.name)
                            .font(.system(size: 13, weight: .semibold))
                            .tracking(-0.2)
                            .foregroundStyle(Color.kPrimary)
                            .lineLimit(1)

                        if merchant.isRecurring {
                            KStatusBadge(text: "Recurring", style: .pending)
                        }
                    }

                    HStack(spacing: 4) {
                        Text("\(merchant.transactionCount) txns")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Color.kTertiary)

                        Text("·").foregroundStyle(Color.kPlaceholder)

                        Text(String(format: "%.1f%%", merchant.sharePercent))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Color.kTertiary)
                    }
                }

                Spacer()

                Text(formatCurrency(merchant.totalVolume))
                    .font(.system(size: 14, weight: .bold))
                    .tracking(-0.3)
                    .foregroundStyle(Color.kPrimary)
            }
            .padding(12)
            .background(Color.kSurface)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.kBorder, lineWidth: 1))
        }
        .buttonStyle(KPressButtonStyle())
    }

    // MARK: - Merchant Detail

    @ViewBuilder
    private func merchantDetailView(merchant: MerchantSummary) -> some View {
        if viewModel.merchantDetailLoading.contains(merchant.name) {
            ProgressView()
                .scaleEffect(0.7)
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity)
        } else if let detail = viewModel.merchantDetails[merchant.name] {
            VStack(alignment: .leading, spacing: 10) {
                KStatRow(items: [
                    (label: "Spent", value: formatCurrency(detail.totalSpent), color: Color.kPrimary),
                    (label: "Earned", value: formatCurrency(detail.totalEarned), color: Color.kPrimary),
                    (label: "Net", value: formatCurrency(detail.netAmount), color: Color.kPrimary),
                    (label: "Avg", value: formatCurrency(merchant.averageTransaction), color: Color.kPrimary)
                ])

                if !merchant.categories.isEmpty {
                    VStack(alignment: .leading, spacing: 5) {
                        KLabel("Categories")
                        HStack(spacing: 4) {
                            ForEach(Array(merchant.categories.sorted().prefix(4)), id: \.self) { cat in
                                Text(cat)
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(Color.kSecondary)
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 3)
                                    .background(Color.kDividerBg, in: Capsule())
                            }
                        }
                    }
                }
            }
            .padding(12)
            .background(Color.kHoverSurface)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.kBorder, lineWidth: 1))
        }
    }

    // MARK: - Helpers

    private func formatCurrency(_ value: Double) -> String {
        abs(value).formatted(.currency(code: "USD").precision(.fractionLength(0)))
    }

    private func compactCurrency(_ value: Double) -> String {
        value >= 1000 ? "$\(Int(value / 1000))k" : "$\(Int(value))"
    }
}

#Preview {
    NavigationStack {
        TransactionsMerchantsView(viewModel: TransactionsViewModel())
    }
    .environment(\.injected, .previewAuthenticated)
}
