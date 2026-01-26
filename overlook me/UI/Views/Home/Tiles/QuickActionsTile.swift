import SwiftUI

struct QuickActionsTile: View {
    let onAddTask: () -> Void
    let onHabits: () -> Void
    let onCalendar: () -> Void
    let onBudgets: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Quick Actions", systemImage: "bolt.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            
            HStack(spacing: 10) {
                QuickActionButton(icon: "plus", label: "Task", action: onAddTask)
                QuickActionButton(icon: "flame.fill", label: "Habits", action: onHabits)
                QuickActionButton(icon: "calendar", label: "Plan", action: onCalendar)
                QuickActionButton(icon: "dollarsign.circle.fill", label: "Budget", action: onBudgets)
            }
        }
        .glassTile()
    }
}

private struct QuickActionButton: View {
    let icon: String
    let label: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(.secondary)
                
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    QuickActionsTile(
        onAddTask: {},
        onHabits: {},
        onCalendar: {},
        onBudgets: {}
    )
    .padding()
}
