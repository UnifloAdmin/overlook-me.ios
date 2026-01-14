import Foundation
import Combine
import UserNotifications

#if canImport(ActivityKit)
import ActivityKit
#endif

@MainActor
final class PomodoroTimerController: ObservableObject {
    @Published var focusMinutes: Int
    @Published private(set) var isRunning: Bool
    @Published private(set) var endDate: Date?
    
    private let habitId: String
    private let habitName: String
    private let defaults: UserDefaults
    
    private let notificationId: String
    private let focusMinutesKey: String
    private let endDateKey: String
    private let activityIdKey: String
    
#if canImport(ActivityKit)
    @available(iOS 16.1, *)
    private var activity: Activity<PomodoroActivityAttributes>?
#endif
    
    init(habitId: String, habitName: String, defaults: UserDefaults = .standard) {
        self.habitId = habitId
        self.habitName = habitName
        self.defaults = defaults
        
        self.notificationId = "pomodoro_done_\(habitId)"
        self.focusMinutesKey = "pomodoro_focusMinutes_\(habitId)"
        self.endDateKey = "pomodoro_endDate_\(habitId)"
        self.activityIdKey = "pomodoro_activityId_\(habitId)"
        
        let storedFocus = defaults.integer(forKey: focusMinutesKey)
        self.focusMinutes = storedFocus == 0 ? 25 : storedFocus
        
        if let storedEnd = defaults.object(forKey: endDateKey) as? Date, storedEnd > Date() {
            self.endDate = storedEnd
            self.isRunning = true
        } else {
            self.endDate = nil
            self.isRunning = false
            defaults.removeObject(forKey: endDateKey)
        }
        
_Concurrency.Task { await restoreLiveActivityIfPossible() }
    }
    
    var remainingTimeInterval: TimeInterval {
        guard let endDate else { return 0 }
        return max(0, endDate.timeIntervalSinceNow)
    }
    
    func updateFocusMinutes(_ minutes: Int) {
        focusMinutes = max(1, minutes)
        defaults.set(focusMinutes, forKey: focusMinutesKey)
    }
    
    func start() {
        guard !isRunning else { return }
        
        let end = Date().addingTimeInterval(TimeInterval(focusMinutes * 60))
        endDate = end
        isRunning = true
        defaults.set(end, forKey: endDateKey)
        
_Concurrency.Task {
            await ensureNotificationPermission()
            await scheduleCompletionNotification(at: end)
            await startOrUpdateLiveActivity(endDate: end)
        }
    }
    
    func stop() {
        guard isRunning else { return }
        
        isRunning = false
        endDate = nil
        defaults.removeObject(forKey: endDateKey)
        
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [notificationId])
        
_Concurrency.Task { await endLiveActivity() }
    }
    
    // MARK: - Notifications
    
    private func ensureNotificationPermission() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        if settings.authorizationStatus == .notDetermined {
            _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
        }
    }
    
    private func scheduleCompletionNotification(at endDate: Date) async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [notificationId])
        
        let content = UNMutableNotificationContent()
        content.title = "Pomodoro finished"
        content.body = "“\(habitName)” focus session is done."
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: max(1, endDate.timeIntervalSinceNow),
            repeats: false
        )
        
        let request = UNNotificationRequest(identifier: notificationId, content: content, trigger: trigger)
        try? await center.add(request)
    }
    
    // MARK: - Live Activity
    
    private func restoreLiveActivityIfPossible() async {
#if canImport(ActivityKit)
        if #available(iOS 16.1, *) {
            guard isRunning, let endDate else { return }
            await startOrUpdateLiveActivity(endDate: endDate)
        }
#endif
    }
    
    private func startOrUpdateLiveActivity(endDate: Date) async {
#if canImport(ActivityKit)
        guard #available(iOS 16.1, *) else { return }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        
        // END ALL existing activities first to prevent stuck/duplicate activities
        for existingActivity in Activity<PomodoroActivityAttributes>.activities {
            await existingActivity.end(dismissalPolicy: .immediate)
        }
        
        let title = "Focus • \(focusMinutes)m"
        let state = PomodoroActivityAttributes.ContentState(endDate: endDate, title: title)

        do {
            let attributes = PomodoroActivityAttributes(habitId: habitId)
            let activity = try Activity.request(
                attributes: attributes,
                content: ActivityContent(state: state, staleDate: endDate),
                pushType: nil
            )
            self.activity = activity
            defaults.set(activity.id, forKey: activityIdKey)
        } catch {
        }
#endif
    }
    
    private func endLiveActivity() async {
#if canImport(ActivityKit)
        guard #available(iOS 16.1, *) else { return }
        
        defaults.removeObject(forKey: activityIdKey)
        self.activity = nil

        for activity in Activity<PomodoroActivityAttributes>.activities {
            await activity.end(dismissalPolicy: .immediate)
        }
#endif
    }
}

