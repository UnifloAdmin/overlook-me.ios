
import SwiftUI
import UserNotifications

struct NotificationsManageView: View {
    @State private var pendingNotifications: [UNNotificationRequest] = []
    @State private var isAuthorized = false
    @State private var hasLoaded = false
    @State private var selectedWrapper: NotificationRequestWrapper?
    
    var body: some View {
        List {
            if !isAuthorized {
                notificationPermissionSection
            }
            
            if !pendingNotifications.isEmpty {
                Section {
                    ForEach(pendingNotifications, id: \.identifier) { request in
                        NotificationRow(request: request)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedWrapper = NotificationRequestWrapper(request: request)
                            }
                    }
                    .onDelete(perform: deleteNotifications)
                } header: {
                    Text("Scheduled")
                }
            }
            
            if pendingNotifications.isEmpty && hasLoaded && isAuthorized {
                Section {
                    VStack(spacing: 12) {
                        Image(systemName: "bell.slash")
                            .font(.system(size: 36))
                            .foregroundStyle(.tertiary)
                        
                        Text("No notifications")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !pendingNotifications.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .destructive) {
                        clearAllNotifications()
                    } label: {
                        Text("Clear All")
                            .font(.subheadline)
                    }
                }
            }
        }
        .task {
            await loadData()
        }
        .refreshable {
            await loadData()
        }
        .sheet(item: $selectedWrapper) { wrapper in
            NotificationEditSheet(request: wrapper.request, onSave: { [self] in
                let _ = _Concurrency.Task { await self.loadData() }
            })
        }
    }
    
    private var notificationPermissionSection: some View {
        Section {
            HStack(spacing: 14) {
                Circle()
                    .fill(.orange.opacity(0.15))
                    .frame(width: 40, height: 40)
                    .overlay {
                        Image(systemName: "bell.badge")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(.orange)
                    }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Notifications Off")
                        .font(.subheadline.weight(.semibold))
                    Text("Tap to enable")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Button("Enable") {
                    requestNotificationPermission()
                }
                .font(.subheadline.weight(.medium))
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .controlSize(.small)
            }
            .padding(.vertical, 6)
        }
    }
    
    private func loadData() async {
        checkNotificationAuthorization()
        await loadPendingNotifications()
        await MainActor.run {
            hasLoaded = true
        }
    }
    
    private func loadPendingNotifications() async {
        let center = UNUserNotificationCenter.current()
        let requests = await center.pendingNotificationRequests()
        
        await MainActor.run {
            pendingNotifications = requests.sorted { req1, req2 in
                let date1 = nextTriggerDate(for: req1.trigger)
                let date2 = nextTriggerDate(for: req2.trigger)
                if let d1 = date1, let d2 = date2 {
                    return d1 < d2
                }
                return date1 != nil
            }
        }
    }
    
    private func nextTriggerDate(for trigger: UNNotificationTrigger?) -> Date? {
        if let calendarTrigger = trigger as? UNCalendarNotificationTrigger {
            return calendarTrigger.nextTriggerDate()
        } else if let intervalTrigger = trigger as? UNTimeIntervalNotificationTrigger {
            return intervalTrigger.nextTriggerDate()
        }
        return nil
    }
    
    private func deleteNotifications(at offsets: IndexSet) {
        let identifiers = offsets.map { pendingNotifications[$0].identifier }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
        pendingNotifications.remove(atOffsets: offsets)
    }
    
    private func clearAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        pendingNotifications = []
    }
    
    private func checkNotificationAuthorization() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                isAuthorized = (settings.authorizationStatus == .authorized)
            }
        }
    }
    
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            DispatchQueue.main.async {
                isAuthorized = granted
            }
        }
    }
}

// MARK: - Wrapper for Identifiable

private struct NotificationRequestWrapper: Identifiable {
    let request: UNNotificationRequest
    var id: String { request.identifier }
}

// MARK: - Notification Edit Sheet

