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
            } else if viewModel.ledgerDayGroups.isEmpty {
                KEmptyState(
                    icon: "doc.text",
                    title: "No Entries",
                    message: "No transactions found for this period."
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        LazyVStack(spacing: 0) {
            ForEach(viewModel.ledgerDayGroups) { group in
                daySection(group: group)
            }
        }
        .padding(.bottom, 100)
    }

    // MARK: - Day Section

    private func daySection(group: DayGroup) -> some View {
        VStack(spacing: 0) {
            dayHeader(group: group)

            if viewModel.expandedDays.contains(group.date) {
                VStack(spacing: 0) {
                    if group.loading {
                        ProgressView()
                            .scaleEffect(0.7)
                            .padding(.vertical, 14)
                            .frame(maxWidth: .infinity)
                            .background(Color.kHoverSurface)
                    }

                    ForEach(group.transactions) { txn in
                        transactionRow(txn: txn)

                        if viewModel.expandedTransactionId == txn.id {
                            transactionDetail(txn: txn)
                        }
                    }
                }
                .transition(.opacity)
            }

            Rectangle().fill(Color.kBorder).frame(height: 1)
        }
    }

    // MARK: - Day Header

    private func dayHeader(group: DayGroup) -> some View {
        let isExpanded = viewModel.expandedDays.contains(group.date)

        return Button {
            let uid = userId
            let vm = viewModel
            let date = group.date
            _Concurrency.Task { await vm.toggleDay(date, userId: uid) }
        } label: {
            HStack(spacing: 12) {
                // Date badge
                VStack(spacing: 0) {
                    Text(dayOfMonthStr(group.date))
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Color.kPrimary)
                    Text(shortDayStr(group.dayOfWeek))
                        .font(.system(size: 9, weight: .semibold))
                        .tracking(0.3)
                        .foregroundStyle(Color.kTertiary)
                }
                .frame(width: 34)

                VStack(alignment: .leading, spacing: 2) {
                    Text(group.label)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.kPrimary)
                    Text("\(group.txnCount) transaction\(group.txnCount == 1 ? "" : "s")")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color.kTertiary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    if group.dayDebit > 0 {
                        Text("-\(formatCurrency(group.dayDebit))")
                            .font(.system(size: 13, weight: .semibold))
                            .tracking(-0.2)
                            .foregroundStyle(Color.kPrimary)
                    }
                    if group.dayCredit > 0 {
                        Text("+\(formatCurrency(group.dayCredit))")
                            .font(.system(size: 11, weight: .medium))
                            .tracking(-0.1)
                            .foregroundStyle(Color.kGreen)
                    }
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Color.kTertiary)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    .animation(.easeInOut(duration: 0.15), value: isExpanded)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
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
                HStack(spacing: 12) {
                    // Direction indicator
                    ZStack {
                        Circle()
                            .fill(txn.isExpense ? Color.kDividerBg : Color.kGreenBg)
                            .frame(width: 34, height: 34)
                        Image(systemName: txn.isExpense ? "arrow.up.right" : "arrow.down.left")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(txn.isExpense ? Color.kSecondary : Color.kGreen)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 5) {
                            Text(txn.merchantName ?? txn.name ?? "Unknown")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color.kPrimary)
                                .lineLimit(1)

                            if txn.isPending == true {
                                KStatusBadge(text: "P", style: .pending)
                            }
                        }

                        if let cat = txn.category {
                            Text(cat)
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(Color.kSecondary)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(Color.kDividerBg, in: Capsule())
                        }
                    }

                    Spacer()

                    Text("\(txn.isIncome ? "+" : "-")\(formatCurrency(txn.displayAmount))")
                        .font(.system(size: 14, weight: .bold))
                        .tracking(-0.3)
                        .foregroundStyle(txn.isIncome ? Color.kGreen : Color.kPrimary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    viewModel.expandedTransactionId == txn.id
                        ? Color.kHoverSurface
                        : Color.kSurface
                )
            }
            .buttonStyle(.plain)

            Rectangle().fill(Color.kBorder).frame(height: 1).padding(.leading, 62)
        }
    }

    // MARK: - Transaction Detail

    private func transactionDetail(txn: TransactionDTO) -> some View {
        let details: [(String, String?)] = [
            ("ID", txn.transactionId.map { String($0.prefix(12)) }),
            ("Date", formatShortDate(effectiveDate(txn))),
            ("Currency", txn.isoCurrencyCode ?? "USD"),
            ("Status", txn.isPending == true ? "Pending" : "Posted"),
        ]

        return LazyVGrid(
            columns: [GridItem(.flexible()), GridItem(.flexible())],
            alignment: .leading,
            spacing: 10
        ) {
            ForEach(details.filter { $0.1 != nil }, id: \.0) { item in
                VStack(alignment: .leading, spacing: 2) {
                    KLabel(item.0)
                    Text(item.1!)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.kPrimary)
                }
            }
        }
        .padding(12)
        .background(Color.kHoverSurface)
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
        .transition(.opacity)
    }

    // MARK: - Helpers

    private func effectiveDate(_ txn: TransactionDTO) -> String {
        txn.isPending == true ? (txn.createdAt ?? txn.date) : txn.date
    }

    private func dayOfMonthStr(_ dateStr: String) -> String {
        viewModel.parseDate(dateStr).formatted(.dateTime.day())
    }

    private func shortDayStr(_ fullDay: String) -> String {
        String(fullDay.prefix(3)).uppercased()
    }

    private func formatCurrency(_ value: Double) -> String {
        abs(value).formatted(.currency(code: "USD").precision(.fractionLength(0)))
    }

    private func formatShortDate(_ dateString: String) -> String {
        viewModel.parseDate(dateString).formatted(.dateTime.month(.abbreviated).day())
    }
}

#Preview {
    NavigationStack {
        TransactionsLedgerView(viewModel: TransactionsViewModel())
    }
    .environment(\.injected, .previewAuthenticated)
}
