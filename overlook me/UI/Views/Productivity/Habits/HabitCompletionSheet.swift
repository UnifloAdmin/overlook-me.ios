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
    @FocusState private var focusedField: Field?
    
    enum Field: Hashable {
        case reason, notes
    }
    
    enum HabitActionType {
        case checkIn, skip, resisted, failedToResist
        
        var title: String {
            switch self {
            case .checkIn: return "Check In"
            case .skip: return "Skip Habit"
            case .resisted: return "Resisted"
            case .failedToResist: return "Gave In"
            }
        }
        
        var icon: String {
            switch self {
            case .checkIn: return "checkmark.circle.fill"
            case .skip: return "minus.circle.fill"
            case .resisted: return "shield.checkered"
            case .failedToResist: return "exclamationmark.circle.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .checkIn, .resisted: return .green
            case .skip: return .orange
            case .failedToResist: return .red
            }
        }
        
        var isSuccessAction: Bool {
            self == .checkIn || self == .resisted
        }
        
        var isFailureAction: Bool { !isSuccessAction }
    }
    
    enum TriggerCategory: String, CaseIterable, Identifiable {
        case stress, social, boredom, tired, emotional, environmental, physical, time, other
        var id: String { rawValue }
        
        var displayName: String { rawValue.capitalized }
        
        var icon: String {
            switch self {
            case .stress: return "brain.head.profile"
            case .social: return "person.2.fill"
            case .boredom: return "clock.fill"
            case .tired: return "moon.zzz.fill"
            case .emotional: return "heart.fill"
            case .environmental: return "location.fill"
            case .physical: return "figure.walk"
            case .time: return "calendar.badge.clock"
            case .other: return "ellipsis.circle.fill"
            }
        }
    }
    
    enum Sentiment: String, CaseIterable, Identifiable {
        case amazing, great, good, okay, struggling, rough, terrible
        var id: String { rawValue }
        
        var displayName: String { rawValue.capitalized }
        
        var icon: String {
            switch self {
            case .amazing: return "star.fill"
            case .great: return "face.smiling.fill"
            case .good: return "hand.thumbsup.fill"
            case .okay: return "hand.raised.fill"
            case .struggling: return "face.dashed.fill"
            case .rough: return "hand.thumbsdown.fill"
            case .terrible: return "xmark.circle.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .amazing, .great: return .green
            case .good, .okay: return .blue
            case .struggling: return .orange
            case .rough, .terrible: return .red
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            List {
                if actionType.isFailureAction {
                    reasonSection
                    triggerSection
                    sentimentSection
                }
                
                notesSection
            }
            .navigationTitle(actionType.title)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                        onCancel()
                    } label: {
                        ZStack {
                            Circle()
                                .fill(.ultraThinMaterial)
                                .frame(width: 32, height: 32)
                            
                            Image(systemName: "xmark")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Submit") {
                        handleSubmit()
                    }
                    .fontWeight(.semibold)
                }
            }
            .scrollDismissesKeyboard(.interactively)
        }
    }
    
    private var reasonSection: some View {
        Section {
            TextField("What happened?", text: $reasonText, axis: .vertical)
                .lineLimit(3...6)
                .focused($focusedField, equals: .reason)
        } header: {
            Text("Reason")
        } footer: {
            Text("Optional: Share what led to this")
        }
    }
    
    private var triggerSection: some View {
        Section {
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ], spacing: 12) {
                ForEach(TriggerCategory.allCases) { trigger in
                    triggerButton(for: trigger)
                }
            }
            .padding(.vertical, 8)
        } header: {
            Text("What triggered this?")
        } footer: {
            Text("Optional: Select what caused this situation")
        }
    }
    
    private func triggerButton(for trigger: TriggerCategory) -> some View {
        Button {
            withAnimation(.smooth(duration: 0.3)) {
                selectedTrigger = selectedTrigger == trigger ? nil : trigger
            }
        } label: {
            VStack(spacing: 6) {
                Image(systemName: trigger.icon)
                    .font(.title3)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(selectedTrigger == trigger ? Color.accentColor : Color.secondary)
                
                Text(trigger.displayName)
                    .font(.caption2)
                    .foregroundStyle(selectedTrigger == trigger ? Color.primary : Color.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 70)
            .background {
                triggerBackground(for: trigger)
            }
        }
        .buttonStyle(.plain)
    }
    
    private func triggerBackground(for trigger: TriggerCategory) -> some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(selectedTrigger == trigger ? AnyShapeStyle(Material.ultraThinMaterial) : AnyShapeStyle(Color(uiColor: .tertiarySystemFill)))
            .overlay {
                if selectedTrigger == trigger {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.accentColor.opacity(0.12))
                }
            }
    }
    
    private var sentimentSection: some View {
        Section {
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ], spacing: 12) {
                ForEach(Sentiment.allCases) { sentiment in
                    sentimentButton(for: sentiment)
                }
            }
            .padding(.vertical, 8)
        } header: {
            Text("How are you feeling?")
        } footer: {
            Text("Optional: Help us understand your emotional state")
        }
    }
    
    private func sentimentButton(for sentiment: Sentiment) -> some View {
        Button {
            withAnimation(.smooth(duration: 0.3)) {
                selectedSentiment = selectedSentiment == sentiment ? nil : sentiment
            }
        } label: {
            VStack(spacing: 6) {
                Image(systemName: sentiment.icon)
                    .font(.title3)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(sentiment.color)
                
                Text(sentiment.displayName)
                    .font(.caption2)
                    .foregroundStyle(selectedSentiment == sentiment ? Color.primary : Color.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 70)
            .background {
                sentimentBackground(for: sentiment)
            }
        }
        .buttonStyle(.plain)
    }
    
    private func sentimentBackground(for sentiment: Sentiment) -> some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(selectedSentiment == sentiment ? AnyShapeStyle(Material.ultraThinMaterial) : AnyShapeStyle(Color(uiColor: .tertiarySystemFill)))
            .overlay {
                if selectedSentiment == sentiment {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(sentiment.color.opacity(0.12))
                }
            }
    }
    
    private var notesSection: some View {
        Section {
            TextField("Add any additional thoughts...", text: $notes, axis: .vertical)
                .lineLimit(4...8)
                .focused($focusedField, equals: .notes)
        } header: {
            Text("Additional Notes")
        } footer: {
            Text("Optional: Any extra context you'd like to add")
        }
    }
    
    private func handleSubmit() {
        let completionData = HabitCompletionData(
            completed: actionType.isSuccessAction,
            wasSkipped: actionType == .skip,
            notes: notes.isEmpty ? nil : notes,
            reason: createReason()
        )
        
        dismiss()
        onComplete(completionData)
    }
    
    private func createReason() -> CompletionReasonDTO? {
        guard actionType.isFailureAction else { return nil }
        guard !reasonText.isEmpty || selectedTrigger != nil || selectedSentiment != nil else {
            return nil
        }
        
        let reasonType: String = actionType == .skip ? "skip" : "failure"
        
        return CompletionReasonDTO(
            reasonType: reasonType,
            reasonText: reasonText.isEmpty ? "No reason provided" : reasonText,
            triggerCategory: selectedTrigger?.rawValue,
            sentiment: selectedSentiment?.rawValue
        )
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
            id: "1",
            userId: "user1",
            oauthId: nil,
            name: "Morning Meditation",
            description: "15 minutes of mindfulness practice",
            category: nil,
            color: nil,
            icon: nil,
            frequency: nil,
            targetDays: nil,
            isIndefinite: nil,
            remindersEnabled: nil,
            priority: nil,
            isPinned: nil,
            isPositive: true,
            sortOrder: nil,
            tags: nil,
            isActive: nil,
            isArchived: nil,
            currentStreak: nil,
            longestStreak: nil,
            totalCompletions: nil,
            completionRate: nil,
            completionLogs: nil,
            createdAt: nil,
            updatedAt: nil
        ),
        actionType: .skip,
        onComplete: { _ in },
        onCancel: {}
    )
}
