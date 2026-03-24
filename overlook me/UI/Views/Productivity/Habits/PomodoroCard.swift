import SwiftUI

struct PomodoroCard: View {
    @ObservedObject var controller: PomodoroTimerController

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            // Header
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("FOCUS TIMER")
                        .font(.system(size: 9, weight: .semibold))
                        .tracking(0.6)
                        .foregroundStyle(Color(hex: "#a1a1aa"))
                    if controller.isRunning, let endDate = controller.endDate {
                        Text(timerInterval: Date()...endDate, countsDown: true)
                            .font(.system(size: 20, weight: .bold))
                            .tracking(-0.8)
                            .monospacedDigit()
                            .foregroundStyle(Color(hex: "#09090b"))
                    } else {
                        Text("\(controller.focusMinutes) min")
                            .font(.system(size: 20, weight: .bold))
                            .tracking(-0.8)
                            .foregroundStyle(Color(hex: "#09090b"))
                    }
                }
                Spacer()

                // Stepper ─/+ buttons
                if !controller.isRunning {
                    HStack(spacing: 6) {
                        stepButton(icon: "minus") {
                            controller.updateFocusMinutes(max(1, controller.focusMinutes - 5))
                        }
                        stepButton(icon: "plus") {
                            controller.updateFocusMinutes(controller.focusMinutes + 5)
                        }
                    }
                }
            }

            // Thin progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color(hex: "#f4f4f5"))
                    Capsule()
                        .fill(controller.isRunning ? Color(hex: "#09090b") : Color(hex: "#d4d4d8"))
                        .frame(width: geo.size.width * cardProgress)
                        .animation(.easeInOut(duration: 0.4), value: cardProgress)
                }
            }
            .frame(height: 4)

            // Action row
            HStack(spacing: 8) {
                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    controller.isRunning ? controller.stop() : controller.start()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: controller.isRunning ? "stop.fill" : "play.fill")
                            .font(.system(size: 11, weight: .bold))
                        Text(controller.isRunning ? "Stop" : "Start")
                            .font(.system(size: 13, weight: .semibold))
                            .tracking(-0.13)
                    }
                    .foregroundStyle(controller.isRunning ? Color(hex: "#09090b") : Color.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 9)
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
                .buttonStyle(KalPomodoroPress())

                Text("Runs via Live Activity")
                    .font(.system(size: 10, weight: .regular))
                    .foregroundStyle(Color(hex: "#a1a1aa"))
            }
        }
        .padding(14)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color(hex: "#f0f0f0"), lineWidth: 1)
        )
    }

    private func stepButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color(hex: "#71717a"))
                .frame(width: 28, height: 28)
                .background(Color(hex: "#f4f4f5"), in: Circle())
        }
        .buttonStyle(KalPomodoroPress())
    }

    private var cardProgress: CGFloat {
        if controller.isRunning, let endDate = controller.endDate {
            let total = TimeInterval(controller.focusMinutes * 60)
            let remaining = max(0, endDate.timeIntervalSinceNow)
            return CGFloat(remaining / total)
        }
        return min(1, CGFloat(controller.focusMinutes) / 120.0)
    }
}

private struct KalPomodoroPress: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .opacity(configuration.isPressed ? 0.8 : 1)
            .animation(.easeInOut(duration: 0.12), value: configuration.isPressed)
    }
}
