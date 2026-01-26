import SwiftUI

// MARK: - Sleep Tile

struct SleepTile: View {
    let data: SleepData
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                Label("Sleep", systemImage: "moon.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Spacer()
                
                VStack(spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text(String(format: "%.1f", data.hours))
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                        Text("hrs")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    
                    Text("Quality \(data.quality)%")
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

// MARK: - Heart Tile

struct HeartTile: View {
    let data: HeartData
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                Label("Heart", systemImage: "heart.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Spacer()
                
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Image(systemName: "heart.fill")
                        .foregroundStyle(.pink)
                        .symbolEffect(.pulse)
                    
                    Text("\(data.current)")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                    
                    Text("bpm")
                        .font(.subheadline)
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

// MARK: - Activity Tile

struct ActivityTile: View {
    let data: ExerciseData
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                Label("Activity", systemImage: "figure.run")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Spacer()
                
                HStack(spacing: 16) {
                    VStack(spacing: 2) {
                        Text("\(data.calories)")
                            .font(.title3.bold())
                        Text("Cal")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    
                    VStack(spacing: 2) {
                        Text("\(data.minutes)")
                            .font(.title3.bold())
                        Text("Min")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    
                    VStack(spacing: 2) {
                        Text(String(format: "%.1f", data.distance))
                            .font(.title3.bold())
                        Text("Mi")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .glassTile()
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Screen Time Tile

struct ScreenTimeTile: View {
    let data: ScreenTimeData
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                Label("Screen", systemImage: "iphone")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Spacer()
                
                VStack(spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text(String(format: "%.1f", data.today))
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundStyle(.pink)
                        Text("hrs")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    
                    Text("\(data.pickups) pickups")
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

// MARK: - Previews

#Preview("Sleep") {
    SleepTile(data: SleepData(hours: 7.5, quality: 82, deepSleep: 1.5, remSleep: 2.0), onTap: {})
        .frame(width: 160, height: 140)
        .padding()
}

#Preview("Heart") {
    HeartTile(data: HeartData(current: 72, resting: 58, max: 165, average: 68), onTap: {})
        .frame(width: 160, height: 140)
        .padding()
}

#Preview("Activity") {
    ActivityTile(data: ExerciseData(steps: 8432, calories: 324, minutes: 45, distance: 5.2), onTap: {})
        .frame(width: 160, height: 140)
        .padding()
}

#Preview("Screen") {
    ScreenTimeTile(data: ScreenTimeData(today: 4.5, average: 5.2, pickups: 42), onTap: {})
        .frame(width: 160, height: 140)
        .padding()
}
