import SwiftUI
import Combine

struct PomodoroSheet: View {
    @Environment(\.dismiss) private var dismiss
    let habit: DailyHabitDTO

    @StateObject private var controller: PomodoroTimerController
    @State private var timerTick = Date()
    @State private var lastDragY: CGFloat = 0

    private let ringSize: CGFloat = 220
    private let ringLineWidth: CGFloat = 12
    private let pointsPerMinute: CGFloat = 18   // pixels needed to change by 1 min

    init(habit: DailyHabitDTO) {
        self.habit = habit
        _controller = StateObject(
            wrappedValue: PomodoroTimerController(habitId: habit.id, habitName: habit.name)
        )
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Spacer(minLength: 16)
                if controller.isRunning {
                    runningView
                } else {
                    idleView
                }
                Spacer(minLength: 28)
                controlsSection
                Spacer(minLength: 44)
            }
            .padding(.horizontal, 28)
            .background(Color.white.ignoresSafeArea())
            .navigationTitle("Focus Timer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(Color(hex: "#a1a1aa"))
                    }
                }
            }
            .onReceive(
                Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()
            ) { _ in if controller.isRunning { timerTick = Date() } }
        }
    }

    // MARK: - Idle — swipeable number

    private var idleView: some View {
        VStack(spacing: 0) {
            // Habit label
            Text(habit.name.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .tracking(1.0)
                .foregroundStyle(Color(hex: "#d4d4d8"))
                .padding(.bottom, 36)

            // Large draggable number
            ZStack {
                // Up / Down affordance dots
                VStack(spacing: 0) {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color(hex: "#d4d4d8"))
                        .padding(.bottom, 12)

                    HStack(alignment: .lastTextBaseline, spacing: 6) {
                        Text("\(controller.focusMinutes)")
                            .font(.system(size: 88, weight: .bold, design: .rounded))
                            .tracking(-4)
                            .foregroundStyle(Color(hex: "#09090b"))
                            .monospacedDigit()
                            .contentTransition(.numericText())
                            .animation(.easeInOut(duration: 0.12), value: controller.focusMinutes)

                        Text("min")
                            .font(.system(size: 20, weight: .medium, design: .rounded))
                            .tracking(-0.5)
                            .foregroundStyle(Color(hex: "#a1a1aa"))
                            .padding(.bottom, 8)
                    }

                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color(hex: "#d4d4d8"))
                        .padding(.top, 12)
                }
            }
            .gesture(
                DragGesture(minimumDistance: 4)
                    .onChanged { value in
                        let dy = value.translation.height - lastDragY
                        lastDragY = value.translation.height
                        // Negative dy = swipe up = more minutes
                        let minuteDelta = Int((-dy / pointsPerMinute).rounded())
                        guard minuteDelta != 0 else { return }
                        let newVal = max(1, controller.focusMinutes + minuteDelta)
                        if newVal != controller.focusMinutes {
                            UISelectionFeedbackGenerator().selectionChanged()
                            controller.updateFocusMinutes(newVal)
                        }
                    }
                    .onEnded { _ in lastDragY = 0 }
            )

            // Hint
            Text("SWIPE UP OR DOWN TO SET")
                .font(.system(size: 9, weight: .semibold))
                .tracking(0.9)
                .foregroundStyle(Color(hex: "#e4e4e7"))
                .padding(.top, 28)
        }
    }

    // MARK: - Running — progress ring

    private var runningView: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .stroke(Color(hex: "#f4f4f5"), lineWidth: ringLineWidth)
                    .frame(width: ringSize, height: ringSize)

                Circle()
                    .trim(from: 0, to: progressValue)
                    .stroke(
                        progressValue < 0.15 ? Color(hex: "#dc2626") : Color(hex: "#09090b"),
                        style: StrokeStyle(lineWidth: ringLineWidth, lineCap: .round)
                    )
                    .frame(width: ringSize, height: ringSize)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.35), value: progressValue)

                VStack(spacing: 3) {
                    if let endDate = controller.endDate {
                        Text(timerInterval: Date()...endDate, countsDown: true)
                            .font(.system(size: 44, weight: .semibold, design: .rounded))
                            .tracking(-1.5)
                            .monospacedDigit()
                            .foregroundStyle(
                                progressValue < 0.15 ? Color(hex: "#dc2626") : Color(hex: "#09090b")
                            )
                    }
                    Text("remaining")
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(0.8)
                        .foregroundStyle(Color(hex: "#a1a1aa"))
                }
            }

            Text(habit.name.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .tracking(1.0)
                .foregroundStyle(Color(hex: "#a1a1aa"))
        }
    }

    // MARK: - Controls

    private var controlsSection: some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            controller.isRunning ? controller.stop() : controller.start()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: controller.isRunning ? "stop.fill" : "play.fill")
                    .font(.system(size: 13, weight: .bold))
                Text(controller.isRunning ? "Stop" : "Start Focus")
                    .font(.system(size: 15, weight: .semibold))
                    .tracking(-0.15)
            }
            .foregroundStyle(controller.isRunning ? Color(hex: "#09090b") : Color.white)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                controller.isRunning ? Color(hex: "#f4f4f5") : Color(hex: "#09090b"),
                in: Capsule()
            )
            .overlay(
                Capsule().strokeBorder(
                    controller.isRunning ? Color(hex: "#e4e4e7") : Color.clear,
                    lineWidth: 1
                )
            )
        }
        .buttonStyle(KalFocusPress())
        .animation(.easeInOut(duration: 0.15), value: controller.isRunning)
    }

    // MARK: - Progress

    private var progressValue: CGFloat {
        guard controller.isRunning, let endDate = controller.endDate else { return 1 }
        _ = timerTick
        let total = TimeInterval(controller.focusMinutes * 60)
        let remaining = max(0, endDate.timeIntervalSinceNow)
        return CGFloat(remaining / total)
    }
}

private struct KalFocusPress: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.82 : 1)
            .animation(.easeInOut(duration: 0.12), value: configuration.isPressed)
    }
}
