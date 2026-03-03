import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct AddNewHabitView: View {
    @State private var activeError: HabitFormError?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.injected) private var container: DIContainer
    @StateObject private var viewModel = AddNewHabitViewModel()
    @State private var showAdvancedOptions = false
    @State private var appeared = false

    private var currentUserId: String? {
        container.appState.state.auth.user?.id
    }

    private var saveDisabled: Bool {
        viewModel.draft.trimmedName.isEmpty || viewModel.isSaving
    }

    private var accent: Color { viewModel.draft.mode.accentColor }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                Color(.systemGroupedBackground).ignoresSafeArea()
                headerGradient

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 16) {
                        modeSelector.stagger(0, appeared: appeared)
                        challengeBanner.stagger(1, appeared: appeared)
                        previewCard.stagger(2, appeared: appeared)
                        basicsCard.stagger(3, appeared: appeared)
                        priorityCard.stagger(4, appeared: appeared)
                        appearanceCard.stagger(5, appeared: appeared)
                        categoryCard.stagger(6, appeared: appeared)

                        if showAdvancedOptions {
                            frequencyCard.sectionTransition
                            goalCard.sectionTransition
                            behaviourCard.sectionTransition
                            scheduleCard.sectionTransition
                            tagsCard.sectionTransition
                            motivationCard.sectionTransition
                        }

                        advancedToggle
                        Spacer(minLength: 4)
                        saveButton
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 100)
                    .padding(.bottom, 30)
                }
            }
            .ignoresSafeArea(edges: .top)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.9))
                            .frame(width: 30, height: 30)
                            .background(.white.opacity(0.15), in: Circle())
                    }
                    .disabled(viewModel.isSaving)
                }
                ToolbarItem(placement: .principal) {
                    Text(viewModel.draft.mode == .challenge21 ? "21-Day Challenge" : "New Habit")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
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
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) { appeared = true }
        }
    }

    // MARK: - Header

    private var headerGradient: some View {
        let isChallenge = viewModel.draft.mode == .challenge21
        return VStack(spacing: 0) {
            LinearGradient(
                colors: isChallenge
                    ? [Color.orange.opacity(0.9), Color.red.opacity(0.6), Color.orange.opacity(0.3)]
                    : [Color.blue.opacity(0.85), Color.indigo.opacity(0.55), Color.cyan.opacity(0.25)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .overlay(
                LinearGradient(colors: [.clear, Color(.systemGroupedBackground)], startPoint: .center, endPoint: .bottom)
            )
            .frame(height: 240)
            Spacer()
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .animation(.easeInOut(duration: 0.5), value: isChallenge)
    }

    // MARK: - Mode Selector

    private var modeSelector: some View {
        HStack(spacing: 10) {
            ForEach(HabitMode.allCases) { mode in
                modeOption(mode)
            }
        }
    }

    private func modeOption(_ mode: HabitMode) -> some View {
        let selected = viewModel.draft.mode == mode
        return Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.easeInOut(duration: 0.3)) {
                viewModel.draft.applyMode(mode)
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: mode.icon)
                    .font(.system(size: 20))
                    .foregroundStyle(selected ? .white : mode.accentColor)
                    .frame(width: 36, height: 36)
                    .background(
                        Circle().fill(selected ? mode.accentColor : mode.accentColor.opacity(0.1))
                    )

                VStack(alignment: .leading, spacing: 1) {
                    Text(mode.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(selected ? .primary : Color(.secondaryLabel))
                    Text(mode == .challenge21 ? "21 days, daily" : "Open-ended")
                        .font(.system(size: 10))
                        .foregroundStyle(Color(.tertiaryLabel))
                }
                Spacer(minLength: 0)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(cardFill)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(selected ? mode.accentColor.opacity(0.5) : borderColor, lineWidth: selected ? 1.5 : 0.5)
            )
        }
        .buttonStyle(PressButtonStyle())
    }

    // MARK: - Challenge Banner

    @ViewBuilder
    private var challengeBanner: some View {
        if viewModel.draft.mode == .challenge21 {
            HStack(spacing: 12) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(.orange)
                    .symbolEffect(.variableColor.iterative.reversing, options: .repeating.speed(0.5))

                VStack(alignment: .leading, spacing: 2) {
                    Text("21-Day Challenge")
                        .font(.system(size: 14, weight: .semibold))
                    if let expiry = viewModel.draft.expiryDate {
                        Text("Ends \(expiry, style: .date)")
                            .font(.system(size: 11))
                            .foregroundStyle(Color(.secondaryLabel))
                    }
                }

                Spacer()

                VStack(spacing: 0) {
                    Text("21")
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundStyle(.orange)
                    Text("days")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(Color(.tertiaryLabel))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(cardFill)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.orange.opacity(0.2), lineWidth: 0.5)
            )
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }

    // MARK: - Preview

    private var previewCard: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(viewModel.draft.color.color.opacity(0.1))
                    .frame(width: 48, height: 48)
                Image(systemName: viewModel.draft.icon.systemImage)
                    .font(.system(size: 20))
                    .foregroundStyle(viewModel.draft.color.color)
                    .contentTransition(.symbolEffect(.replace))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.draft.trimmedName.isEmpty ? "Habit Name" : viewModel.draft.trimmedName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(viewModel.draft.trimmedName.isEmpty ? Color(.quaternaryLabel) : .primary)
                    .lineLimit(1)

                Text(viewModel.draft.trimmedDescription.isEmpty ? "Add a description" : viewModel.draft.trimmedDescription)
                    .font(.system(size: 12))
                    .foregroundStyle(Color(.tertiaryLabel))
                    .lineLimit(1)
            }

            Spacer()

            Text(viewModel.draft.priority.displayValue)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(priorityColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(priorityColor.opacity(0.1), in: Capsule())
        }
        .padding(14)
        .background(cardFill)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(borderColor, lineWidth: 0.5)
        )
        .animation(.easeInOut(duration: 0.2), value: viewModel.draft.icon.materialName)
        .animation(.easeInOut(duration: 0.2), value: viewModel.draft.color.hex)
        .animation(.easeInOut(duration: 0.2), value: viewModel.draft.priority)
    }

    private var priorityColor: Color {
        switch viewModel.draft.priority {
        case .high: return .red
        case .medium: return .orange
        case .low: return .blue
        }
    }

    // MARK: - Basics

    private var basicsCard: some View {
        card("Basics") {
            VStack(spacing: 10) {
                inputRow(icon: "pencil", placeholder: "What habit will you build?", text: binding(\.name), capitalization: .words)
                inputRow(icon: "text.alignleft", placeholder: "Why does this matter?", text: binding(\.description), axis: .vertical, lineLimit: 2...4)
            }
        }
    }

    // MARK: - Priority

    private var priorityCard: some View {
        card("Priority") {
            HStack(spacing: 8) {
                ForEach(HabitPriority.allCases) { p in
                    let selected = viewModel.draft.priority == p
                    let pColor = priorityColorFor(p)
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        withAnimation(.easeInOut(duration: 0.2)) { viewModel.draft.priority = p }
                    } label: {
                        VStack(spacing: 5) {
                            Image(systemName: priorityIcon(p))
                                .font(.system(size: 16, weight: .medium))
                            Text(p.displayValue)
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .foregroundStyle(selected ? pColor : Color(.tertiaryLabel))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(selected ? pColor.opacity(0.08) : Color.clear, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(selected ? pColor.opacity(0.35) : Color(.separator).opacity(0.15), lineWidth: selected ? 1.5 : 0.5)
                        )
                    }
                    .buttonStyle(PressButtonStyle())
                }
            }
        }
    }

    private func priorityIcon(_ p: HabitPriority) -> String {
        switch p {
        case .low: return "minus.circle"
        case .medium: return "equal.circle"
        case .high: return "exclamationmark.circle.fill"
        }
    }

    private func priorityColorFor(_ p: HabitPriority) -> Color {
        switch p {
        case .low: return .blue
        case .medium: return .orange
        case .high: return .red
        }
    }

    // MARK: - Appearance

    private var appearanceCard: some View {
        card("Appearance") {
            VStack(alignment: .leading, spacing: 14) {
                sectionLabel("Icon")
                iconGrid
                sectionLabel("Color")
                colorRow
            }
        }
    }

    private var iconGrid: some View {
        let cols = Array(repeating: GridItem(.flexible(), spacing: 6), count: 6)
        return LazyVGrid(columns: cols, spacing: 6) {
            ForEach(HabitIconOption.all) { opt in
                let sel = viewModel.draft.icon.materialName == opt.materialName
                Button {
                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                    withAnimation(.easeInOut(duration: 0.15)) { viewModel.draft.icon = opt }
                } label: {
                    Image(systemName: opt.systemImage)
                        .font(.system(size: 16))
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        .foregroundStyle(sel ? viewModel.draft.color.color : Color(.tertiaryLabel))
                        .background(sel ? viewModel.draft.color.color.opacity(0.1) : Color(.systemGray6).opacity(0.6), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(sel ? viewModel.draft.color.color.opacity(0.4) : .clear, lineWidth: 1.5)
                        )
                }
                .buttonStyle(PressButtonStyle())
            }
        }
    }

    private var colorRow: some View {
        HStack(spacing: 0) {
            ForEach(HabitColorOption.all) { opt in
                let sel = viewModel.draft.color.hex == opt.hex
                Button {
                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                    withAnimation(.easeInOut(duration: 0.15)) { viewModel.draft.color = opt }
                } label: {
                    ZStack {
                        Circle()
                            .fill(opt.color)
                            .frame(width: sel ? 28 : 24, height: sel ? 28 : 24)
                        if sel {
                            Circle()
                                .strokeBorder(.white, lineWidth: 2)
                                .frame(width: 28, height: 28)
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .black))
                                .foregroundStyle(.white)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
                    .animation(.easeInOut(duration: 0.15), value: sel)
                }
                .buttonStyle(PressButtonStyle())
            }
        }
    }

    // MARK: - Category

    private var categoryCard: some View {
        card("Category") {
            let cols = Array(repeating: GridItem(.flexible(), spacing: 8), count: 4)
            LazyVGrid(columns: cols, spacing: 8) {
                ForEach(HabitCategoryOption.all) { opt in
                    let sel = viewModel.draft.category.id == opt.id
                    let c = Color(hex: opt.color)
                    Button {
                        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                        withAnimation(.easeInOut(duration: 0.2)) { viewModel.draft.category = opt }
                    } label: {
                        VStack(spacing: 5) {
                            Image(systemName: opt.icon)
                                .font(.system(size: 15))
                            Text(opt.label)
                                .font(.system(size: 9, weight: .medium))
                                .lineLimit(1)
                        }
                        .foregroundStyle(sel ? c : Color(.tertiaryLabel))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(sel ? c.opacity(0.08) : Color.clear, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(sel ? c.opacity(0.35) : Color(.separator).opacity(0.1), lineWidth: sel ? 1.5 : 0.5)
                        )
                    }
                    .buttonStyle(PressButtonStyle())
                }
            }
        }
    }

    // MARK: - Frequency

    private var frequencyCard: some View {
        card("Frequency") {
            VStack(spacing: 12) {
                HStack(spacing: 6) {
                    ForEach(HabitFrequency.allCases) { opt in
                        let sel = viewModel.draft.frequency == opt
                        let locked = viewModel.draft.mode == .challenge21 && opt != .daily
                        Button {
                            guard !locked else { return }
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            withAnimation(.easeInOut(duration: 0.2)) {
                                viewModel.draft.frequency = opt
                                switch opt {
                                case .weekdays: viewModel.draft.selectedWeekdays = HabitWeekday.weekdayPresetSet
                                case .weekends: viewModel.draft.selectedWeekdays = HabitWeekday.weekendPresetSet
                                case .daily: viewModel.draft.selectedWeekdays.removeAll()
                                case .custom:
                                    if viewModel.draft.selectedWeekdays.isEmpty {
                                        viewModel.draft.selectedWeekdays = HabitWeekday.weekdayPresetSet
                                    }
                                }
                            }
                        } label: {
                            Text(opt.label)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(locked ? Color(.quaternaryLabel) : (sel ? accent : Color(.secondaryLabel)))
                                .padding(.vertical, 8)
                                .frame(maxWidth: .infinity)
                                .background(sel ? accent.opacity(0.1) : Color.clear, in: Capsule())
                                .overlay(Capsule().strokeBorder(sel ? accent.opacity(0.35) : Color(.separator).opacity(0.12), lineWidth: sel ? 1.5 : 0.5))
                        }
                        .buttonStyle(PressButtonStyle())
                        .disabled(locked)
                    }
                }

                if viewModel.draft.frequency == .custom {
                    WeekdayChipGrid(accent: accent, selected: viewModel.draft.selectedWeekdays) { day in
                        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                        withAnimation(.easeInOut(duration: 0.15)) {
                            if viewModel.draft.selectedWeekdays.contains(day) {
                                viewModel.draft.selectedWeekdays.remove(day)
                            } else {
                                viewModel.draft.selectedWeekdays.insert(day)
                            }
                        }
                    }
                    .transition(.opacity)
                }
            }
        }
    }

    // MARK: - Goal

    private var goalCard: some View {
        card("Goal & Measurement") {
            VStack(spacing: 12) {
                Picker("Goal Type", selection: binding(\.goalType)) {
                    ForEach(HabitGoalType.allCases) { t in Text(t.label).tag(t) }
                }
                .pickerStyle(.segmented)

                inputRow(icon: "star", placeholder: "What does success look like?", text: binding(\.dailyGoal), axis: .vertical, lineLimit: 1...2)

                if viewModel.draft.goalType.supportsTargetValue {
                    Stepper(value: binding(\.targetValue), in: 1...240, step: goalStepValue) {
                        Text(goalTargetDescription).font(.system(size: 13))
                    }
                }

                if viewModel.draft.goalType.supportsUnit {
                    inputRow(icon: "ruler", placeholder: "Unit (e.g. km, minutes, reps)", text: binding(\.unit))
                }
            }
        }
    }

    // MARK: - Behaviour

    private var behaviourCard: some View {
        card("Behaviour & Reminders") {
            VStack(spacing: 2) {
                toggleItem(icon: "arrow.up.right", label: viewModel.draft.isPositive ? "Build habit" : "Break habit", on: binding(\.isPositive), tint: viewModel.draft.isPositive ? .green : .red)
                toggleItem(icon: "pin.fill", label: "Pinned", on: binding(\.isPinned), tint: .purple)
                toggleItem(icon: "bell.fill", label: "Reminders", on: binding(\.remindersEnabled), tint: .blue)

                if viewModel.draft.mode != .challenge21 {
                    toggleItem(icon: "infinity", label: "Indefinite", on: binding(\.isIndefinite), tint: .teal)
                        .onChange(of: viewModel.draft.isIndefinite) { val in
                            if val { viewModel.draft.expiryDate = nil }
                            else if viewModel.draft.expiryDate == nil {
                                viewModel.draft.expiryDate = Calendar.current.date(byAdding: .day, value: 1, to: .now) ?? .now
                            }
                        }

                    if !viewModel.draft.isIndefinite {
                        DatePicker("Expiry", selection: Binding(
                            get: { viewModel.draft.expiryDate ?? Date() },
                            set: { viewModel.draft.expiryDate = $0 }
                        ), in: Date()..., displayedComponents: .date)
                        .font(.system(size: 13))
                        .padding(.leading, 36)
                        .transition(.opacity)
                    }
                }
            }
        }
    }

    private func toggleItem(icon: String, label: String, on: Binding<Bool>, tint: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(tint)
                .frame(width: 26, height: 26)
                .background(tint.opacity(on.wrappedValue ? 0.12 : 0.05), in: RoundedRectangle(cornerRadius: 7, style: .continuous))

            Toggle(label, isOn: on)
                .font(.system(size: 13))
                .tint(tint)
        }
        .padding(.vertical, 2)
        .animation(.easeInOut(duration: 0.15), value: on.wrappedValue)
    }

    // MARK: - Schedule

    private var scheduleCard: some View {
        card("Schedule & Timing") {
            VStack(spacing: 12) {
                Picker("Time", selection: binding(\.preferredTime)) {
                    ForEach(HabitPreferredTime.allCases) { o in Text(o.label).tag(o) }
                }
                .pickerStyle(.segmented)

                if viewModel.draft.mode != .challenge21 {
                    Toggle("Start date", isOn: startDateBinding).font(.system(size: 13))
                    if viewModel.draft.startDate != nil {
                        DatePicker("Start", selection: dateBinding(\.startDate), in: Date()..., displayedComponents: .date).font(.system(size: 13)).transition(.opacity)
                    }
                    Toggle("End date", isOn: endDateBinding).font(.system(size: 13))
                    if viewModel.draft.endDate != nil {
                        DatePicker("End", selection: dateBinding(\.endDate, fallback: defaultEndDate), in: (viewModel.draft.startDate ?? Date())..., displayedComponents: .date).font(.system(size: 13)).transition(.opacity)
                    }
                }

                Toggle("Reminder time", isOn: reminderBinding).font(.system(size: 13))
                if viewModel.draft.scheduledTime != nil {
                    DatePicker("Reminder", selection: dateBinding(\.scheduledTime, fallback: defaultTime), displayedComponents: .hourAndMinute).font(.system(size: 13)).transition(.opacity)
                }
            }
        }
    }

    // MARK: - Tags

    private var tagsCard: some View {
        card("Tags") {
            VStack(alignment: .leading, spacing: 6) {
                inputRow(icon: "tag", placeholder: "e.g. health, morning, focus", text: binding(\.tags))
                Text("Comma-separated. Used for filtering and analytics.")
                    .font(.system(size: 10))
                    .foregroundStyle(Color(.quaternaryLabel))
                    .padding(.leading, 36)
            }
        }
    }

    // MARK: - Motivation

    private var motivationCard: some View {
        card("Motivation & Rewards") {
            VStack(spacing: 10) {
                inputRow(icon: "bolt.heart.fill", placeholder: "What motivates you?", text: binding(\.motivation), iconColor: .pink)
                inputRow(icon: "gift.fill", placeholder: "How will you reward yourself?", text: binding(\.reward), iconColor: .orange)
            }
        }
    }

    // MARK: - Advanced Toggle

    private var advancedToggle: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.easeInOut(duration: 0.35)) { showAdvancedOptions.toggle() }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: showAdvancedOptions ? "minus.circle" : "plus.circle")
                    .font(.system(size: 15, weight: .medium))
                    .contentTransition(.symbolEffect(.replace))
                Text(showAdvancedOptions ? "Less options" : "More options")
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundStyle(Color(.secondaryLabel))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
        .buttonStyle(PressButtonStyle())
    }

    // MARK: - Save

    private var saveButton: some View {
        let isChallenge = viewModel.draft.mode == .challenge21
        return Button(action: performSave) {
            HStack(spacing: 8) {
                if viewModel.isSaving {
                    ProgressView().tint(.white)
                } else {
                    Image(systemName: isChallenge ? "flame.fill" : "checkmark")
                        .font(.system(size: 15, weight: .bold))
                    Text(isChallenge ? "Start Challenge" : "Create Habit")
                        .font(.system(size: 16, weight: .semibold))
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                LinearGradient(
                    colors: saveDisabled
                        ? [Color.gray.opacity(0.3), Color.gray.opacity(0.2)]
                        : (isChallenge ? [.orange, .red.opacity(0.8)] : [.blue, .indigo.opacity(0.7)]),
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
        }
        .buttonStyle(PressButtonStyle())
        .disabled(saveDisabled)
        .padding(.bottom, 8)
    }

    // MARK: - Reusable Components

    private func card<C: View>(_ title: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color(.secondaryLabel))
                .padding(.leading, 2)

            VStack(alignment: .leading, spacing: 12) {
                content()
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(cardFill)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: 0.5)
            )
        }
    }

    private func inputRow(
        icon: String,
        placeholder: String,
        text: Binding<String>,
        axis: Axis = .horizontal,
        lineLimit: ClosedRange<Int>? = nil,
        capitalization: TextInputAutocapitalization = .sentences,
        iconColor: Color? = nil
    ) -> some View {
        HStack(alignment: axis == .vertical ? .top : .center, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(iconColor ?? accent)
                .frame(width: 22)
                .padding(.top, axis == .vertical ? 2 : 0)

            if axis == .vertical {
                TextField(placeholder, text: text, axis: .vertical)
                    .font(.system(size: 14))
                    .lineLimit(lineLimit ?? 1...4)
                    .textInputAutocapitalization(capitalization)
            } else {
                TextField(placeholder, text: text)
                    .font(.system(size: 14))
                    .textInputAutocapitalization(capitalization)
            }
        }
        .padding(12)
        .background(Color(.systemGray6).opacity(0.6), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(Color(.tertiaryLabel))
    }

    // MARK: - Style Tokens

    private var cardFill: Color {
        colorScheme == .dark ? Color(uiColor: .secondarySystemBackground) : .white
    }

    private var borderColor: Color {
        Color(.separator).opacity(colorScheme == .dark ? 0.15 : 0.12)
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

    private var goalTargetDescription: String {
        let v = Int(viewModel.draft.targetValue)
        switch viewModel.draft.goalType {
        case .duration: return "Target \(v) min per session"
        case .numeric: return "Target \(v) per \(viewModel.draft.frequency == .daily ? "day" : "week")"
        case .text, .boolean: return "Target \(v) completions"
        }
    }

    private var goalStepValue: Double { viewModel.draft.goalType == .duration ? 5.0 : 1.0 }

    // MARK: - Bindings

    private var startDateBinding: Binding<Bool> {
        Binding(get: { viewModel.draft.startDate != nil }, set: { viewModel.draft.startDate = $0 ? (viewModel.draft.startDate ?? Date()) : nil })
    }

    private var endDateBinding: Binding<Bool> {
        Binding(get: { viewModel.draft.endDate != nil }, set: {
            viewModel.draft.endDate = $0 ? (viewModel.draft.endDate ?? (viewModel.draft.startDate?.addingTimeInterval(86400) ?? nextDay)) : nil
        })
    }

    private var reminderBinding: Binding<Bool> {
        Binding(get: { viewModel.draft.scheduledTime != nil }, set: { viewModel.draft.scheduledTime = $0 ? (viewModel.draft.scheduledTime ?? defaultTime) : nil })
    }

    private var defaultTime: Date { Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date() }
    private var defaultEndDate: Date { viewModel.draft.endDate ?? (viewModel.draft.startDate?.addingTimeInterval(86400) ?? nextDay) }
    private var nextDay: Date { Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date().addingTimeInterval(86400) }

    private func dateBinding(_ kp: WritableKeyPath<HabitFormDraft, Date?>, fallback: Date = Date()) -> Binding<Date> {
        Binding(get: { viewModel.draft[keyPath: kp] ?? fallback }, set: { viewModel.draft[keyPath: kp] = $0 })
    }

    private func binding<T>(_ kp: WritableKeyPath<HabitFormDraft, T>) -> Binding<T> {
        Binding(get: { viewModel.draft[keyPath: kp] }, set: { viewModel.draft[keyPath: kp] = $0 })
    }
}

// MARK: - Button Style

private struct PressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.7 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

// MARK: - View Modifiers

private extension View {
    func stagger(_ index: Int, appeared: Bool) -> some View {
        opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 20)
            .animation(.easeOut(duration: 0.4).delay(Double(index) * 0.04), value: appeared)
    }

    var sectionTransition: some View {
        transition(.opacity.combined(with: .move(edge: .top)))
    }
}

// MARK: - Weekday Chips

private struct WeekdayChipGrid: View {
    let accent: Color
    let selected: Set<HabitWeekday>
    let toggle: (HabitWeekday) -> Void

    private let cols = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    var body: some View {
        LazyVGrid(columns: cols, spacing: 6) {
            ForEach(HabitWeekday.allCases) { day in
                let on = selected.contains(day)
                Button { toggle(day) } label: {
                    Text(String(day.shortLabel.prefix(2)))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(on ? accent : Color(.tertiaryLabel))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(on ? accent.opacity(0.1) : Color(.systemGray6).opacity(0.5), in: Circle())
                        .overlay(Circle().strokeBorder(on ? accent.opacity(0.35) : Color(.separator).opacity(0.1), lineWidth: on ? 1.5 : 0.5))
                }
                .buttonStyle(PressButtonStyle())
            }
        }
    }
}

#Preview {
    AddNewHabitView()
        .environment(\.injected, .previewAuthenticated)
}
