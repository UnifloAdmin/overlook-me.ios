import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// kalTodayBg is not in the shared file — keep it locally
private extension Color {
    static let kalTodayBg = Color.kalToday.opacity(0.12)
}

// MARK: - AddNewHabitView

struct AddNewHabitView: View {
    @State private var activeError: HabitFormError?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.injected) private var container: DIContainer
    @StateObject private var viewModel = AddNewHabitViewModel()
    @FocusState private var focused: FormField?

    private enum FormField: Hashable {
        case name, description
    }

    private var currentUserId: String? { container.appState.state.auth.user?.id }
    private var saveDisabled: Bool { viewModel.draft.trimmedName.isEmpty || viewModel.isSaving }

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 14) {
                    modeCard
                    basicsCard
                    behaviourCard
                    priorityCard
                    categoryCard
                    scheduleCard
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 100)
            }
            .background(Color.kalBackground.ignoresSafeArea())
            .navigationTitle(viewModel.draft.mode == .challenge21 ? "21-Day Challenge" : "New Habit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(Color.kalMuted)
                    }
                    .disabled(viewModel.isSaving)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if viewModel.isSaving {
                        ProgressView().tint(Color.kalPrimary)
                    } else {
                        Button { performSave() } label: {
                            Image(systemName: "checkmark")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(saveDisabled ? Color.kalTertiary : Color.kalPrimary)
                        }
                        .disabled(saveDisabled)
                    }
                }
                ToolbarItem(placement: .keyboard) {
                    Button("Done") { focused = nil }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.kalPrimary)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
        }
        .interactiveDismissDisabled(viewModel.isSaving)
        .alert("Unable to Save", isPresented: Binding(
            get: { activeError != nil },
            set: { if !$0 { activeError = nil } })
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(activeError?.errorDescription ?? "")
        }
    }

    // MARK: - Mode Card

    private var modeCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                ForEach(HabitMode.allCases) { mode in
                    modeChip(mode)
                }
            }

            if viewModel.draft.mode == .challenge21, let expiry = viewModel.draft.expiryDate {
                HStack(spacing: 5) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.orange)
                    Text("Ends \(expiry, style: .date)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.kalMuted)
                }
                .padding(.leading, 2)
            }
        }
    }

    private func modeChip(_ mode: HabitMode) -> some View {
        let selected = viewModel.draft.mode == mode
        return Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.easeInOut(duration: 0.15)) { viewModel.draft.applyMode(mode) }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: mode.icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(selected ? Color.white : Color.kalMuted)
                    .frame(width: 28, height: 28)
                    .background(selected ? Color.kalPrimary : Color.kalInput, in: Circle())

                VStack(alignment: .leading, spacing: 1) {
                    Text(mode.title)
                        .font(.system(size: 12, weight: .semibold))
                        .tracking(-0.12)
                        .foregroundStyle(selected ? Color.kalPrimary : Color.kalMuted)
                    Text(mode == .challenge21 ? "21 days · daily" : "Open-ended")
                        .font(.system(size: 9, weight: .medium))
                        .tracking(0.18)
                        .foregroundStyle(Color.kalTertiary)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.kalSurface)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(selected ? Color.kalPrimary.opacity(0.45) : Color.kalBorder, lineWidth: selected ? 1.5 : 1)
            )
        }
        .buttonStyle(KalPressStyle())
    }

    // MARK: - Basics Card

    private var basicsCard: some View {
        VStack(spacing: 0) {
            bareInputRow(
                icon: "pencil",
                placeholder: "Habit name",
                text: binding(\.name),
                field: .name,
                capitalization: .words,
                next: .description
            )

            Rectangle()
                .fill(Color.kalBorder)
                .frame(height: 1)
                .padding(.leading, 40)

            bareInputRow(
                icon: "text.alignleft",
                placeholder: "Why does this matter?",
                text: binding(\.description),
                field: .description,
                axis: .vertical,
                lineLimit: 2...4
            )
        }
        .glassEffect(in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func bareInputRow(
        icon: String,
        placeholder: String,
        text: Binding<String>,
        field: FormField,
        axis: Axis = .horizontal,
        lineLimit: ClosedRange<Int>? = nil,
        capitalization: TextInputAutocapitalization = .sentences,
        next: FormField? = nil
    ) -> some View {
        HStack(alignment: axis == .vertical ? .top : .center, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.kalTertiary)
                .frame(width: 18)
                .padding(.top, axis == .vertical ? 2 : 0)

            if axis == .vertical {
                TextField(placeholder, text: text, axis: .vertical)
                    .font(.system(size: 14))
                    .foregroundStyle(Color.kalPrimary)
                    .lineLimit(lineLimit ?? 1...4)
                    .textInputAutocapitalization(capitalization)
                    .focused($focused, equals: field)
            } else {
                TextField(placeholder, text: text)
                    .font(.system(size: 14))
                    .foregroundStyle(Color.kalPrimary)
                    .textInputAutocapitalization(capitalization)
                    .focused($focused, equals: field)
                    .submitLabel(next != nil ? .next : .done)
                    .onSubmit { focused = next }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
    }

    // MARK: - Behaviour Card

    private var behaviourCard: some View {
        Picker("Habit type", selection: binding(\.isPositive)) {
            Label("Build", systemImage: "arrow.up").tag(true)
            Label("Break", systemImage: "arrow.down").tag(false)
        }
        .pickerStyle(.segmented)
        .onAppear  { applySegmentAppearance() }
        .onDisappear { resetSegmentAppearance() }
    }

    private func applySegmentAppearance() {
        let sel = UIColor(Color.kalPrimary)
        UISegmentedControl.appearance().selectedSegmentTintColor = sel
        UISegmentedControl.appearance().setTitleTextAttributes(
            [.foregroundColor: UIColor.white,
             .font: UIFont.systemFont(ofSize: 13, weight: .semibold)],
            for: .selected
        )
        UISegmentedControl.appearance().setTitleTextAttributes(
            [.foregroundColor: UIColor(Color.kalMuted),
             .font: UIFont.systemFont(ofSize: 13, weight: .medium)],
            for: .normal
        )
    }

    private func resetSegmentAppearance() {
        UISegmentedControl.appearance().selectedSegmentTintColor = nil
        UISegmentedControl.appearance().setTitleTextAttributes([:], for: .selected)
        UISegmentedControl.appearance().setTitleTextAttributes([:], for: .normal)
    }

    // MARK: - Priority Card

    private var priorityCard: some View {
        section("Priority") {
            HStack(spacing: 0) {
                ForEach(HabitPriority.allCases) { p in
                    priorityOption(p)
                }
            }
        }
    }

    private func priorityOption(_ p: HabitPriority) -> some View {
        let selected = viewModel.draft.priority == p
        let fg = priorityFg(p)
        let dots = priorityDots(p)
        return Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.easeInOut(duration: 0.12)) { viewModel.draft.priority = p }
        } label: {
            VStack(spacing: 6) {
                HStack(spacing: 4) {
                    ForEach(0..<3, id: \.self) { i in
                        Circle()
                            .fill(i < dots ? fg : Color.kalBorder)
                            .frame(width: 8, height: 8)
                    }
                }
                Text(p.displayValue)
                    .font(.system(size: 12, weight: selected ? .semibold : .regular))
                    .tracking(-0.12)
                    .foregroundStyle(selected ? fg : Color.kalTertiary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 3)
                    .background(selected ? fg.opacity(0.1) : Color.clear, in: Capsule())
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
        .buttonStyle(KalPressStyle())
    }

    private func priorityDots(_ p: HabitPriority) -> Int {
        switch p { case .low: return 1; case .medium: return 2; case .high: return 3 }
    }

    // MARK: - Category Card

    private var categoryCard: some View {
        section("Category") {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(HabitCategoryOption.all) { opt in
                        categoryChip(opt)
                    }
                }
                .padding(.vertical, 2)
            }
            .padding(.horizontal, -14)
            .padding(.vertical, -4)
        }
    }

    private func categoryChip(_ opt: HabitCategoryOption) -> some View {
        let selected = viewModel.draft.category.id == opt.id
        let c = Color(hex: opt.color)
        return Button {
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            withAnimation(.easeInOut(duration: 0.12)) { viewModel.draft.category = opt }
        } label: {
            VStack(spacing: 6) {
                Image(systemName: opt.icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(selected ? c : Color.kalTertiary)
                    .frame(width: 44, height: 44)
                    .background(selected ? c.opacity(0.1) : Color.kalInput, in: Circle())
                Text(opt.label)
                    .font(.system(size: 10, weight: selected ? .semibold : .regular))
                    .tracking(0.1)
                    .foregroundStyle(selected ? Color.kalPrimary : Color.kalTertiary)
                    .lineLimit(1)
            }
            .frame(width: 64)
        }
        .buttonStyle(KalPressStyle())
    }

    // MARK: - Schedule Card

    private var scheduleCard: some View {
        section("Schedule") {
            VStack(spacing: 0) {
                // Day grid
                dayGridSection
                    .padding(.bottom, 12)

                schedDivider

                // Duration row
                durationRow
                    .padding(.vertical, 12)

                if !viewModel.draft.isIndefinite && viewModel.draft.mode != .challenge21 {
                    nativeDateRow(
                        label: "Ends on",
                        selection: Binding(
                            get: { viewModel.draft.expiryDate ?? Date() },
                            set: { viewModel.draft.expiryDate = $0 }
                        ),
                        range: Date()...
                    )
                    .padding(.bottom, 12)
                }

                schedDivider

                // Time of day
                preferredTimeRow
                    .padding(.top, 12)
            }
        }
    }

    // Day circles + preset pills
    private var dayGridSection: some View {
        let locked = viewModel.draft.mode == .challenge21
        return VStack(spacing: 14) {
            HStack(spacing: 0) {
                ForEach(HabitWeekday.allCases) { day in
                    let on = locked ? true : viewModel.draft.selectedWeekdays.contains(day)
                    Button {
                        guard !locked else { return }
                        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                        withAnimation(.easeInOut(duration: 0.12)) {
                            viewModel.draft.frequency = .custom
                            if on { viewModel.draft.selectedWeekdays.remove(day) }
                            else  { viewModel.draft.selectedWeekdays.insert(day) }
                        }
                    } label: {
                        Text(String(day.shortLabel.prefix(1)))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(on ? Color.white : Color.kalTertiary)
                            .frame(width: 36, height: 36)
                            .background(on ? Color.kalPrimary : Color.kalInput, in: Circle())
                    }
                    .buttonStyle(KalPressStyle())
                    .disabled(locked)
                    .frame(maxWidth: .infinity)
                }
            }

            if !locked {
                HStack(spacing: 8) {
                    presetPill("Daily") {
                        viewModel.draft.frequency = .daily
                        viewModel.draft.selectedWeekdays = Set(HabitWeekday.allCases)
                    }
                    presetPill("M – F") {
                        viewModel.draft.frequency = .weekdays
                        viewModel.draft.selectedWeekdays = HabitWeekday.weekdayPresetSet
                    }
                    presetPill("Sa – Su") {
                        viewModel.draft.frequency = .weekends
                        viewModel.draft.selectedWeekdays = HabitWeekday.weekendPresetSet
                    }
                    Spacer()
                    Text("\(viewModel.draft.selectedWeekdays.count) / 7")
                        .font(.system(size: 11, weight: .medium))
                        .tracking(-0.1)
                        .foregroundStyle(Color.kalTertiary)
                }
            }
        }
    }

    private func presetPill(_ label: String, action: @escaping () -> Void) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.easeInOut(duration: 0.12)) { action() }
        } label: {
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .tracking(-0.1)
                .foregroundStyle(Color.kalMuted)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.kalInput, in: Capsule())
        }
        .buttonStyle(KalPressStyle())
    }

    // Duration (open-ended toggle)
    private var durationRow: some View {
        Button {
            guard viewModel.draft.mode != .challenge21 else { return }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.easeInOut(duration: 0.15)) {
                viewModel.draft.isIndefinite.toggle()
                if viewModel.draft.isIndefinite {
                    viewModel.draft.expiryDate = nil
                } else if viewModel.draft.expiryDate == nil {
                    viewModel.draft.expiryDate = Calendar.current.date(byAdding: .day, value: 30, to: .now)
                }
            }
        } label: {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(viewModel.draft.isIndefinite ? Color.kalPrimary : Color.kalInput)
                        .frame(width: 30, height: 30)
                    Image(systemName: viewModel.draft.isIndefinite ? "infinity" : "calendar")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(viewModel.draft.isIndefinite ? Color.white : Color.kalTertiary)
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text(viewModel.draft.isIndefinite ? "Open-ended" : "Fixed duration")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.kalPrimary)
                    Text(viewModel.draft.isIndefinite ? "Runs forever" : "Set an end date below")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.kalTertiary)
                }

                Spacer()

                Image(systemName: viewModel.draft.isIndefinite ? "checkmark" : "chevron.down")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(viewModel.draft.isIndefinite ? Color.kalPrimary : Color.kalTertiary)
            }
        }
        .buttonStyle(KalPressStyle())
        .disabled(viewModel.draft.mode == .challenge21)
    }

    private var schedDivider: some View {
        Rectangle()
            .fill(Color.kalBorder)
            .frame(height: 1)
    }

    private var preferredTimeRow: some View {
        HStack(spacing: 0) {
            ForEach(HabitPreferredTime.allCases) { t in
                timeOption(t)
            }
        }
        .background(Color.kalInput, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func timeOption(_ t: HabitPreferredTime) -> some View {
        let selected = viewModel.draft.preferredTime == t
        let icon: String
        let tint: Color
        switch t {
        case .unspecified: icon = "sparkles";        tint = Color.kalMuted
        case .morning:     icon = "sunrise.fill";    tint = Color(hex: "#f59e0b")
        case .afternoon:   icon = "sun.max.fill";    tint = Color(hex: "#f97316")
        case .evening:     icon = "sunset.fill";     tint = Color(hex: "#8b5cf6")
        case .night:       icon = "moon.stars.fill"; tint = Color(hex: "#3b82f6")
        }
        return Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.easeInOut(duration: 0.15)) { viewModel.draft.preferredTime = t }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(selected ? tint : Color.kalTertiary)
                Text(t.label)
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(0.2)
                    .foregroundStyle(selected ? tint : Color.kalTertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(selected ? tint.opacity(0.1) : Color.clear,
                        in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(selected ? tint.opacity(0.35) : Color.clear, lineWidth: 1)
            )
            .animation(.easeInOut(duration: 0.12), value: selected)
        }
        .buttonStyle(KalPressStyle())
    }

    // Removed: frequencyChip (replaced by dayGridSection + presetPill)
    // MARK: - Reusable Section Container

    private func section<C: View>(_ title: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.kalSurface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.kalBorder, lineWidth: 1)
        )
    }

    // MARK: - Reusable Input Field

    private func inputField(
        icon: String,
        placeholder: String,
        text: Binding<String>,
        field: FormField,
        axis: Axis = .horizontal,
        lineLimit: ClosedRange<Int>? = nil,
        capitalization: TextInputAutocapitalization = .sentences,
        next: FormField? = nil
    ) -> some View {
        HStack(alignment: axis == .vertical ? .top : .center, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.kalTertiary)
                .frame(width: 18)
                .padding(.top, axis == .vertical ? 2 : 0)

            if axis == .vertical {
                TextField(placeholder, text: text, axis: .vertical)
                    .font(.system(size: 14))
                    .foregroundStyle(Color.kalPrimary)
                    .lineLimit(lineLimit ?? 1...4)
                    .textInputAutocapitalization(capitalization)
                    .focused($focused, equals: field)
            } else {
                TextField(placeholder, text: text)
                    .font(.system(size: 14))
                    .foregroundStyle(Color.kalPrimary)
                    .textInputAutocapitalization(capitalization)
                    .focused($focused, equals: field)
                    .submitLabel(next != nil ? .next : .done)
                    .onSubmit { focused = next }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.kalInput, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    // MARK: - Reusable Toggle Row

    private func toggleRow(
        icon: String,
        iconBg: Color,
        iconFg: Color,
        label: String,
        binding: Binding<Bool>,
        tint: Color
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(iconFg)
                .frame(width: 28, height: 28)
                .background(iconBg, in: RoundedRectangle(cornerRadius: 7, style: .continuous))

            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.kalPrimary)

            Spacer()

            Toggle("", isOn: binding)
                .labelsHidden()
                .tint(tint)
        }
        .padding(.vertical, 2)
        .animation(.easeInOut(duration: 0.12), value: binding.wrappedValue)
    }

    // MARK: - Reusable DatePicker Row

    private func nativeDateRow(
        label: String,
        selection: Binding<Date>,
        range: PartialRangeFrom<Date>? = nil
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "calendar")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.kalTertiary)
                .frame(width: 18)

            if let range {
                DatePicker(label, selection: selection, in: range, displayedComponents: .date)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.kalPrimary)
            } else {
                DatePicker(label, selection: selection, displayedComponents: .date)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.kalPrimary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }


    // MARK: - Row Divider

    private var rowDivider: some View {
        Rectangle()
            .fill(Color.kalBorder)
            .frame(height: 1)
            .padding(.leading, 38)
    }

    // MARK: - Actions

    private func performSave() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        guard let userId = currentUserId else { activeError = .missingUser; return }
        _Concurrency.Task {
            do {
                _ = try await viewModel.save(userId: userId)
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                dismiss()
            } catch let e as HabitFormError {
                UINotificationFeedbackGenerator().notificationOccurred(.error)
                activeError = e
            } catch {
                UINotificationFeedbackGenerator().notificationOccurred(.error)
                activeError = .network("Something went wrong. Please try again.")
            }
        }
    }

    // MARK: - Computed

    private var defaultTime: Date {
        Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()
    }

    private func priorityFg(_ p: HabitPriority) -> Color {
        switch p {
        case .high:   return Color.kalFail
        case .medium: return Color.orange
        case .low:    return Color.kalToday
        }
    }

    private func priorityIcon(_ p: HabitPriority) -> String {
        switch p {
        case .high:   return "exclamationmark.circle.fill"
        case .medium: return "equal.circle"
        case .low:    return "minus.circle"
        }
    }

    // MARK: - Bindings

    private func binding<T>(_ kp: WritableKeyPath<HabitFormDraft, T>) -> Binding<T> {
        Binding(
            get: { viewModel.draft[keyPath: kp] },
            set: { viewModel.draft[keyPath: kp] = $0 }
        )
    }
}

// MARK: - Press Button Style

private struct KalPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .opacity(configuration.isPressed ? 0.82 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

#Preview {
    AddNewHabitView()
        .environment(\.injected, .previewAuthenticated)
}
