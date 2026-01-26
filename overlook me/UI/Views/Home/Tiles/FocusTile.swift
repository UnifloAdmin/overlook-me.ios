import SwiftUI

struct FocusTile: View {
    let tasks: [FocusTask]
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("Focus", systemImage: "scope")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    HStack(spacing: 4) {
                        Text("All")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Image(systemName: "chevron.right")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                }
                
                if tasks.isEmpty {
                    HStack {
                        Spacer()
                        VStack(spacing: 8) {
                            Image(systemName: "sparkles")
                                .font(.title2)
                                .foregroundStyle(.tertiary)
                            Text("All done!")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 8)
                } else {
                    VStack(spacing: 6) {
                        ForEach(tasks.prefix(3)) { task in
                            HStack(spacing: 10) {
                                Image(systemName: task.status == .completed ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(task.status == .completed ? .primary : .tertiary)
                                
                                Text(task.title)
                                    .font(.subheadline)
                                    .foregroundStyle(task.status == .completed ? .secondary : .primary)
                                    .strikethrough(task.status == .completed)
                                    .lineLimit(1)
                                
                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
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
    FocusTile(
        tasks: [
            FocusTask(id: "1", title: "Review proposal", status: .pending, dueTime: nil),
            FocusTask(id: "2", title: "Team meeting", status: .completed, dueTime: nil)
        ],
        onTap: {}
    )
    .padding()
}
