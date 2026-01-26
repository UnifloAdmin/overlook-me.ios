//
//  HealthInsightsView.swift
//  overlook me
//
//  Created by Naresh Chandra on 1/15/26.
//

import SwiftUI
import HealthKit
import Combine
import Charts

struct HealthInsightsView: View {
    @StateObject private var healthKitManager = HealthKitManager()
    
    var body: some View {
        ZStack(alignment: .top) {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()
            
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 16) {
                    sleepContainer
                }
                .padding(.horizontal, 16)
                .padding(.top, 120)
                .padding(.bottom, 24)
            }
        }
        .ignoresSafeArea(edges: .top)
        .navigationTitle("Health Insights")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await healthKitManager.requestAuthorization()
            await healthKitManager.fetchWeeklySleepData()
            await healthKitManager.fetchMonthlySleepData()
        }
    }

    private var sleepContainer: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Sleep")
                        .font(.headline)
                    Text("Last 7 days overview")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text(healthKitManager.averageSleepFormatted)
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("avg/night")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if let goal = healthKitManager.sleepGoal {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Goal")
                            .font(.subheadline)
                        Spacer()
                        Text(formatHours(goal))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    ProgressView(value: Double(healthKitManager.goalProgress), total: 100)
                        .tint(.purple)
                }
            }

            HStack(spacing: 12) {
                averageCard(
                    title: "Last week avg",
                    value: averageLabel(healthKitManager.averageSleep),
                    data: healthKitManager.weeklySleepData,
                    accent: .purple
                )
                averageCard(
                    title: "Monthly avg",
                    value: averageLabel(healthKitManager.monthlyAverage),
                    data: healthKitManager.monthlySleepData,
                    accent: .blue
                )
            }

            HStack(spacing: 12) {
                miniStat(title: "Best", value: bestNightLabel)
                miniStat(title: "Lowest", value: worstNightLabel)
                miniStat(title: "Consistency", value: consistencyLabel)
            }

            Chart(healthKitManager.weeklySleepData) { day in
                BarMark(
                    x: .value("Day", day.dayLabel),
                    y: .value("Hours", day.hours)
                )
                .foregroundStyle(day.isToday ? Color.purple : Color.accentColor)
                .cornerRadius(6)
            }
            .chartYScale(domain: 0...12)
            .frame(height: 170)
            .accessibilityLabel("Sleep hours chart for the last 7 days")

            VStack(alignment: .leading, spacing: 10) {
                Text("Insights")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 8) {
                    insightRow(text: goalInsightText)
                    insightRow(text: variabilityInsightText)
                    insightRow(text: trendInsightText)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color(.separator).opacity(0.6), lineWidth: 1)
        )
    }
    
    private func formatHours(_ hours: Double) -> String {
        let h = Int(hours)
        let m = Int((hours - Double(h)) * 60)
        return "\(h)h\(m > 0 ? " \(m)m" : "")"
    }

    private func averageLabel(_ hours: Double) -> String {
        guard hours > 0 else { return "—" }
        return formatHours(hours)
    }

    private func miniStat(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color(.separator).opacity(0.45), lineWidth: 1)
        )
    }

    private func averageCard(title: String, value: String, data: [SleepDayData], accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
            Chart(data) { day in
                BarMark(
                    x: .value("Date", day.date),
                    y: .value("Hours", day.hours)
                )
                .foregroundStyle(accent)
                .cornerRadius(5)
            }
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .frame(height: 70)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color(.separator).opacity(0.45), lineWidth: 1)
        )
    }

    private func insightRow(text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(Color.purple)
                .frame(width: 6, height: 6)
                .padding(.top, 6)
            Text(text)
                .font(.footnote)
                .foregroundStyle(.primary)
        }
    }

    private var bestNightLabel: String {
        guard let best = healthKitManager.weeklySleepData.max(by: { $0.hours < $1.hours }) else {
            return "—"
        }
        return "\(best.dayLabel) \(formatHours(best.hours))"
    }

    private var worstNightLabel: String {
        guard let worst = healthKitManager.weeklySleepData.min(by: { $0.hours < $1.hours }) else {
            return "—"
        }
        return "\(worst.dayLabel) \(formatHours(worst.hours))"
    }

    private var consistencyLabel: String {
        let hours = healthKitManager.weeklySleepData.map(\.hours)
        guard !hours.isEmpty else { return "—" }
        let mean = hours.reduce(0, +) / Double(hours.count)
        let variance = hours.map { pow($0 - mean, 2) }.reduce(0, +) / Double(hours.count)
        let stdDev = sqrt(variance)
        let score = max(0, min(100, Int(100 - (stdDev * 12))))
        return "\(score)%"
    }

    private var goalInsightText: String {
        guard let goal = healthKitManager.sleepGoal else {
            return "Set a sleep goal to track progress more closely."
        }
        let average = healthKitManager.averageSleep
        if average >= goal {
            return "You met your goal on average this week."
        }
        let gap = max(0, goal - average)
        return "You are \(formatHours(gap)) below your goal on average."
    }

    private var variabilityInsightText: String {
        let hours = healthKitManager.weeklySleepData.map(\.hours)
        guard hours.count >= 3 else {
            return "Log a few more nights to see consistency."
        }
        let mean = hours.reduce(0, +) / Double(hours.count)
        let variance = hours.map { pow($0 - mean, 2) }.reduce(0, +) / Double(hours.count)
        let stdDev = sqrt(variance)
        if stdDev <= 0.6 {
            return "Your sleep schedule is very consistent."
        } else if stdDev <= 1.2 {
            return "Your sleep is moderately consistent."
        } else {
            return "Your sleep varies a lot. Aim for steadier bedtimes."
        }
    }

    private var trendInsightText: String {
        let hours = healthKitManager.weeklySleepData.map(\.hours)
        guard hours.count >= 4 else {
            return "Keep tracking to spot weekly trends."
        }
        let firstHalf = hours.prefix(3).reduce(0, +) / 3
        let secondHalf = hours.suffix(3).reduce(0, +) / 3
        if secondHalf > firstHalf + 0.3 {
            return "Sleep improved toward the end of the week."
        } else if secondHalf + 0.3 < firstHalf {
            return "Sleep dipped toward the end of the week."
        } else {
            return "Sleep was steady throughout the week."
        }
    }
}

