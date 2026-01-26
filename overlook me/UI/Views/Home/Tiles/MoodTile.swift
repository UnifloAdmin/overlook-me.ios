import SwiftUI

struct MoodTile: View {
    let mood: MoodData
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                Label("Mood", systemImage: "face.smiling")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Spacer()
                
                VStack(spacing: 8) {
                    Image(systemName: mood.icon)
                        .font(.system(size: 36))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.orange)
                    
                    Text(mood.current)
                        .font(.headline)
                    
                    Text("\(mood.streak) day streak")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .glassTile()
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    MoodTile(
        mood: MoodData(current: "Good", icon: "face.smiling", streak: 3),
        onTap: {}
    )
    .frame(width: 160, height: 160)
    .padding()
}
