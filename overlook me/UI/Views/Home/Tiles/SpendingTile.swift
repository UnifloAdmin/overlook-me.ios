import SwiftUI

struct SpendingTile: View {
    let weeklySpending: [WeeklySpending]
    let totalFormatted: String
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("Spending", systemImage: "chart.bar.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    Text(totalFormatted)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(.fill.tertiary, in: Capsule())
                }
                
                HStack(alignment: .bottom, spacing: 6) {
                    ForEach(weeklySpending) { day in
                        VStack(spacing: 6) {
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(day.isToday ? Color.indigo : Color.indigo.opacity(0.3))
                                .frame(height: max(4, 80 * (day.percentage / 100)))
                            
                            Text(day.label)
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: 100)
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .glassTile()
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    SpendingTile(
        weeklySpending: [
            WeeklySpending(label: "Mon", amount: 45, percentage: 20, isToday: false, isHighest: false),
            WeeklySpending(label: "Tue", amount: 128, percentage: 55, isToday: false, isHighest: false),
            WeeklySpending(label: "Wed", amount: 67, percentage: 30, isToday: true, isHighest: false),
            WeeklySpending(label: "Thu", amount: 89, percentage: 40, isToday: false, isHighest: false),
            WeeklySpending(label: "Fri", amount: 156, percentage: 70, isToday: false, isHighest: false),
            WeeklySpending(label: "Sat", amount: 234, percentage: 100, isToday: false, isHighest: true),
            WeeklySpending(label: "Sun", amount: 78, percentage: 35, isToday: false, isHighest: false)
        ],
        totalFormatted: "$797",
        onTap: {}
    )
    .padding()
}