private struct NotificationEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    let request: UNNotificationRequest
    let onSave: () -> Void
    
    @State private var title: String = ""
    @State private var messageBody: String = ""
    @State private var selectedSound: NotificationSoundOption = .default
    @State private var interruptionLevel: UNNotificationInterruptionLevel = .active
    @State private var isSaving = false
    @State private var isSticky: Bool = false
    
    // Schedule
    @State private var selectedTime: Date = Date()
    @State private var isRepeating: Bool = true
    @State private var selectedDays: Set<Int> = Set(1...7) // 1 = Sunday, 7 = Saturday
    
    private let weekdays = [
        (1, "Sun"), (2, "Mon"), (3, "Tue"), (4, "Wed"), (5, "Thu"), (6, "Fri"), (7, "Sat")
    ]
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Content") {
                    TextField("Title", text: $title)
                    TextField("Message", text: $messageBody, axis: .vertical)
                        .lineLimit(2...4)
                }
                
                Section("Schedule") {
                    DatePicker("Time", selection: $selectedTime, displayedComponents: .hourAndMinute)
                    
                    Toggle("Repeat", isOn: $isRepeating)
                    
                    if isRepeating {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Days")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            
                            HStack(spacing: 8) {
                                ForEach(weekdays, id: \.0) { day in
                                    DayButton(
                                        label: day.1,
                                        isSelected: selectedDays.contains(day.0),
                                        action: { toggleDay(day.0) }
                                    )
                                }
                            }
                        }
                        .padding(.vertical, 4)
                        
                        HStack(spacing: 12) {
                            Button("Weekdays") {
                                selectedDays = Set([2, 3, 4, 5, 6])
                            }
                            .font(.caption)
                            .buttonStyle(.bordered)
                            .buttonBorderShape(.capsule)
                            
                            Button("Weekends") {
                                selectedDays = Set([1, 7])
                            }
                            .font(.caption)
                            .buttonStyle(.bordered)
                            .buttonBorderShape(.capsule)
                            
                            Button("Every Day") {
                                selectedDays = Set(1...7)
                            }
                            .font(.caption)
                            .buttonStyle(.bordered)
                            .buttonBorderShape(.capsule)
                        }
                    }
                }
                
                Section("Sound") {
                    Picker("Sound", selection: $selectedSound) {
                        ForEach(NotificationSoundOption.allCases) { sound in
                            Text(sound.displayName).tag(sound)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                Section {
                    Toggle(isOn: $isSticky) {
                        HStack {
                            Image(systemName: "pin.fill")
                                .foregroundStyle(.orange)
                            Text("Sticky")
                        }
                    }
                    .onChange(of: isSticky) { _, newValue in
                        if newValue {
                            interruptionLevel = .timeSensitive
                        }
                    }
                    
                    Picker("Delivery", selection: $interruptionLevel) {
                        Text("Silent").tag(UNNotificationInterruptionLevel.passive)
                        Text("Normal").tag(UNNotificationInterruptionLevel.active)
                        Text("Time Sensitive").tag(UNNotificationInterruptionLevel.timeSensitive)
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: interruptionLevel) { _, newValue in
                        if newValue != .timeSensitive {
                            isSticky = false
                        }
                    }
                } header: {
                    Text("Priority")
                } footer: {
                    Text(isSticky ? "Notification will stay visible until you dismiss it." : interruptionLevelDescription)
                }
            }
            .navigationTitle("Edit Notification")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveNotification()
                    }
                    .disabled(title.isEmpty || isSaving || (isRepeating && selectedDays.isEmpty))
                }
            }
            .onAppear {
                loadCurrentSettings()
            }
        }
    }
    
    private func toggleDay(_ day: Int) {
        if selectedDays.contains(day) {
            selectedDays.remove(day)
        } else {
            selectedDays.insert(day)
        }
    }
    
    private var interruptionLevelDescription: String {
        switch interruptionLevel {
        case .passive:
            return "Delivers quietly without waking the screen."
        case .active:
            return "Standard notification with sound and banner."
        case .timeSensitive:
            return "Can break through Focus and Do Not Disturb."
        case .critical:
            return "Critical alerts always play sound."
        @unknown default:
            return ""
        }
    }
    
    private func loadCurrentSettings() {
        title = request.content.title
        messageBody = request.content.body
        interruptionLevel = request.content.interruptionLevel
        
        // Check if sticky (timeSensitive + high relevance)
        isSticky = request.content.interruptionLevel == .timeSensitive && request.content.relevanceScore >= 1.0
        
        if request.content.sound == nil {
            selectedSound = .none
        } else {
            selectedSound = .default
        }
        
        // Load schedule from trigger
        if let calendarTrigger = request.trigger as? UNCalendarNotificationTrigger {
            let components = calendarTrigger.dateComponents
            
            if let hour = components.hour, let minute = components.minute {
                selectedTime = Calendar.current.date(from: DateComponents(hour: hour, minute: minute)) ?? Date()
            }
            
            isRepeating = calendarTrigger.repeats
            
            if let weekday = components.weekday {
                selectedDays = Set([weekday])
            } else if calendarTrigger.repeats {
                selectedDays = Set(1...7)
            }
        }
    }
    
    private func saveNotification() {
        isSaving = true
        
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = messageBody
        content.interruptionLevel = isSticky ? .timeSensitive : interruptionLevel
        content.sound = selectedSound.sound
        content.badge = request.content.badge
        content.categoryIdentifier = request.content.categoryIdentifier
        content.threadIdentifier = request.content.threadIdentifier
        content.userInfo = request.content.userInfo
        
        // Set high relevance for sticky notifications
        if isSticky {
            content.relevanceScore = 1.0
        }
        
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [request.identifier])
        
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: selectedTime)
        let minute = calendar.component(.minute, from: selectedTime)
        
        if isRepeating && !selectedDays.isEmpty {
            // Create one notification per selected day
            let sortedDays = selectedDays.sorted()
            
            for (index, weekday) in sortedDays.enumerated() {
                var components = DateComponents()
                components.hour = hour
                components.minute = minute
                components.weekday = weekday
                
                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
                let identifier = "\(request.identifier)_\(index)"
                
                let newRequest = UNNotificationRequest(
                    identifier: identifier,
                    content: content,
                    trigger: trigger
                )
                
                center.add(newRequest, withCompletionHandler: nil)
            }
            
            DispatchQueue.main.async {
                isSaving = false
                onSave()
                dismiss()
            }
        } else {
            // Single notification
            var components = DateComponents()
            components.hour = hour
            components.minute = minute
            
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: isRepeating)
            
            let newRequest = UNNotificationRequest(
                identifier: request.identifier,
                content: content,
                trigger: trigger
            )
            
            center.add(newRequest) { error in
                DispatchQueue.main.async {
                    isSaving = false
                    if error == nil {
                        onSave()
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Day Button

private struct DayButton: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.caption.weight(.medium))
                .frame(width: 36, height: 36)
                .background(isSelected ? Color.accentColor : Color(.systemGray5))
                .foregroundStyle(isSelected ? .white : .primary)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Sound Options

private enum NotificationSoundOption: String, CaseIterable, Identifiable {
    case none
    case `default`
    case tri_tone = "tri-tone"
    case chime
    case glass
    case horn
    case bell
    case electronic
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .none: return "None"
        case .default: return "Default"
        case .tri_tone: return "Tri-tone"
        case .chime: return "Chime"
        case .glass: return "Glass"
        case .horn: return "Horn"
        case .bell: return "Bell"
        case .electronic: return "Electronic"
        }
    }
    
    var sound: UNNotificationSound? {
        switch self {
        case .none:
            return nil
        case .default:
            return .default
        case .tri_tone:
            return .default
        case .chime:
            return .default
        case .glass:
            return .default
        case .horn:
            return .default
        case .bell:
            return .default
        case .electronic:
            return .default
        }
    }
}