// MARK: - HealthKit Manager

@MainActor
class HealthKitManager: ObservableObject {
    @Published var weeklySleepData: [SleepDayData] = []
    @Published var monthlySleepData: [SleepDayData] = []
    @Published var averageSleep: Double = 0
    @Published var sleepGoal: Double? = 8.0 // 8 hours goal
    
    private let healthStore = HKHealthStore()
    
    var averageSleepFormatted: String {
        let h = Int(averageSleep)
        let m = Int((averageSleep - Double(h)) * 60)
        return "\(h)h \(m)m"
    }
    
    var goalProgress: Int {
        guard let goal = sleepGoal else { return 0 }
        return min(100, Int((averageSleep / goal) * 100))
    }

    var monthlyAverage: Double {
        averageHours(for: monthlySleepData)
    }
    
    func requestAuthorization() async {
        guard HKHealthStore.isHealthDataAvailable() else {
            applyWeeklyMockData()
            applyMonthlyMockData()
            return
        }
        
        let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
        
        do {
            try await healthStore.requestAuthorization(toShare: [], read: [sleepType])
        } catch {
            print("HealthKit authorization failed: \(error)")
            applyWeeklyMockData()
            applyMonthlyMockData()
        }
    }
    
    func fetchWeeklySleepData() async {
        guard HKHealthStore.isHealthDataAvailable() else {
            applyWeeklyMockData()
            return
        }
        
        let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis)!
        let calendar = Calendar.current
        let now = Date()
        
