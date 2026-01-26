import SwiftUI

struct WaterIntakeTile: View {
    let waterIntake: WaterIntake
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                Label("Water", systemImage: "drop.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                
                HStack(spacing: 0) {
                    ForEach(1...8, id: \.self) { index in
                        Image(systemName: "drop.fill")
                            .font(.title3)
                            .foregroundStyle(index <= waterIntake.current ? Color.blue : Color.gray.opacity(0.2))
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.vertical, 8)
                
                Text("\(waterIntake.current)/\(waterIntake.goal) glasses")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .glassTile()
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    WaterIntakeTile(
        waterIntake: WaterIntake(current: 5, goal: 8),
        onTap: {}
    )
    .padding()
}
