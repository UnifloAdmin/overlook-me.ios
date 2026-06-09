import SwiftUI
import Observation

// MARK: - Create View Model

@Observable
@MainActor
private final class BudgetCreateViewModel {
    var name: String = ""
    var amount: String = ""
    var period: BudgetPeriodOption = .monthly
    var alertThreshold: Double = 0.8
    var isSubmitting = false
    var errorMessage: String?

    var parsedAmount: Double? { Double(amount.replacingOccurrences(of: ",", with: "")) }

    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && (parsedAmount ?? 0) > 0
    }

    var alertDollarPreview: String {
        guard let amt = parsedAmount else { return "--" }
        return (amt * alertThreshold).formatted(.currency(code: "USD").precision(.fractionLength(0)))
    }

    private let api = BudgetsAPI(client: AppAPIClient.live())

    func create(userId: String) async -> Bool {
        guard let amount = parsedAmount, isValid else { return false }
        isSubmitting = true
        errorMessage = nil
        do {
            _ = try await api.createBudget(CreateBudgetRequestDTO(
                userId: userId,
                name: name.trimmingCharacters(in: .whitespaces),
                categoryId: nil,
                amount: amount,
                period: period.rawValue,
                startDate: nil,
                endDate: nil,
                alertThreshold: alertThreshold
            ))
            isSubmitting = false
            return true
        } catch {
            errorMessage = error.localizedDescription
            isSubmitting = false
            return false
        }
    }
}

// MARK: - Period Option

enum BudgetPeriodOption: String, CaseIterable {
    case weekly    = "Weekly"
    case monthly   = "Monthly"
    case quarterly = "Quarterly"
    case yearly    = "Yearly"

    var icon: String {
        switch self {
        case .weekly:    return "7.circle"
        case .monthly:   return "calendar"
        case .quarterly: return "calendar.badge.clock"
        case .yearly:    return "chart.line.uptrend.xyaxis"
        }
    }

    var description: String {
        switch self {
        case .weekly:    return "Resets every Monday"
        case .monthly:   return "Resets 1st of month"
        case .quarterly: return "Resets every quarter"
        case .yearly:    return "Resets Jan 1st"
        }
    }
}

// MARK: - Budget Create View

struct BudgetCreateView: View {
    @SwiftUI.Environment(\.injected) private var container: DIContainer
    @Environment(\.dismiss) private var dismiss
    @State private var vm = BudgetCreateViewModel()
    @FocusState private var focusedField: Field?

    var onCreated: (() async -> Void)?

    enum Field { case name, amount }

    private var userId: String {
        container.appState.state.auth.user?.id ?? ""
    }

    // Preset amounts
    private let amountPresets: [Double] = [100, 200, 300, 500, 1000]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    VStack(spacing: 16) {
                        nameField
                        amountSection
                        periodSection
                        alertSection

                        if let error = vm.errorMessage {
                            Text(error)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(Color.kRed)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 4)
                        }

