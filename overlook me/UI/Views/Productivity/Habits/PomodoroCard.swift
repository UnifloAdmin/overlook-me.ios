import SwiftUI

struct PomodoroCard: View {
    @ObservedObject var controller: PomodoroTimerController
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("Pomodoro")
                    .font(.headline)
                Spacer()
                
                if controller.isRunning, let endDate = controller.endDate {
                    Text(timerInterval: Date()...endDate, countsDown: true)
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                } else {
                    Text("\(controller.focusMinutes)m")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            
            Stepper(
                value: Binding(
                    get: { controller.focusMinutes },
                    set: { controller.updateFocusMinutes($0) }
                ),
                in: 5...180,
                step: 5
            ) {
                Text("Focus duration")
                    .font(.subheadline)
            }
            .disabled(controller.isRunning)
            
            HStack(spacing: 12) {
                Button {
                    controller.isRunning ? controller.stop() : controller.start()
                } label: {
                    Text(controller.isRunning ? "Stop" : "Start")
                }
                .buttonStyle(.borderedProminent)
                
                if controller.isRunning {
                    Button(role: .destructive) {
                        controller.stop()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Stop Pomodoro")
                }
            }
            
            Text("Runs in the background via Live Activity (Dynamic Island) and sends an alarm when finished.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
    }
}

