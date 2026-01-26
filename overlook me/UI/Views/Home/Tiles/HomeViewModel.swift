import SwiftUI
import Combine

// MARK: - Data Models

struct TaskStats {
    let completed: Int
    let pending: Int
    let inProgress: Int
    let overdue: Int
    let total: Int
    
    static let empty = TaskStats(completed: 0, pending: 0, inProgress: 0, overdue: 0, total: 0)
}

struct HabitStats {
    let active: Int
    let completed: Int
    let streaks: Int
    let completionRate: Double
    
    static let empty = HabitStats(active: 0, completed: 0, streaks: 0, completionRate: 0)
}

struct SpendingStats {
    let thisMonth: Double
    let lastMonth: Double
    let trend: SpendingTrend
    let trendPercent: Double
    let topCategories: [SpendingCategory]
    
    enum SpendingTrend: String {
        case up, down, stable
    }
    
    static let empty = SpendingStats(thisMonth: 0, lastMonth: 0, trend: .stable, trendPercent: 0, topCategories: [])
}

struct SpendingCategory: Identifiable {
    let id = UUID()
    let name: String
    let amount: Double
    let percentage: Double
}

struct WeeklySpending: Identifiable {
    let id = UUID()
    let label: String
    let amount: Double
    let percentage: Double
    let isToday: Bool
    let isHighest: Bool
}

struct Budget: Identifiable {
    let id = UUID()
    let name: String
    let limit: Double
    let spent: Double
    let category: String
    
    var remaining: Double { limit - spent }
    var isOverBudget: Bool { spent > limit }
    var progress: Double { min(spent / limit, 1.0) }
}

struct UpcomingBill: Identifiable {
    let id = UUID()
    let name: String
    let amount: Double
    let daysUntil: Int
    let icon: String
    let color: Color
    
    var isUrgent: Bool { daysUntil <= 3 }
}

struct WeekDay: Identifiable {
    let id = UUID()
    let label: String
    let date: Int
    let tasks: Int
    let habits: Int
    let isToday: Bool
    let isPast: Bool
}

struct FocusTask: Identifiable {
    let id: String
    let title: String
    let status: TaskStatus
    let dueTime: Date?
    
    enum TaskStatus: String {
        case pending, inProgress, completed
    }
}

struct ScheduleItem: Identifiable {
    let id = UUID()
    let time: String
    let title: String
    let type: ScheduleType
    
    enum ScheduleType {
        case meeting, event, reminder
    }
}

struct SleepData {
    let hours: Double
    let quality: Int
    let deepSleep: Double
    let remSleep: Double
    
    static let empty = SleepData(hours: 0, quality: 0, deepSleep: 0, remSleep: 0)
}

struct ExerciseData {
    let steps: Int
    let calories: Int
    let minutes: Int
    let distance: Double
    
    static let empty = ExerciseData(steps: 0, calories: 0, minutes: 0, distance: 0)
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
    
    var progress: Double { Double(current) / Double(goal) }
    
    static let empty = WaterIntake(current: 0, goal: 8)
}

struct MoodData {
    let current: String
    let icon: String
    let streak: Int
    
    static let empty = MoodData(current: "Unknown", icon: "face.smiling", streak: 0)
}

struct ScreenTimeData {
    let today: Double
    let average: Double
    let pickups: Int
    
    static let empty = ScreenTimeData(today: 0, average: 0, pickups: 0)
}

struct DailyQuote {
    let text: String
    let author: String
    
    static let placeholder = DailyQuote(
        text: "The only way to do great work is to love what you do.",
        author: "Steve Jobs"
    )
}

// MARK: - ViewModel

@MainActor
final class HomeViewModel: ObservableObject {
    // Loading states
    @Published var isLoadingTasks = false
    @Published var isLoadingHabits = false
    @Published var isLoadingSpending = false
    
    // Data
    @Published var taskStats = TaskStats.empty
    @Published var habitStats = HabitStats.empty
    @Published var spendingStats = SpendingStats.empty
    @Published var focusTasks: [FocusTask] = []
    @Published var weeklySpending: [WeeklySpending] = []
    @Published var budgets: [Budget] = []
    @Published var upcomingBills: [UpcomingBill] = []
    @Published var weekDays: [WeekDay] = []
    @Published var schedule: [ScheduleItem] = []
    
    // Wellness
    @Published var sleepData = SleepData.empty
    @Published var exerciseData = ExerciseData.empty
    @Published var heartData = HeartData.empty
    @Published var waterIntake = WaterIntake.empty
    @Published var moodData = MoodData.empty
    @Published var screenTime = ScreenTimeData.empty
    
