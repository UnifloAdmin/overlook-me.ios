import SwiftUI

// MARK: - Health Data Models

struct SleepData {
    let hours: Double
    let quality: Int
    let deepSleep: Double
    let remSleep: Double

    static let empty = SleepData(hours: 0, quality: 0, deepSleep: 0, remSleep: 0)

    var formattedHours: String {
        let h = Int(hours)
        let m = Int((hours - Double(h)) * 60)
        return m > 0 ? "\(h)h \(m)m" : "\(h)h"
    }
}

struct ExerciseData {
    let steps: Int
    let calories: Int
    let minutes: Int
    let distance: Double

    static let empty = ExerciseData(steps: 0, calories: 0, minutes: 0, distance: 0)

    var formattedSteps: String {
        steps >= 1000 ? String(format: "%.1fk", Double(steps) / 1000) : "\(steps)"
    }
}

struct HeartData {
    let current: Int
    let resting: Int
    let max: Int
    let average: Int

    static let empty = HeartData(current: 0, resting: 0, max: 0, average: 0)
}

struct WaterIntake {
    let current: Int
    let goal: Int

    var progress: Double { Double(current) / Double(max(goal, 1)) }

    static let empty = WaterIntake(current: 0, goal: 8)
}

// MARK: - Color Extensions

extension Color {
    static let wellnessGreen    = Color(red: 0.20, green: 0.60, blue: 0.38)
    static let wellnessGold     = Color(red: 0.72, green: 0.55, blue: 0.14)
    static let wellnessGoldLight = Color(red: 0.82, green: 0.68, blue: 0.25)
}

// MARK: - View Extensions

extension View {
    func glassTile(padding: CGFloat = 16) -> some View {
        self
            .padding(padding)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

// MARK: - Shared UI Components

struct ProgressRing: View {
    let progress: Double
    var lineWidth: CGFloat = 8
    var color: Color = .accentColor

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.15), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: min(progress, 1))
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.spring(duration: 0.6, bounce: 0.1), value: progress)
        }
    }
}
