import SwiftUI

struct ScheduleTile: View {
    let schedule: [ScheduleItem]
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                Label("Schedule", systemImage: "calendar.day.timeline.left")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                
                if schedule.isEmpty {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "calendar.badge.plus")
                            .font(.title2)
                            .foregroundStyle(.tertiary)
                        Text("No events")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    Spacer()
                } else {
                    VStack(spacing: 6) {
                        ForEach(schedule.prefix(3)) { item in
                            HStack(spacing: 10) {
                                Text(item.time)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.indigo)
                                    .frame(width: 65, alignment: .leading)
                                
                                Text(item.title)
                                    .font(.subheadline)
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
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .glassTile()
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ScheduleTile(
        schedule: [
            ScheduleItem(time: "9:00 AM", title: "Standup", type: .meeting),
            ScheduleItem(time: "12:30 PM", title: "Lunch", type: .event)
        ],
        onTap: {}
    )
    .frame(height: 160)
    .padding()
}
