import SwiftUI

struct WeekGlanceTile: View {
    let days: [WeekDay]
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                Label("This Week", systemImage: "calendar")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                
                HStack(spacing: 8) {
                    ForEach(days) { day in
                        VStack(spacing: 6) {
                            Text(day.label)
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(day.isToday ? .white : .secondary)
                            
                            Text("\(day.date)")
                                .font(.callout.weight(.semibold))
                                .foregroundStyle(day.isToday ? .white : .primary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(day.isToday ? Color.indigo : Color.gray.opacity(0.1))
                        )
                        .opacity(day.isPast ? 0.4 : 1)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .glassTile()
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    WeekGlanceTile(
        days: [
            WeekDay(label: "Mon", date: 20, tasks: 3, habits: 2, isToday: false, isPast: true),
            WeekDay(label: "Tue", date: 21, tasks: 2, habits: 4, isToday: false, isPast: true),
            WeekDay(label: "Wed", date: 22, tasks: 4, habits: 1, isToday: true, isPast: false),
            WeekDay(label: "Thu", date: 23, tasks: 1, habits: 3, isToday: false, isPast: false),
            WeekDay(label: "Fri", date: 24, tasks: 5, habits: 2, isToday: false, isPast: false),
            WeekDay(label: "Sat", date: 25, tasks: 0, habits: 1, isToday: false, isPast: false),
            WeekDay(label: "Sun", date: 26, tasks: 2, habits: 0, isToday: false, isPast: false)
        ],
        onTap: {}
    )
    .padding()
}
