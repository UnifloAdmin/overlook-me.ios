import SwiftUI

// MARK: - Transactions Search View

struct TransactionsSearchView: View {
    @SwiftUI.Environment(\.injected) private var container: DIContainer
    @Bindable var viewModel: TransactionsViewModel

    private var userId: String {
        container.appState.state.auth.user?.id ?? ""
    }

    var body: some View {
        LazyVStack(spacing: 10) {
            KSearchField(
                placeholder: "Search transactions...",
                text: $viewModel.searchFilters.searchText,
                onCommit: { performSearch() }
            )
            .onChange(of: viewModel.searchFilters.searchText) { _, _ in
                _Concurrency.Task {
                    try? await _Concurrency.Task.sleep(for: .milliseconds(300))
                    performSearch()
                }
            }

            filtersSection
            resultsSummary

            if !viewModel.searchResults.isEmpty {
                resultsList
            } else if !viewModel.isSearchLoading {
                KEmptyState(
                    icon: "magnifyingglass",
                    title: "No transactions found",
                    message: "Adjust your filters to see more results",
                    ctaLabel: activeFiltersCount > 0 ? "Clear Filters" : nil,
                    ctaAction: { viewModel.clearSearchFilters() }
                )
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 100)
        .task {
            await viewModel.loadCategories(userId: userId)
        }
    }

    // MARK: - Filters

    private var filtersSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Type pills
            HStack(spacing: 4) {
                ForEach(["all", "expense", "income"], id: \.self) { type in
                    let isActive = viewModel.searchFilters.transactionType == type
                    Button {
                        viewModel.searchFilters.transactionType = type
                        performSearch()
                    } label: {
                        Text(type == "all" ? "All" : type.capitalized)
                            .font(.system(size: 11, weight: .semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 5)
                            .foregroundStyle(isActive ? .white : Color.kTertiary)
                            .background(isActive ? Color.kPrimary : Color.kSurface, in: Capsule())
                            .overlay(isActive ? nil : Capsule().stroke(Color.kBorderMedium, lineWidth: 1))
                    }
                    .buttonStyle(KPressButtonStyle())
                }

                Spacer()

                if !viewModel.categories.isEmpty {
                    Picker("", selection: $viewModel.searchFilters.category) {
                        Text("All Categories").tag("all")
                        ForEach(viewModel.categories, id: \.self) { cat in
                            Text(cat).tag(cat)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .tint(Color.kSecondary)
                    .onChange(of: viewModel.searchFilters.category) { _, _ in performSearch() }
                }
            }

            // Date range
            HStack(spacing: 8) {
                KLabel("From")
                DatePicker("", selection: $viewModel.searchFilters.startDate, displayedComponents: .date)
                    .labelsHidden()
                    .datePickerStyle(.compact)
                    .onChange(of: viewModel.searchFilters.startDate) { _, _ in performSearch() }

                Text("–")
                    .foregroundStyle(Color.kTertiary)
                    .font(.system(size: 12))

                KLabel("To")
                DatePicker("", selection: $viewModel.searchFilters.endDate, displayedComponents: .date)
                    .labelsHidden()
                    .datePickerStyle(.compact)
                    .onChange(of: viewModel.searchFilters.endDate) { _, _ in performSearch() }
            }
        }
        .padding(12)
        .background(Color.kSurface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.kBorder, lineWidth: 1))
    }

    // MARK: - Results Summary

    private var resultsSummary: some View {
        HStack(spacing: 8) {
            Text("\(viewModel.searchResults.count)")
                .font(.system(size: 18, weight: .bold))
                .tracking(-0.5)
                .foregroundStyle(Color.kPrimary)

            KLabel("results")

            if activeFiltersCount > 0 {
                Button {
                    viewModel.clearSearchFilters()
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "xmark")
                            .font(.system(size: 8, weight: .bold))
                        Text("Clear (\(activeFiltersCount))")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundStyle(Color.kRed)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(Color.kRedBg, in: Capsule())
                }
                .buttonStyle(KPressButtonStyle())
            }

            Spacer()

            if viewModel.isSearchLoading {
                ProgressView().scaleEffect(0.7)
            }
        }
    }

    // MARK: - Results List

    private var resultsList: some View {
        VStack(spacing: 0) {
            ForEach(Array(viewModel.searchResults.enumerated()), id: \.element.id) { index, txn in
                searchResultRow(txn: txn)

                if index < viewModel.searchResults.count - 1 {
                    Rectangle().fill(Color.kBorder).frame(height: 1).padding(.leading, 58)
                }
            }

            if viewModel.searchTotalPages > 1 {
                HStack(spacing: 14) {
                    KPill(label: "Prev", icon: "chevron.left") {
                        if viewModel.searchPage > 1 {
                            viewModel.searchPage -= 1
                            performSearch()
                        }
                    }
                    .opacity(viewModel.searchPage <= 1 ? 0.4 : 1)

                    KLabel("Page \(viewModel.searchPage) of \(viewModel.searchTotalPages)")

                    KPill(label: "Next", icon: "chevron.right") {
                        if viewModel.searchPage < viewModel.searchTotalPages {
                            viewModel.searchPage += 1
                            performSearch()
                        }
                    }
                    .opacity(viewModel.searchPage >= viewModel.searchTotalPages ? 0.4 : 1)
                }
                .padding(.vertical, 12)
            }
        }
        .background(Color.kSurface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.kBorder, lineWidth: 1))
    }

    private func searchResultRow(txn: TransactionDTO) -> some View {
        HStack(spacing: 12) {
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
                        .tracking(-0.2)
                        .foregroundStyle(Color.kPrimary)
                        .lineLimit(1)

                    if txn.isPending == true {
                        KStatusBadge(text: "P", style: .pending)
                    }
                }

                HStack(spacing: 5) {
                    Text(formatShortDate(txn.date))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color.kTertiary)

                    if let cat = txn.category {
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

            Text("\(txn.isIncome ? "+" : "-")\(formatCurrency(txn.displayAmount))")
                .font(.system(size: 14, weight: .bold))
                .tracking(-0.3)
                .foregroundStyle(txn.isIncome ? Color.kGreen : Color.kPrimary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    // MARK: - Helpers

    private var activeFiltersCount: Int {
        var count = 0
        if !viewModel.searchFilters.searchText.isEmpty { count += 1 }
        if viewModel.searchFilters.transactionType != "all" { count += 1 }
        if viewModel.searchFilters.category != "all" { count += 1 }
        if viewModel.searchFilters.minAmount != nil { count += 1 }
        if viewModel.searchFilters.maxAmount != nil { count += 1 }
        return count
    }

    private func performSearch() {
        let uid = userId
        let vm = viewModel
        _Concurrency.Task { await vm.executeSearch(userId: uid) }
    }

    private func formatCurrency(_ value: Double) -> String {
        abs(value).formatted(.currency(code: "USD").precision(.fractionLength(0)))
    }

    private func formatShortDate(_ dateString: String) -> String {
        let d = viewModel.parseDate(dateString)
        return d == .distantPast ? "—" : d.formatted(.dateTime.month(.abbreviated).day())
    }
}

#Preview {
    NavigationStack {
        TransactionsSearchView(viewModel: TransactionsViewModel())
    }
    .environment(\.injected, .previewAuthenticated)
}