    // Daily life
    @Published var dailyQuote = DailyQuote.placeholder
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        loadMockData()
    }
    
    func refresh() {
        loadMockData()
        // TODO: Connect to real API services
    }
    
    // MARK: - Helpers
    
    var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Good Morning"
        case 12..<17: return "Good Afternoon"
        case 17..<22: return "Good Evening"
        default: return "Sweet Night"
        }
    }
    
    var todayDateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter.string(from: Date())
    }
    
    func formatCurrency(_ amount: Double) -> String {
        if amount >= 10000 {
            return "$\(Int(amount / 1000))k"
        } else if amount >= 1000 {
            return String(format: "$%.1fk", amount / 1000)
        }
        return "$\(Int(amount))"
    }
    
    // MARK: - Mock Data
    
    private func loadMockData() {
        // Task Stats
        taskStats = TaskStats(completed: 5, pending: 3, inProgress: 2, overdue: 1, total: 11)
        
        // Habit Stats
        habitStats = HabitStats(active: 6, completed: 4, streaks: 12, completionRate: 75)
        
        // Spending Stats
        spendingStats = SpendingStats(
            thisMonth: 2847,
            lastMonth: 3120,
            trend: .down,
            trendPercent: 8.7,
            topCategories: [
                SpendingCategory(name: "Food & Drink", amount: 856, percentage: 30),
                SpendingCategory(name: "Shopping", amount: 612, percentage: 21),
                SpendingCategory(name: "Transport", amount: 428, percentage: 15),
                SpendingCategory(name: "Entertainment", amount: 285, percentage: 10)
            ]
        )
        
        // Focus Tasks
        focusTasks = [
            FocusTask(id: "1", title: "Review project proposal", status: .pending, dueTime: nil),
            FocusTask(id: "2", title: "Team standup meeting", status: .completed, dueTime: nil),
            FocusTask(id: "3", title: "Update documentation", status: .inProgress, dueTime: nil)
        ]
        
        // Weekly Spending
        let days = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
        let amounts: [Double] = [45, 128, 67, 89, 156, 234, 78]
        let maxAmount = amounts.max() ?? 1
        let todayIndex = (Calendar.current.component(.weekday, from: Date()) + 5) % 7
        
        weeklySpending = days.enumerated().map { index, day in
            WeeklySpending(
                label: day,
                amount: amounts[index],
                percentage: amounts[index] / maxAmount * 100,
                isToday: index == todayIndex,
                isHighest: amounts[index] == maxAmount
            )
        }
        
        // Budgets
        budgets = [
            Budget(name: "Groceries", limit: 500, spent: 387, category: "food"),
            Budget(name: "Entertainment", limit: 200, spent: 156, category: "fun"),
            Budget(name: "Transport", limit: 150, spent: 178, category: "transport")
        ]
        
        // Upcoming Bills
        upcomingBills = [
            UpcomingBill(name: "Netflix", amount: 16, daysUntil: 2, icon: "tv", color: .gray),
            UpcomingBill(name: "Spotify", amount: 10, daysUntil: 5, icon: "music.note", color: .green),
            UpcomingBill(name: "Electric", amount: 85, daysUntil: 8, icon: "bolt.fill", color: .yellow),
            UpcomingBill(name: "Internet", amount: 65, daysUntil: 12, icon: "wifi", color: .blue)
        ]
        
        // Week at a Glance
        let calendar = Calendar.current
        let today = Date()
        let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today))!
        
        weekDays = (0..<7).map { offset in
            let date = calendar.date(byAdding: .day, value: offset, to: startOfWeek)!
            let dayOfMonth = calendar.component(.day, from: date)
            let isToday = calendar.isDateInToday(date)
            let isPast = date < today && !isToday
            
            return WeekDay(
                label: days[offset],
                date: dayOfMonth,
                tasks: Int.random(in: 0...5),
                habits: Int.random(in: 0...4),
                isToday: isToday,
                isPast: isPast
            )
        }
        
        // Schedule
        schedule = [
            ScheduleItem(time: "9:00 AM", title: "Team Standup", type: .meeting),
            ScheduleItem(time: "12:30 PM", title: "Lunch with Alex", type: .event),
            ScheduleItem(time: "3:00 PM", title: "Project Review", type: .meeting)
        ]
        
        // Wellness
        sleepData = SleepData(hours: 7.5, quality: 82, deepSleep: 1.5, remSleep: 2.0)
        exerciseData = ExerciseData(steps: 8432, calories: 324, minutes: 45, distance: 5.2)
        heartData = HeartData(current: 72, resting: 58, max: 165, average: 68)
        waterIntake = WaterIntake(current: 5, goal: 8)
        moodData = MoodData(current: "Good", icon: "face.smiling", streak: 3)
        screenTime = ScreenTimeData(today: 4.5, average: 5.2, pickups: 42)
        
        // Quote
        dailyQuote = DailyQuote(
            text: "The only way to do great work is to love what you do.",
            author: "Steve Jobs"
        )
    }
}
