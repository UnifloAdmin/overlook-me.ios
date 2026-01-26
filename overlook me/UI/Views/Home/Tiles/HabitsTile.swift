import SwiftUI

struct HabitsTile: View {
    let stats: HabitStats
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                Label("Habits", systemImage: "flame.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                if stats.active > 0 {
                    Spacer()
                    Gauge(value: stats.completionRate, in: 0...100) {
                        Text("Progress")
                    } currentValueLabel: {
                        Text("\(Int(stats.completionRate))%")
                            .font(.headline.bold())
                    }
                    .gaugeStyle(.accessoryCircularCapacity)
                    .tint(.orange)
                    .scaleEffect(1.4)
                    Spacer()
                } else {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "leaf")
                            .font(.title2)
                            .foregroundStyle(.tertiary)
                        Text("No habits")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .glassTile()
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    HabitsTile(
        stats: HabitStats(active: 6, completed: 4, streaks: 12, completionRate: 75),
        onTap: {}
    )
    .frame(width: 160, height: 160)
    .padding()
}