                        createButton
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 40)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Kalshi.bg)
            .navigationTitle("New Budget")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.kSecondary)
                }
            }
            .onTapGesture { focusedField = nil }
        }
    }

    // MARK: - Name Field

    private var nameField: some View {
        VStack(alignment: .leading, spacing: 6) {
            KLabel("Budget Name")

            TextField("e.g. Groceries, Dining Out…", text: $vm.name)
                .font(.system(size: 15, weight: .semibold))
                .tracking(-0.2)
                .foregroundStyle(Color.kPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color.kSurface)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(focusedField == .name ? Color.kPrimary.opacity(0.5) : Color.kBorder, lineWidth: 1)
                )
                .focused($focusedField, equals: .name)
        }
    }

    // MARK: - Amount Section

    private var amountSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            KLabel("Budget Amount")

            // Amount input
            HStack(spacing: 4) {
                Text("$")
                    .font(.system(size: 20, weight: .bold))
                    .tracking(-0.5)
                    .foregroundStyle(Color.kTertiary)

                TextField("0", text: $vm.amount)
                    .font(.system(size: 22, weight: .bold))
                    .tracking(-0.8)
                    .foregroundStyle(Color.kPrimary)
                    .keyboardType(.decimalPad)
                    .focused($focusedField, equals: .amount)
                    .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.kSurface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(focusedField == .amount ? Color.kPrimary.opacity(0.5) : Color.kBorder, lineWidth: 1)
            )

            // Quick presets
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(amountPresets, id: \.self) { preset in
                        Button {
                            vm.amount = String(Int(preset))
                            focusedField = nil
                        } label: {
                            Text("$\(Int(preset))")
                                .font(.system(size: 12, weight: .semibold))
                                .tracking(-0.1)
                                .foregroundStyle(vm.amount == String(Int(preset)) ? .white : Color.kSecondary)
                                .padding(.horizontal, 13)
                                .padding(.vertical, 6)
                                .background(
                                    vm.amount == String(Int(preset)) ? Color.kPrimary : Color.kSurface,
                                    in: Capsule()
                                )
                                .overlay(
                                    vm.amount == String(Int(preset))
                                        ? nil
                                        : Capsule().stroke(Color.kBorderMedium, lineWidth: 1)
                                )
                        }
                        .buttonStyle(KPressButtonStyle())
                    }
                }
            }
        }
    }

    // MARK: - Period Section

    private var periodSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            KLabel("Budget Period")

            VStack(spacing: 6) {
                ForEach(BudgetPeriodOption.allCases, id: \.rawValue) { option in
                    periodRow(option)
                }
            }
        }
    }

    private func periodRow(_ option: BudgetPeriodOption) -> some View {
        let isSelected = vm.period == option
        return Button {
            withAnimation(Kalshi.micro) { vm.period = option }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: option.icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(isSelected ? Color.kPrimary : Color.kSecondary)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 1) {
                    Text(option.rawValue)
                        .font(.system(size: 13, weight: .semibold))
                        .tracking(-0.1)
                        .foregroundStyle(Color.kPrimary)

                    Text(option.description)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.kTertiary)
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 16))
                    .foregroundStyle(isSelected ? Color.kPrimary : Color.kBorderMedium)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(isSelected ? Color.kDividerBg : Color.kSurface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.kPrimary.opacity(0.3) : Color.kBorder, lineWidth: 1)
            )
        }
        .buttonStyle(KPressButtonStyle())
    }

    // MARK: - Alert Section

    private var alertSection: some View {
        KCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Alert Threshold")
                            .font(.system(size: 13, weight: .semibold))
                            .tracking(-0.2)
                            .foregroundStyle(Color.kPrimary)

                        Text("Notify me when I hit \(Int(vm.alertThreshold * 100))% of budget")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Color.kTertiary)
                    }

                    Spacer()

                    Text(vm.alertDollarPreview)
                        .font(.system(size: 14, weight: .bold))
                        .tracking(-0.4)
                        .foregroundStyle(Color.kPrimary)
                        .contentTransition(.numericText())
                        .animation(.easeInOut(duration: 0.15), value: vm.alertDollarPreview)
                }

                Slider(value: $vm.alertThreshold, in: 0.5...1.0, step: 0.05)
                    .tint(Color.kPrimary)

                HStack {
                    Text("50%")
                    Spacer()
                    Text("75%")
                    Spacer()
                    Text("100%")
                }
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(Color.kTertiary)
            }
        }
    }

    // MARK: - Create Button

    private var createButton: some View {
        Button {
            focusedField = nil
            _Concurrency.Task {
                let success = await vm.create(userId: userId)
                if success {
                    await onCreated?()
                    dismiss()
                }
            }
        } label: {
            HStack(spacing: 8) {
                if vm.isSubmitting {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(0.85)
                } else {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .bold))
                }
                Text(vm.isSubmitting ? "Creating…" : "Create Budget")
                    .font(.system(size: 15, weight: .semibold))
                    .tracking(-0.2)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(vm.isValid ? Color.kPrimary : Color.kBorderMedium, in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(KPressButtonStyle())
        .disabled(!vm.isValid || vm.isSubmitting)
    }
}

// MARK: - Preview

#Preview {
    BudgetCreateView()
        .environment(\.injected, .previewAuthenticated)
}
