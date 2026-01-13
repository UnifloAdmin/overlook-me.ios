import SwiftUI
import UserNotifications

struct HabitNotification: View {
    @Environment(\.dismiss) private var dismiss
    let habit: DailyHabitDTO
    
    @State private var reminderTimes: [Date] = []
    @State private var isAuthorized = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ForEach(reminderTimes.indices, id: \.self) { index in
                        DatePicker(
                            "Time \(index + 1)",
                            selection: Binding(
                                get: { reminderTimes[index] },
                                set: { newTime in
                                    reminderTimes[index] = newTime
                                    saveAndSchedule()
                                }
                            ),
                            displayedComponents: .hourAndMinute
                        )
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                deleteTime(at: index)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                    .onDelete(perform: deleteOffsets)
                    
                    Button {
                        addTime()
                    } label: {
                        Label("Add Reminder", systemImage: "plus")
                    }
                } header: {
                    Text(habit.name)
                }
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .close) { dismiss() } label: {
                        Image(systemName: "xmark")
                    }
                }
            }
            .onAppear {
                loadReminders()
                checkAuthorization()
            }
        }
    }
    
    private func loadReminders() {
        if let saved = UserDefaults.standard.array(forKey: "notifications_\(habit.id)") as? [Date] {
            reminderTimes = saved
        }
    }
    
    private func addTime() {
        let newTime = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()
        reminderTimes.append(newTime)
        saveAndSchedule()
    }
    
    private func deleteOffsets(offsets: IndexSet) {
        reminderTimes.remove(atOffsets: offsets)
        saveAndSchedule()
    }
    
    private func deleteTime(at index: Int) {
        reminderTimes.remove(at: index)
        saveAndSchedule()
    }
    
    private func saveAndSchedule() {
        // Save to UserDefaults
        UserDefaults.standard.set(reminderTimes, forKey: "notifications_\(habit.id)")
        
        // Schedule Notifications
        Task {
            await scheduleNotifications()
        }
    }
    
    private func checkAuthorization() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                isAuthorized = (settings.authorizationStatus == .authorized)
                if !isAuthorized {
                    requestAuthorization()
                }
            }
        }
    }
    
    private func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            DispatchQueue.main.async {
                isAuthorized = granted
            }
        }
    }
    
    private func scheduleNotifications() async {
        let center = UNUserNotificationCenter.current()
        
        // Remove existing for this habit
        let identifiersToRemove = (await center.pendingNotificationRequests())
            .filter { $0.identifier.starts(with: "habit_\(habit.id)_") }
            .map { $0.identifier }
        center.removePendingNotificationRequests(withIdentifiers: identifiersToRemove)
        
        guard !reminderTimes.isEmpty else { return }
        
        for (index, date) in reminderTimes.enumerated() {
            let content = UNMutableNotificationContent()
            content.title = "Time to \(habit.name)"
            content.body = "Keep up the streak! Mark your progress now."
            content.sound = .default
            
            let components = Calendar.current.dateComponents([.hour, .minute], from: date)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            
            let request = UNNotificationRequest(
                identifier: "habit_\(habit.id)_\(index)",
                content: content,
                trigger: trigger
            )
            
            try? await center.add(request)
        }
    }
}
