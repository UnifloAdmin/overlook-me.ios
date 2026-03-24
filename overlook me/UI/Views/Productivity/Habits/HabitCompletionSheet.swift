import SwiftUI

struct HabitCompletionSheet: View {
    let habit: DailyHabitDTO
    let actionType: HabitActionType
    let onComplete: (HabitCompletionData) -> Void
    let onCancel: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var notes: String = ""
    @State private var selectedTrigger: TriggerCategory?
    @State private var selectedSentiment: Sentiment?
    @State private var reasonText: String = ""
    @FocusState private var focused: Field?

    enum Field: Hashable { case reason, notes }

    // MARK: - Types

    enum HabitActionType {
        case checkIn, skip, resisted, failedToResist

        var title: String {
            switch self {
            case .checkIn:        return "Check In"
            case .skip:           return "Skip Habit"
            case .resisted:       return "Resisted"
            case .failedToResist: return "Gave In"
            }
        }

        var icon: String {
            switch self {
            case .checkIn:        return "checkmark.circle.fill"
            case .skip:           return "minus.circle.fill"
            case .resisted:       return "shield.checkered"
            case .failedToResist: return "exclamationmark.circle.fill"
            }
        }

        var accent: Color {
            switch self {
            case .checkIn, .resisted: return Color(hex: "#16a34a")
            case .skip:               return Color(hex: "#f97316")
            case .failedToResist:     return Color(hex: "#dc2626")
            }
        }

        var isSuccessAction: Bool { self == .checkIn || self == .resisted }
        var isFailureAction: Bool { !isSuccessAction }
    }

    enum TriggerCategory: String, CaseIterable, Identifiable {
        case stress, social, boredom, tired, emotional, environmental, physical, time, other
        var id: String { rawValue }
        var label: String { rawValue.capitalized }

        var icon: String {
            switch self {
            case .stress:        return "brain.head.profile"
            case .social:        return "person.2.fill"
            case .boredom:       return "clock.fill"
            case .tired:         return "moon.zzz.fill"
            case .emotional:     return "heart.fill"
            case .environmental: return "location.fill"
            case .physical:      return "figure.walk"
            case .time:          return "calendar.badge.clock"
            case .other:         return "ellipsis.circle.fill"
            }
        }
    }

    enum Sentiment: String, CaseIterable, Identifiable {
        case amazing, great, good, okay, struggling, rough, terrible
        var id: String { rawValue }
        var label: String { rawValue.capitalized }

        var icon: String {
            switch self {
            case .amazing:    return "star.fill"
            case .great:      return "face.smiling.fill"
            case .good:       return "hand.thumbsup.fill"
            case .okay:       return "hand.raised.fill"
            case .struggling: return "face.dashed.fill"
            case .rough:      return "hand.thumbsdown.fill"
            case .terrible:   return "xmark.circle.fill"
            }
        }

        var tint: Color {
            switch self {
            case .amazing, .great:  return Color(hex: "#16a34a")
            case .good, .okay:      return Color(hex: "#3b82f6")
            case .struggling:       return Color(hex: "#f97316")
            case .rough, .terrible: return Color(hex: "#dc2626")
            }
        }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 12) {
                    habitBanner
                    if actionType.isFailureAction { failureCard }
                    notesCard
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 60)
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(actionType.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.kalBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss(); onCancel() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(Color.kalTertiary)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { handleSubmit() } label: {
                        Image(systemName: "checkmark")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color.kalPrimary)
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
    }

    // MARK: - Habit Banner