// MARK: - Notification Row

private struct NotificationRow: View {
    let request: UNNotificationRequest
    
    private var title: String {
        request.content.title.isEmpty ? "Notification" : request.content.title
    }
    
    private var timeString: String {
        guard let trigger = request.trigger else { return "" }
        
        if let calendarTrigger = trigger as? UNCalendarNotificationTrigger {
            let components = calendarTrigger.dateComponents
            if let hour = components.hour, let minute = components.minute {
                let formatter = DateFormatter()
                formatter.timeStyle = .short
                let date = Calendar.current.date(from: DateComponents(hour: hour, minute: minute)) ?? Date()
                return formatter.string(from: date)
            }
        } else if let intervalTrigger = trigger as? UNTimeIntervalNotificationTrigger {
            let interval = intervalTrigger.timeInterval
            if interval < 60 {
                return "In \(Int(interval))s"
            } else if interval < 3600 {
                return "In \(Int(interval / 60))m"
            } else {
                return "In \(Int(interval / 3600))h"
            }
        }
        return ""
    }
    
    private var isRepeating: Bool {
        if let calendarTrigger = request.trigger as? UNCalendarNotificationTrigger {
            return calendarTrigger.repeats
        }
        return false
    }
    
    private var isTimeSensitive: Bool {
        request.content.interruptionLevel == .timeSensitive
    }
    
    private var isSticky: Bool {
        request.content.interruptionLevel == .timeSensitive && request.content.relevanceScore >= 1.0
    }
    
    private var iconName: String {
        let id = request.identifier.lowercased()
        if id.contains("habit") {
            return "repeat.circle.fill"
        } else if id.contains("task") {
            return "checkmark.circle.fill"
        } else if id.contains("pomodoro") {
            return "timer"
        }
        return "bell.fill"
    }
    
    private var iconColor: Color {
        let id = request.identifier.lowercased()
        if id.contains("habit") {
            return .green
        } else if id.contains("task") {
            return .blue
        } else if id.contains("pomodoro") {
            return .red
        }
        return .orange
    }
    
    var body: some View {
        HStack(spacing: 14) {
            Circle()
                .fill(iconColor.opacity(0.15))
                .frame(width: 40, height: 40)
                .overlay {
                    Image(systemName: iconName)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(iconColor)
                }
            
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    
                    if isSticky {
                        Image(systemName: "pin.fill")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    } else if isTimeSensitive {
                        Image(systemName: "clock.badge.exclamationmark")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                }
                
                HStack(spacing: 6) {
                    Text(timeString)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    if isRepeating {
                        Text("•")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                        Text("Daily")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    
                    if isSticky {
                        Text("•")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                        Text("Sticky")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 6)
    }
}

#Preview {
    NavigationStack {
        NotificationsManageView()
    }
}
