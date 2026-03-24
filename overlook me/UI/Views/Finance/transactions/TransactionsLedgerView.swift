import SwiftUI

// MARK: - Transactions Ledger View

struct TransactionsLedgerView: View {
    @SwiftUI.Environment(\.injected) private var container: DIContainer
    @Bindable var viewModel: TransactionsViewModel
    
    private var userId: String {
        container.appState.state.auth.user?.id ?? ""
    }
    
    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.ledgerDayGroups.isEmpty {
                VStack(spacing: 8) {
                    ProgressView()
                    KLabel("Loading ledger")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.kSurface)
            } else if viewModel.ledgerDayGroups.isEmpty {
                KEmptyState(
                    icon: "doc.text",
                    title: "No Entries",
                    message: "No transactions found for this period."
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.kSurface)
            } else {
                ledgerContent
            }
        }
        .background(Color.kSurface)
        .task {
            if viewModel.ledgerDayGroups.isEmpty {
                await viewModel.loadLedgerSummary(userId: userId)
            }
        }
    }
    
    // MARK: - Ledger Content
    
    private var ledgerContent: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                // Period picker + summary scroll with content — never sticky
                VStack(spacing: 10) {
                    TransactionsPeriodPicker(viewModel: viewModel)
                    TransactionsSummaryStrip(viewModel: viewModel)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                
                ledgerSummaryStrip
                columnHeaders
                
                ForEach(viewModel.ledgerDayGroups) { group in
                    daySection(group: group)
                }
                
                periodFooter
            }
        }
        .refreshable {
            await viewModel.loadLedgerSummary(userId: userId)
        }
    }
    
    // MARK: - Summary Strip
    
    private var ledgerSummaryStrip: some View {
        let net = viewModel.ledgerNetFlow
        return KStatRow(items: [
            (label: "Total Debits", value: formatCurrency(viewModel.ledgerTotalDebits), color: Color.kRed),
            (label: "Total Credits", value: formatCurrency(viewModel.ledgerTotalCredits), color: Color.kGreen),
            (label: "Net Flow", value: "\(net >= 0 ? "+" : "")\(formatCurrency(net))", color: net >= 0 ? Color.kGreen : Color.kRed),
            (label: "Entries", value: "\(viewModel.ledgerTxnCount)", color: Color.kPrimary)
        ])
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
    }
    
    // MARK: - Column Headers
    
    private var columnHeaders: some View {
        HStack(spacing: 0) {
            Text("DATE")
                .frame(width: 50, alignment: .leading)
            Text("DESCRIPTION")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("DEBIT")
                .frame(width: 65, alignment: .trailing)
            Text("CREDIT")
                .frame(width: 65, alignment: .trailing)
        }
        .font(.system(size: 9, weight: .semibold))
        .tracking(0.6)
        .foregroundStyle(Color.kTertiary)
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(Color.kDividerBg)
    }
    
    // MARK: - Day Section
    
    private func daySection(group: DayGroup) -> some View {
        VStack(spacing: 0) {
            dayHeader(group: group)
            
            if viewModel.expandedDays.contains(group.date) {
                VStack(spacing: 0) {
                    if group.loading {
                        HStack {
                            Spacer()
                            ProgressView()
                                .scaleEffect(0.7)
                                .padding(.vertical, 12)
                            Spacer()
                        }
                        .background(Color.kHoverSurface)
                    }
                    
                    ForEach(group.transactions) { txn in
                        transactionRow(txn: txn)
                        
                        if viewModel.expandedTransactionId == txn.id {
                            transactionDetail(txn: txn)
                        }
                    }
                    
                    if group.loaded && !group.transactions.isEmpty {
                        daySubtotal(group: group)
                    }
                }
                .transition(.opacity)
            }
            
            Rectangle().fill(Color.kBorder).frame(height: 1)
        }
    }
    
    private func dayHeader(group: DayGroup) -> some View {
        let isExpanded = viewModel.expandedDays.contains(group.date)
        let netFlow = group.dayCredit - group.dayDebit
        
        return Button {
            let uid = userId
            let vm = viewModel
            let date = group.date
            _Concurrency.Task {
                await vm.toggleDay(date, userId: uid)
            }
        } label: {
            HStack(spacing: 0) {
                // Left accent bar — neutral, no color coding
                Capsule()
                    .fill(Color.kBorderMedium)
                    .frame(width: 3, height: 28)
                    .padding(.trailing, 8)
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(Color.kTertiary)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    .padding(.trailing, 8)
                
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 5) {
                        Text(group.dayOfWeek)
                            .font(.system(size: 12, weight: .semibold))
                            .tracking(-0.1)
                            .foregroundStyle(Color.kPrimary)
                        Text(group.label)
                            .font(.system(size: 10, weight: .medium))
                            .tracking(0.2)
                            .foregroundStyle(Color.kTertiary)
                    }
                    
                    HStack(spacing: 6) {
                        Text("\(group.txnCount) ENTR\(group.txnCount == 1 ? "Y" : "IES")")
                            .font(.system(size: 9, weight: .semibold))
                            .tracking(0.4)
                            .foregroundStyle(Color.kTertiary)
                        
                        if group.pendingCount > 0 {
                            KStatusBadge(text: "\(group.pendingCount) pending", style: .pending)
                        }
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 1) {
                    if group.dayDebit > 0 {
                        Text("-\(formatCurrency(group.dayDebit))")
                            .font(.system(size: 11, weight: .semibold))
                            .tracking(-0.1)
                            .foregroundStyle(Color.kPrimary)
                    }
                    if group.dayCredit > 0 {
                        Text("+\(formatCurrency(group.dayCredit))")
                            .font(.system(size: 11, weight: .semibold))
                            .tracking(-0.1)
                            .foregroundStyle(Color.kPrimary)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(isExpanded ? Color.kDividerBg : Color.kSurface)
        }
        .buttonStyle(KPressButtonStyle())
    }
    
    // MARK: - Transaction Row
    
    private func transactionRow(txn: TransactionDTO) -> some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.1)) {
                    viewModel.expandedTransactionId = viewModel.expandedTransactionId == txn.id ? nil : txn.id
                }
            } label: {
                HStack(spacing: 0) {
                    // Date
                    Text(formatShortDate(effectiveDate(txn)))
                        .font(.system(size: 10, weight: .medium))
                        .tracking(0.2)
                        .foregroundStyle(Color.kSecondary)
                        .frame(width: 50, alignment: .leading)
                    
                    // Description — merchant as primary, name as secondary
                    VStack(alignment: .leading, spacing: 1) {
                        HStack(spacing: 5) {
                            Text(txn.merchantName ?? txn.name ?? "Unknown")
                                .font(.system(size: 12, weight: .semibold))
                                .tracking(-0.1)
                                .foregroundStyle(Color.kPrimary)
                                .lineLimit(1)
                            
                            if txn.isPending == true {
                                KStatusBadge(text: "P", style: .pending)
                            }
                        }
                        
                        if let name = txn.name, let merchant = txn.merchantName, name != merchant {
                            Text(name)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(Color.kTertiary)
                                .lineLimit(1)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // Debit
                    if txn.isExpense {
                        Text(formatCurrency(txn.displayAmount))
                            .font(.system(size: 12, weight: .semibold))
                            .tracking(-0.1)
                            .foregroundStyle(Color.kPrimary)
                            .frame(width: 65, alignment: .trailing)
                    } else {
                        Text("—")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.kPlaceholder)
                            .frame(width: 65, alignment: .trailing)
                    }
                    
                    // Credit
                    if txn.isIncome {
                        Text(formatCurrency(txn.displayAmount))
                            .font(.system(size: 12, weight: .semibold))
                            .tracking(-0.1)
                            .foregroundStyle(Color.kPrimary)
                            .frame(width: 65, alignment: .trailing)
                    } else {
                        Text("—")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.kPlaceholder)
                            .frame(width: 65, alignment: .trailing)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    viewModel.expandedTransactionId == txn.id
                        ? Color.kHoverSurface
                        : Color.kSurface
                )
            }
            .buttonStyle(.plain)
            
            Rectangle().fill(Color.kBorder).frame(height: 1).padding(.leading, 14)
        }
    }
    
    // MARK: - Transaction Detail
    
    private func transactionDetail(txn: TransactionDTO) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            let details: [(String, String?)] = [
                ("Transaction ID", txn.transactionId),
                ("Merchant", txn.merchantName),
                ("Date", formatShortDate(effectiveDate(txn))),
                ("Currency", txn.isoCurrencyCode ?? "USD"),
                ("Status", txn.isPending == true ? "Pending" : "Posted"),
                ("Notes", txn.notes),
            ]
            
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 10),
                GridItem(.flexible(), spacing: 10)
            ], alignment: .leading, spacing: 8) {
                ForEach(details.filter { $0.1 != nil }, id: \.0) { item in
                    VStack(alignment: .leading, spacing: 2) {
                        KLabel(item.0)
                        Text(item.1!)
                            .font(.system(size: 12, weight: .medium))
                            .tracking(-0.1)
                            .foregroundStyle(Color.kPrimary)
                            .lineLimit(2)
                    }
                }
            }
            
            HStack(spacing: 6) {
                if txn.isExcludedFromBudget == true {
                    KStatusBadge(text: "Excluded", style: .fail)
                }
                
                if let category = txn.category {
                    Text(category)
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(0.2)
                        .foregroundStyle(Color.kSecondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.kDividerBg, in: Capsule())
                }
            }
        }
        .padding(12)
        .background(Color.kHoverSurface)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal, 14)
        .padding(.vertical, 4)
        .transition(.opacity)
    }
    
    // MARK: - Day Subtotal
    
    private func daySubtotal(group: DayGroup) -> some View {
        HStack(spacing: 0) {
            Text("")
                .frame(width: 50, alignment: .leading)
            Text("DAY SUBTOTAL")
                .font(.system(size: 9, weight: .bold))
                .tracking(0.6)
                .foregroundStyle(Color.kSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            if group.dayDebit > 0 {
                Text(formatCurrency(group.dayDebit))
                    .font(.system(size: 12, weight: .bold))
                    .tracking(-0.1)
                    .foregroundStyle(Color.kPrimary)
                    .frame(width: 65, alignment: .trailing)
            } else {
                Text("—")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.kPlaceholder)
                    .frame(width: 65, alignment: .trailing)
            }
            
            if group.dayCredit > 0 {
                Text(formatCurrency(group.dayCredit))
                    .font(.system(size: 12, weight: .bold))
                    .tracking(-0.1)
                    .foregroundStyle(Color.kPrimary)
                    .frame(width: 65, alignment: .trailing)
            } else {
                Text("—")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.kPlaceholder)
                    .frame(width: 65, alignment: .trailing)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color.kDividerBg)
    }
    
    // MARK: - Period Footer
    
    private var periodFooter: some View {
        VStack(spacing: 6) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Period Total")
                        .font(.system(size: 14, weight: .semibold))
                        .tracking(-0.3)
                        .foregroundStyle(Color.kPrimary)
                    KLabel("\(viewModel.ledgerTxnCount) entries across \(viewModel.ledgerDayGroups.count) days")
                }
                Spacer()
            }
            
            let net = viewModel.ledgerNetFlow
            KStatRow(items: [
                (label: "Debits", value: formatCurrency(viewModel.ledgerTotalDebits), color: Color.kRed),
                (label: "Credits", value: formatCurrency(viewModel.ledgerTotalCredits), color: Color.kGreen),
                (label: "Net", value: "\(net >= 0 ? "+" : "")\(formatCurrency(net))", color: net >= 0 ? Color.kGreen : Color.kRed)
            ])
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
    
    // MARK: - Helpers
    
    private func effectiveDate(_ txn: TransactionDTO) -> String {
        if txn.isPending == true, let authDate = txn.createdAt {
            return authDate
        }
        return txn.date
    }
    
    private func formatCurrency(_ value: Double) -> String {
        abs(value).formatted(.currency(code: "USD").precision(.fractionLength(0)))
    }
    
    private func formatShortDate(_ dateString: String) -> String {
        let date = viewModel.parseDate(dateString)
        return date.formatted(.dateTime.month(.abbreviated).day())
    }
}

#Preview {
    NavigationStack {
        TransactionsLedgerView(viewModel: TransactionsViewModel())
    }
    .environment(\.injected, .previewAuthenticated)
}