    private var habitBanner: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(actionType.accent.opacity(0.12))
                .frame(width: 38, height: 38)
                .overlay(
                    Image(systemName: actionType.icon)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(actionType.accent)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(habit.name)
                    .font(.system(size: 14, weight: .semibold))
                    .tracking(-0.14)
                    .foregroundStyle(Color.kalPrimary)
                if let desc = habit.description, !desc.isEmpty {
                    Text(desc)
                        .font(.system(size: 11))
                        .foregroundStyle(Color.kalTertiary)
                        .lineLimit(1)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(Color.kalSurface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(actionType.accent.opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: - Failure card (reason + triggers + sentiment in one container)

    private var failureCard: some View {
        VStack(spacing: 0) {
            // Reason field
            VStack(alignment: .leading, spacing: 8) {
                sectionLabel("What happened?")
            TextField("Optional reason…", text: $reasonText, axis: .vertical)
                .lineLimit(2...5)
                .font(.system(size: 13))
                .foregroundStyle(Color.kalPrimary)
                .focused($focused, equals: .reason)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.kalInput,
                            in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .padding(14)

            cardDivider

            // Trigger horizontal scroll
            VStack(alignment: .leading, spacing: 10) {
                sectionLabel("What triggered this?")
                    .padding(.horizontal, 14)
                    .padding(.top, 14)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(TriggerCategory.allCases) { t in
                            triggerChip(t)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.bottom, 14)
                }
            }

            cardDivider

            // Sentiment horizontal scroll
            VStack(alignment: .leading, spacing: 10) {
                sectionLabel("How are you feeling?")
                    .padding(.horizontal, 14)
                    .padding(.top, 14)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Sentiment.allCases) { s in
                            sentimentChip(s)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.bottom, 14)
                }
            }
        }
        .background(Color.kalSurface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.kalBorder, lineWidth: 1)
        )
    }

    // MARK: - Trigger Chip

    private func triggerChip(_ t: TriggerCategory) -> some View {
        let on = selectedTrigger == t
        return Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.easeInOut(duration: 0.12)) { selectedTrigger = on ? nil : t }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: t.icon)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(on ? Color.kalBackground : Color.kalMuted)
                Text(t.label)
                    .font(.system(size: 12, weight: .semibold))
                    .tracking(-0.12)
                    .foregroundStyle(on ? Color.kalBackground : Color.kalMuted)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(on ? Color.kalPrimary : Color.kalInput,
                        in: Capsule())
            .animation(.easeInOut(duration: 0.12), value: on)
        }
        .buttonStyle(KalSheetPress())
    }

    // MARK: - Sentiment Chip

    private func sentimentChip(_ s: Sentiment) -> some View {
        let on = selectedSentiment == s
        return Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.easeInOut(duration: 0.12)) { selectedSentiment = on ? nil : s }
        } label: {
            VStack(spacing: 5) {
                Image(systemName: s.icon)
                    .font(.system(size: 15))
                    .foregroundStyle(on ? s.tint : Color.kalTertiary)
                Text(s.label)
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(0.1)
                    .foregroundStyle(on ? s.tint : Color.kalTertiary)
            }
            .frame(width: 68)
            .padding(.vertical, 10)
            .background(on ? s.tint.opacity(0.08) : Color.kalInput,
                        in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(on ? s.tint.opacity(0.3) : Color.clear, lineWidth: 1)
            )
            .animation(.easeInOut(duration: 0.12), value: on)
        }
        .buttonStyle(KalSheetPress())
    }

    // MARK: - Notes Card

    private var notesCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("Notes")
            TextField("Any extra thoughts… (optional)", text: $notes, axis: .vertical)
                .lineLimit(3...7)
                .font(.system(size: 13))
                .foregroundStyle(Color.kalPrimary)
                .focused($focused, equals: .notes)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.kalInput,
                            in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .padding(14)
        .background(Color.kalSurface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.kalBorder, lineWidth: 1)
        )
    }

    // MARK: - Helpers

    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 9, weight: .semibold))
            .tracking(0.7)
            .foregroundStyle(Color.kalTertiary)
    }

    private var cardDivider: some View {
        Rectangle()
            .fill(Color.kalBorder)
            .frame(height: 1)
    }

    // MARK: - Submit

    private func handleSubmit() {
        let data = HabitCompletionData(
            completed: actionType.isSuccessAction,
            wasSkipped: actionType == .skip,
            notes: notes.isEmpty ? nil : notes,
            reason: buildReason()
        )
        dismiss()
        onComplete(data)
    }

    private func buildReason() -> CompletionReasonDTO? {
        guard actionType.isFailureAction else { return nil }
        guard !reasonText.isEmpty || selectedTrigger != nil || selectedSentiment != nil else { return nil }
        return CompletionReasonDTO(
            reasonType: actionType == .skip ? "skip" : "failure",
            reasonText: reasonText.isEmpty ? "No reason provided" : reasonText,
            triggerCategory: selectedTrigger?.rawValue,
            sentiment: selectedSentiment?.rawValue
        )
    }
}

// MARK: - Button Style

private struct KalSheetPress: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .opacity(configuration.isPressed ? 0.8 : 1)
            .animation(.easeInOut(duration: 0.12), value: configuration.isPressed)
    }
}

// MARK: - Data Model

struct HabitCompletionData {
    let completed: Bool
    let wasSkipped: Bool
    let notes: String?
    let reason: CompletionReasonDTO?
}

// MARK: - Preview

#Preview {
    HabitCompletionSheet(
        habit: DailyHabitDTO(
            id: "1", userId: "user1", oauthId: nil,
            name: "Morning Meditation",
            description: "15 minutes of mindfulness practice",
            category: nil, color: nil, icon: nil,
            frequency: nil, targetDays: nil, isIndefinite: nil,
            remindersEnabled: nil, priority: nil, isPinned: nil,
            isPositive: true, sortOrder: nil, tags: nil,
            isActive: nil, isArchived: nil,
            currentStreak: nil, longestStreak: nil,
            totalCompletions: nil, completionRate: nil,
            completionLogs: nil, createdAt: nil, updatedAt: nil
        ),
        actionType: .failedToResist,
        onComplete: { _ in },
        onCancel: {}
    )
}