        // Get last 7 days
        guard let startDate = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: now)) else {
            applyWeeklyMockData()
            return
        }
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: now, options: .strictStartDate)
        
        let query = HKSampleQuery(sampleType: sleepType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { [weak self] _, samples, error in
            guard let samples = samples as? [HKCategorySample] else {
                _Concurrency.Task { @MainActor in
                    self?.applyWeeklyMockData()
                }
                return
            }
            
            _Concurrency.Task { @MainActor in
                self?.processWeeklySamples(samples, days: 7)
            }
        }
        
        healthStore.execute(query)
    }

    func fetchMonthlySleepData() async {
        guard HKHealthStore.isHealthDataAvailable() else {
            applyMonthlyMockData()
            return
        }

        let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis)!
        let calendar = Calendar.current
        let now = Date()

        guard let startDate = calendar.date(byAdding: .day, value: -29, to: calendar.startOfDay(for: now)) else {
            applyMonthlyMockData()
            return
        }

        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: now, options: .strictStartDate)

        let query = HKSampleQuery(sampleType: sleepType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { [weak self] _, samples, error in
            guard let samples = samples as? [HKCategorySample] else {
                _Concurrency.Task { @MainActor in
                    self?.applyMonthlyMockData()
                }
                return
            }

            _Concurrency.Task { @MainActor in
                self?.processMonthlySamples(samples, days: 30)
            }
        }

        healthStore.execute(query)
    }

    private func processWeeklySamples(_ samples: [HKCategorySample], days: Int) {
        let data = buildSleepData(samples: samples, days: days)
        weeklySleepData = data
        averageSleep = averageHours(for: data)

        if averageSleep == 0 {
            applyWeeklyMockData()
        }
    }

    private func processMonthlySamples(_ samples: [HKCategorySample], days: Int) {
        let data = buildSleepData(samples: samples, days: days)
        monthlySleepData = data

        if monthlyAverage == 0 {
            applyMonthlyMockData()
        }
    }

    private func buildSleepData(samples: [HKCategorySample], days: Int) -> [SleepDayData] {
        let calendar = Calendar.current
        var dailySleep: [Date: TimeInterval] = [:]
        
        // Filter for asleep samples only
        let asleepSamples = samples.filter { sample in
            sample.value == HKCategoryValueSleepAnalysis.asleep.rawValue ||
            sample.value == HKCategoryValueSleepAnalysis.asleepCore.rawValue ||
            sample.value == HKCategoryValueSleepAnalysis.asleepDeep.rawValue ||
            sample.value == HKCategoryValueSleepAnalysis.asleepREM.rawValue
        }
        
        // Group by day
        for sample in asleepSamples {
            let day = calendar.startOfDay(for: sample.startDate)
            let duration = sample.endDate.timeIntervalSince(sample.startDate)
            dailySleep[day, default: 0] += duration
        }
        
        var data: [SleepDayData] = []
        let today = calendar.startOfDay(for: Date())
        
        for i in 0..<days {
            guard let day = calendar.date(byAdding: .day, value: -(days - 1) + i, to: today) else { continue }
            let sleepDuration = dailySleep[day] ?? 0
            let hours = sleepDuration / 3600
            
            let dayLabel = calendar.shortWeekdaySymbols[calendar.component(.weekday, from: day) - 1]
            let isToday = calendar.isDate(day, inSameDayAs: Date())
            
            data.append(SleepDayData(
                date: day,
                hours: hours,
                dayLabel: dayLabel,
                isToday: isToday
            ))
        }
        
        return data
    }

    private func averageHours(for data: [SleepDayData]) -> Double {
        guard !data.isEmpty else { return 0 }
        return data.map(\.hours).reduce(0, +) / Double(data.count)
    }

    private func applyWeeklyMockData() {
        weeklySleepData = mockSleepData(days: 7)
        averageSleep = averageHours(for: weeklySleepData)
    }

    private func applyMonthlyMockData() {
        monthlySleepData = mockSleepData(days: 30)
    }

    private func mockSleepData(days: Int) -> [SleepDayData] {
        let calendar = Calendar.current
        let today = Date()
        let baseHours: [Double] = [7.2, 6.8, 7.5, 8.1, 6.5, 7.8, 7.3]
        
        return (0..<days).compactMap { i in
            guard let day = calendar.date(byAdding: .day, value: -(days - 1) + i, to: today) else { return nil }
            let dayLabel = calendar.shortWeekdaySymbols[calendar.component(.weekday, from: day) - 1]
            let isToday = calendar.isDate(day, inSameDayAs: Date())
            let base = baseHours[i % baseHours.count]
            let variation = (i % 4 == 0) ? 0.2 : (i % 5 == 0 ? -0.2 : 0)
            let hours = max(4.5, min(9.5, base + variation))
            
            return SleepDayData(
                date: day,
                hours: hours,
                dayLabel: dayLabel,
                isToday: isToday
            )
        }
    }
}

// MARK: - Sleep Day Data

struct SleepDayData: Identifiable {
    let id = UUID()
    let date: Date
    let hours: Double
    let dayLabel: String
    let isToday: Bool
}

// MARK: - Preview

#Preview {
    NavigationStack {
        HealthInsightsView()
    }
}
