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
        if searchText.isEmpty {
            return viewModel.merchantSummaries
        }
        return viewModel.merchantSummaries.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.categories.contains(where: { $0.localizedCaseInsensitiveContains(searchText) })
        }
    }
    
    private var topMerchants: [MerchantSummary] {
        Array(filteredMerchants.prefix(5))
    }
    
    private var maxTopVolume: Double {
        topMerchants.first?.totalVolume ?? 1
    }
    
    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.merchantSummaries.isEmpty {
                VStack(spacing: 8) {
                    ProgressView()
                    KLabel("Analyzing merchants")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.kSurface)
            } else if viewModel.merchantSummaries.isEmpty {
                KEmptyState(
                    icon: "storefront",
                    title: "No Merchants",
                    message: "No merchant data available."
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.kSurface)
            } else {
                merchantsList
            }
        }
        .background(Color.kSurface)
        .searchable(text: $searchText, prompt: "Search merchants or categories...")
    }
    
    private var merchantsList: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                // Period picker + summary scroll with content — never sticky
                TransactionsPeriodPicker(viewModel: viewModel)
                TransactionsSummaryStrip(viewModel: viewModel)
                
                summarySection
                topMerchantsSection
                sortBar
                allMerchantsSection
                merchantFooter
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
        }
        .refreshable {
            await viewModel.loadMerchants(userId: userId)
        }
    }
    
    // MARK: - Summary Section
    
    private var summarySection: some View {
        KStatRow(items: [
            (label: "Total Volume", value: formatCurrency(viewModel.merchantTotalVolume), color: Color.kPrimary),
            (label: "Merchants", value: "\(viewModel.merchantSummaries.count)", color: Color.kPrimary),
            (label: "Recurring", value: "\(viewModel.merchantRecurringCount)", color: Color.kPrimary),
            (label: "Avg / Merchant", value: formatCurrency(viewModel.merchantAvgPerMerchant), color: Color.kPrimary)
        ])
    }
    
    // MARK: - Top Merchants Ranking
    
    private var topMerchantsSection: some View {
        KCard(title: "Top Merchants", eyebrow: "BY VOLUME") {
            VStack(spacing: 0) {
                ForEach(Array(topMerchants.enumerated()), id: \.element.id) { index, merchant in
                    HStack(spacing: 8) {
                        // Rank with medal for top 3
                        rankBadge(index: index)
                        
                        Text(merchant.name)
                            .font(.system(size: 12, weight: .semibold))
                            .tracking(-0.1)
                            .foregroundStyle(Color.kPrimary)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        KProgressBar(
                            ratio: maxTopVolume > 0 ? merchant.totalVolume / maxTopVolume : 0,
                            color: Color.kPrimary.opacity(0.5),
                            height: 4
                        )
                        .frame(width: 50)
                        
                        VStack(alignment: .trailing, spacing: 1) {
                            Text(formatCurrency(merchant.totalVolume))
                                .font(.system(size: 12, weight: .bold))
                                .tracking(-0.1)
                                .foregroundStyle(Color.kPrimary)
                            Text(String(format: "%.1f%%", merchant.sharePercent))
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(Color.kTertiary)
                        }
                        .frame(width: 60, alignment: .trailing)
                    }
                    .padding(.vertical, 6)
                    
                    if index < topMerchants.count - 1 {
                        Rectangle().fill(Color.kBorder).frame(height: 1)
                    }
                }
            }
        }
    }
    
    private func rankBadge(index: Int) -> some View {
        let colors: [Color] = [
            Color(red: 0.965, green: 0.831, blue: 0.353), // Gold
            Color(red: 0.753, green: 0.753, blue: 0.800), // Silver
            Color(red: 0.804, green: 0.502, blue: 0.306)  // Bronze
        ]
        
        return Text("\(index + 1)")
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(index < 3 ? .white : Color.kTertiary)
            .frame(width: 20, height: 20)
            .background(index < 3 ? colors[index] : Color.kDividerBg, in: Circle())
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
                                .tracking(0.6)
                            
                            if viewModel.merchantSortField == field {
                                Image(systemName: viewModel.merchantSortAscending ? "chevron.up" : "chevron.down")
                                    .font(.system(size: 7, weight: .bold))
                            }
                        }
                        .padding(.horizontal, 11)
                        .padding(.vertical, 5)
                        .foregroundStyle(viewModel.merchantSortField == field ? Color.white : Color.kTertiary)
                        .background(
                            viewModel.merchantSortField == field
                                ? Color.kPrimary
                                : Color.kSurface,
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
    
    // MARK: - All Merchants Section
    
    private var allMerchantsSection: some View {
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
            _Concurrency.Task {
                await vm.toggleMerchantExpand(name, userId: uid)
            }
        } label: {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(merchant.name)
                            .font(.system(size: 14, weight: .semibold))
                            .tracking(-0.3)
                            .foregroundStyle(Color.kPrimary)
                            .lineLimit(1)
                        
                        if merchant.isRecurring {
                            KStatusBadge(text: "Recurring", style: .pending)
                        }
                    }
                    
                    // Compact inline stats
                    HStack(spacing: 4) {
                        Text("\(merchant.transactionCount) txns")
                            .font(.system(size: 9, weight: .semibold))
                            .tracking(0.3)
                            .foregroundStyle(Color.kTertiary)
                        
                        Text("·")
                            .foregroundStyle(Color.kPlaceholder)
                        
                        Text("avg \(formatCurrency(merchant.averageTransaction))")
                            .font(.system(size: 9, weight: .semibold))
                            .tracking(0.3)
                            .foregroundStyle(Color.kTertiary)
                        
                        Text("·")
                            .foregroundStyle(Color.kPlaceholder)
                        
                        Text(String(format: "%.1f%%", merchant.sharePercent))
                            .font(.system(size: 9, weight: .semibold))
                            .tracking(0.3)
                            .foregroundStyle(Color.kTertiary)
                        
                        ForEach(Array(merchant.categories.prefix(1)), id: \.self) { cat in
                            Text(cat)
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(Color.kSecondary)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(Color.kDividerBg, in: Capsule())
                        }
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
            HStack {
                Spacer()
                ProgressView()
                    .scaleEffect(0.7)
                    .padding(.vertical, 12)
                Spacer()
            }
            .background(Color.kSurface)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.kBorder, lineWidth: 1))
        } else if let detail = viewModel.merchantDetails[merchant.name] {
            VStack(alignment: .leading, spacing: 10) {
                // Stats strip
                KStatRow(items: [
                    (label: "Spent", value: formatCurrency(detail.totalSpent), color: Color.kPrimary),
                    (label: "Earned", value: formatCurrency(detail.totalEarned), color: Color.kPrimary),
                    (label: "Net", value: formatCurrency(detail.netAmount), color: Color.kPrimary),
                    (label: "Avg", value: formatCurrency(merchant.averageTransaction), color: Color.kPrimary)
                ])
                
                HStack(spacing: 12) {
                    detailStat(label: "First Seen", value: formatShortDate(detail.firstSeen), color: Color.kSecondary)
                    detailStat(label: "Last Seen", value: formatShortDate(detail.lastSeen), color: Color.kSecondary)
                    detailStat(label: "Share", value: String(format: "%.1f%%", merchant.sharePercent), color: Color.kSecondary)
                    detailStat(label: "Txns", value: "\(detail.transactions.count)", color: Color.kSecondary)
                }
                
                if !detail.transactions.isEmpty {
                    VStack(alignment: .leading, spacing: 0) {
                        KLabel("Recent Transactions")
                            .padding(.bottom, 6)
                        
                        ForEach(Array(detail.transactions.prefix(8).enumerated()), id: \.element.id) { index, txn in
                            HStack(spacing: 6) {
                                Text(formatShortDate(txn.date))
                                    .font(.system(size: 10, weight: .medium))
                                    .tracking(0.2)
                                    .foregroundStyle(Color.kTertiary)
                                    .frame(width: 45, alignment: .leading)
                                
                                if txn.isPending == true {
                                    KStatusBadge(text: "P", style: .pending)
                                }
                                
                                Text(txn.name ?? "Unknown")
                                    .font(.system(size: 12, weight: .medium))
                                    .tracking(-0.1)
                                    .foregroundStyle(Color.kPrimary)
                                    .lineLimit(1)
                                
                                Spacer()
                                
                                Text("\(txn.isExpense ? "-" : "+")\(formatCurrency(txn.displayAmount))")
                                    .font(.system(size: 12, weight: .semibold))
                                    .tracking(-0.1)
                                    .foregroundStyle(Color.kPrimary)
                            }
                            .padding(.vertical, 5)
                            
                            if index < detail.transactions.prefix(8).count - 1 {
                                Rectangle().fill(Color.kBorder).frame(height: 1)
                            }
                        }
                        
                        if detail.transactions.count > 8 {
                            KLabel("+\(detail.transactions.count - 8) more")
                                .padding(.top, 4)
                        }
                    }
                }
                
                if !merchant.categories.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        KLabel("Categories")
                        
                        FlowLayout(spacing: 4) {
                            ForEach(Array(merchant.categories.sorted()), id: \.self) { cat in
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
            .background(Color.kSurface)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.kBorder, lineWidth: 1))
        }
    }
    
    private func detailStat(label: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            KLabel(label)
            Text(value)
                .font(.system(size: 12, weight: .bold))
                .tracking(-0.1)
                .foregroundStyle(color)
        }
    }
    
    // MARK: - Footer
    
    private var merchantFooter: some View {
        HStack {
            KLabel("\(filteredMerchants.count) merchant\(filteredMerchants.count == 1 ? "" : "s")")
            Spacer()
            Text("Total: \(formatCurrency(viewModel.merchantTotalVolume))")
                .font(.system(size: 12, weight: .bold))
                .tracking(-0.1)
                .foregroundStyle(Color.kPrimary)
        }
        .padding(.horizontal, 2)
    }
    
    // MARK: - Helpers
    
    private func formatCurrency(_ value: Double) -> String {
        abs(value).formatted(.currency(code: "USD").precision(.fractionLength(0)))
    }
    
    private func formatShortDate(_ dateString: String) -> String {
        let date = viewModel.parseDate(dateString)
        if date == .distantPast { return "—" }
        return date.formatted(.dateTime.month(.abbreviated).day())
    }
}

#Preview {
    NavigationStack {
        TransactionsMerchantsView(viewModel: TransactionsViewModel())
    }
    .environment(\.injected, .previewAuthenticated)
}
