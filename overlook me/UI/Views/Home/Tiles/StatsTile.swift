import SwiftUI

struct StatTile: View {
    let icon: String
    let iconColor: Color
    let value: String
    let label: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(iconColor)
                    .frame(width: 40, height: 40)
                    .background(iconColor.opacity(0.15), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(value)
                        .font(.headline)
                    
                    Text(label)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer(minLength: 0)
            }
            .glassTile()
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    StatTile(
        icon: "checkmark.circle.fill",
        iconColor: .indigo,
        value: "5/11",
        label: "Tasks",
        action: {}
    )
    .padding()
}
