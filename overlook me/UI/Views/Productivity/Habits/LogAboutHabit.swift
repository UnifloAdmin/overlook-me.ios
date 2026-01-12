import SwiftUI

struct LogAboutHabit: View {
    enum Sentiment: String, CaseIterable, Identifiable {
        case energized
        case balanced
        case drained
        
        var id: String { rawValue }
        var icon: String {
            switch self {
            case .energized: return "sun.max.fill"
            case .balanced: return "waveform.path.ecg"
            case .drained: return "moon.zzz.fill"
            }
        }
        
        var label: String {
            rawValue.capitalized
        }
    }
    
    let habit: DailyHabitDTO
    @Binding private var reflection: String
    private let maxCharacters: Int
    private let onSave: ((String, Sentiment) -> Void)?
    
    @State private var selectedSentiment: Sentiment = .balanced
    @FocusState private var isEditorFocused: Bool
    
    init(
        habit: DailyHabitDTO,
        reflection: Binding<String>,
        maxCharacters: Int = 280,
        onSave: ((String, Sentiment) -> Void)? = nil
    ) {
        self.habit = habit
        self._reflection = reflection
        self.maxCharacters = max(1, maxCharacters)
        self.onSave = onSave
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            habitHeader
            Divider()
            sentimentPicker
            noteEditor
            footerActions
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
        .accessibilityElement(children: .contain)
    }
    
    private var habitHeader: some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(habitAccentColor.opacity(0.15))
                .frame(width: 44, height: 44)
                .overlay {
                    if let icon = habit.icon, !icon.isEmpty {
                        Image(systemName: icon)
                            .foregroundColor(habitAccentColor)
                    } else {
                        Text(String(habit.name.prefix(1)))
                            .font(.headline.weight(.semibold))
                            .foregroundColor(habitAccentColor)
                    }
                }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(habit.name)
                    .font(.headline)
                if let description = habit.description, !description.isEmpty {
                    Text(description)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            Spacer()
        }
    }
    
    private var sentimentPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("How did it feel?")
                .font(.subheadline.weight(.semibold))
            Picker("Sentiment", selection: $selectedSentiment) {
                ForEach(Sentiment.allCases) { sentiment in
                    Label(sentiment.label, systemImage: sentiment.icon)
                        .tag(sentiment)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityLabel("Select how the habit felt")
        }
    }
    
    private var noteEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Capture a quick note")
                .font(.subheadline.weight(.semibold))
            
            ZStack(alignment: .topLeading) {
                if reflection.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("Wins, struggles, triggers, or anything worth remembering…")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 16)
                }
                
                TextEditor(text: $reflection)
                    .focused($isEditorFocused)
                    .padding(12)
                    .frame(minHeight: 140)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color(uiColor: .systemBackground))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                    )
                    .onChange(of: reflection) { newValue in
                        guard newValue.count > maxCharacters else { return }
                        reflection = String(newValue.prefix(maxCharacters))
                    }
            }
        }
    }
    
    private var footerActions: some View {
        HStack(spacing: 12) {
            Text("\(reflection.count)/\(maxCharacters)")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Spacer()
            
            Button {
                let trimmed = reflection.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return }
                onSave?(trimmed, selectedSentiment)
                reflection = ""
                isEditorFocused = false
            } label: {
                Label("Log reflection", systemImage: "square.and.pencil")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(reflection.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .accessibilityHint("Saves this reflection to the parent view")
        }
    }
    
    private var habitAccentColor: Color {
        guard let hex = habit.color, !hex.isEmpty else { return .accentColor }
        return Color(hex: hex)
    }
}

#Preview {
    LogAboutHabitPreview()
        .padding()
        .background(Color(uiColor: .systemGroupedBackground))
}

private struct LogAboutHabitPreview: View {
    @State private var text = "Felt a bit low energy but still showed up."
    
    var body: some View {
        LogAboutHabit(
            habit: .preview,
            reflection: $text
        )
        .padding()
    }
}

private extension DailyHabitDTO {
    static var preview: DailyHabitDTO {
        DailyHabitDTO(
            id: "habit-001",
            userId: "user-123",
            oauthId: nil,
            name: "Read 10 pages",
            description: "Slow down in the evenings and read before bed.",
            category: "mindfulness",
            color: "#7C4DFF",
            icon: "book.fill",
            frequency: "daily",
            targetDays: ["mon", "tue", "wed", "thu", "fri"],
            isIndefinite: true,
            remindersEnabled: true,
            priority: "high",
            isPinned: true,
            isPositive: true,
            sortOrder: 1,
            tags: "focus,calm",
            isActive: true,
            isArchived: false,
            currentStreak: 5,
            longestStreak: 14,
            totalCompletions: 120,
            completionRate: 0.82,
            completionLogs: [],
            createdAt: nil,
            updatedAt: nil
        )
    }
}
