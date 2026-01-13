import SwiftUI
import Combine

struct PomodoroSheet: View {
    @Environment(\.dismiss) private var dismiss
    let habit: DailyHabitDTO
    @StateObject private var controller: PomodoroTimerController
    @State private var isDragging = false
    @State private var dragAngle: Double = 0
    @State private var timerTick = Date()
    
    private let ringSize: CGFloat = 220
    private let ringLineWidth: CGFloat = 16
    private let minMinutes = 5
    private let maxMinutes = 120
    
    init(habit: DailyHabitDTO) {
        self.habit = habit
        _controller = StateObject(wrappedValue: PomodoroTimerController(habitId: habit.id, habitName: habit.name))
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                timerDisplay
                controlsSection
                Spacer()
            }
            .padding(.top, 24)
            .padding(.horizontal, 24)
            .navigationTitle("Focus Timer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .onReceive(Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()) { _ in
                if controller.isRunning {
                    timerTick = Date()
                }
            }
        }
    }
    
    private var timerDisplay: some View {
        VStack(spacing: 16) {
            ZStack {
                // Background ring
                Circle()
                    .stroke(ringBackgroundColor, lineWidth: ringLineWidth)
                    .frame(width: ringSize, height: ringSize)
                
                // Progress ring
                Circle()
                    .trim(from: 0, to: progressValue)
                    .stroke(
                        ringForegroundColor,
                        style: StrokeStyle(lineWidth: ringLineWidth, lineCap: .round)
                    )
                    .frame(width: ringSize, height: ringSize)
                    .rotationEffect(.degrees(-90))
                    .animation(isDragging ? nil : .easeInOut(duration: 0.3), value: progressValue)
                
                // Drag handle (only when not running)
                if !controller.isRunning {
                    dragHandle
                }
                
                // Timer text
                VStack(spacing: 4) {
                    if controller.isRunning, let endDate = controller.endDate {
                        Text(timerInterval: Date()...endDate, countsDown: true)
                            .font(.system(size: 44, weight: .medium, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.primary)
                    } else {
                        Text("\(controller.focusMinutes)")
                            .font(.system(size: 56, weight: .semibold, design: .rounded))
                            .foregroundStyle(isDragging ? .orange : .primary)
                        Text("minutes")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .scaleEffect(isDragging ? 1.05 : 1.0)
                .animation(.easeInOut(duration: 0.15), value: isDragging)
            }
            .gesture(dragGesture)
            
            Text(habit.name)
                .font(.headline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
    
    private var dragHandle: some View {
        let angle = Angle(degrees: Double(controller.focusMinutes - minMinutes) / Double(maxMinutes - minMinutes) * 360 - 90)
        let radius = ringSize / 2
        let x = cos(angle.radians) * radius
        let y = sin(angle.radians) * radius
        
        return Circle()
            .fill(Color.orange)
            .frame(width: ringLineWidth + 8, height: ringLineWidth + 8)
            .shadow(color: .orange.opacity(0.5), radius: isDragging ? 8 : 4)
            .scaleEffect(isDragging ? 1.2 : 1.0)
            .offset(x: x, y: y)
            .animation(.easeInOut(duration: 0.15), value: isDragging)
    }
    
    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard !controller.isRunning else { return }
                
                if !isDragging {
                    isDragging = true
                    hapticFeedback(.light)
                }
                
                let center = CGPoint(x: ringSize / 2, y: ringSize / 2)
                let location = value.location
                let vector = CGVector(dx: location.x - center.x, dy: location.y - center.y)
                var angle = atan2(vector.dy, vector.dx) + .pi / 2
                
                if angle < 0 { angle += 2 * .pi }
                
                let percentage = angle / (2 * .pi)
                let newMinutes = Int(percentage * Double(maxMinutes - minMinutes)) + minMinutes
                let clampedMinutes = max(minMinutes, min(maxMinutes, newMinutes))
                
                // Round to nearest 5
                let roundedMinutes = (clampedMinutes / 5) * 5
                
                if roundedMinutes != controller.focusMinutes {
                    hapticFeedback(.selection)
                    controller.updateFocusMinutes(max(minMinutes, roundedMinutes))
                }
            }
            .onEnded { _ in
                isDragging = false
                hapticFeedback(.medium)
            }
    }
    
    private var ringBackgroundColor: Color {
        if isDragging {
            return Color.orange.opacity(0.3)
        }
        return Color.orange.opacity(0.15)
    }
    
    private var ringForegroundColor: Color {
        if controller.isRunning {
            let progress = progressValue
            if progress < 0.1 {
                return .red
            } else if progress < 0.25 {
                return .orange
            }
            return .orange
        }
        return isDragging ? .orange : .orange.opacity(0.9)
    }
    
    private var controlsSection: some View {
        VStack(spacing: 20) {
            // Start/Stop button
            Button {
                hapticFeedback(.medium)
                if controller.isRunning {
                    controller.stop()
                } else {
                    controller.start()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: controller.isRunning ? "stop.fill" : "play.fill")
                    Text(controller.isRunning ? "Stop" : "Start Focus")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(controller.isRunning ? Color.red : Color.orange)
                .foregroundStyle(.white)
                .cornerRadius(14)
            }
            
            if !controller.isRunning {
                Text("Drag the ring to set duration")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    private var progressValue: CGFloat {
        if controller.isRunning, let endDate = controller.endDate {
            // Use timerTick to force recalculation
            _ = timerTick
            let total = TimeInterval(controller.focusMinutes * 60)
            let remaining = max(0, endDate.timeIntervalSinceNow)
            return CGFloat(remaining / total)
        }
        // When not running, show the set duration as progress
        return CGFloat(controller.focusMinutes - minMinutes) / CGFloat(maxMinutes - minMinutes)
    }
    
    private func hapticFeedback(_ style: HapticStyle) {
        switch style {
        case .light:
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        case .medium:
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        case .selection:
            UISelectionFeedbackGenerator().selectionChanged()
        }
    }
    
    private enum HapticStyle {
        case light, medium, selection
    }
}
