import Foundation
import HealthKit
import Combine

// MARK: - Extended Health Data Models

struct WeeklyDataPoint: Identifiable {
    let id = UUID()
    let label: String
    let value: Double
    let isToday: Bool
}

struct HeartRatePoint: Identifiable {
    let id = UUID()
    let time: Date
    let value: Double
}

struct HRVData {
    let current: Int
    let baseline: Int

    var status: String {
        if current > baseline + 5 { return "Above baseline" }
        if current < baseline - 5 { return "Below baseline" }
        return "Normal"
    }

    var statusColor: String {
        if current > baseline + 5 { return "green" }
        if current < baseline - 5 { return "orange" }
        return "secondary"
    }

    static let empty = HRVData(current: 0, baseline: 0)
}

struct SleepStagesData {
    let deep: Double
    let rem: Double
    let light: Double
    let awake: Double

    static let empty = SleepStagesData(deep: 0, rem: 0, light: 0, awake: 0)
}

struct SleepScheduleData {
    let avgBedtime: String
    let avgWakeTime: String

    static let empty = SleepScheduleData(avgBedtime: "--:--", avgWakeTime: "--:--")
}

// MARK: - HealthKit Service

@MainActor
final class HealthKitService: ObservableObject {
    static let shared = HealthKitService()

    private let healthStore = HKHealthStore()
    private(set) var isAuthorized = false

    // MARK: - Published Properties (Today)

    @Published var sleepData = SleepData.empty
    @Published var heartData = HeartData.empty
    @Published var exerciseData = ExerciseData.empty
    @Published var waterIntake = WaterIntake.empty
    @Published var isLoading = false
    @Published var lastUpdated: Date?

    // MARK: - Published Properties (Extended)

    @Published var weeklySleep: [WeeklyDataPoint] = []
    @Published var weeklySteps: [WeeklyDataPoint] = []
    @Published var weeklyCalories: [WeeklyDataPoint] = []
    @Published var weeklyWater: [WeeklyDataPoint] = []
    @Published var heartRateHistory: [HeartRatePoint] = []
    @Published var hrvData = HRVData.empty
    @Published var sleepStages = SleepStagesData.empty
    @Published var sleepSchedule = SleepScheduleData.empty
    @Published var floorsClimbed: Int = 0
    @Published var standHours: Int = 0

    // MARK: - Published Properties (Body & Fitness)

    @Published var bodyWeight: Double = 0
    @Published var vo2Max: Double = 0
    @Published var respiratoryRate: Double = 0
    @Published var mindfulMinutes: Int = 0

    // MARK: - HealthKit Types

    private var readTypes: Set<HKObjectType> {
        var types = Set<HKObjectType>()
        let identifiers: [HKQuantityTypeIdentifier] = [
            .heartRate, .restingHeartRate, .heartRateVariabilitySDNN,
            .stepCount, .activeEnergyBurned, .appleExerciseTime,
            .distanceWalkingRunning, .flightsClimbed, .dietaryWater,
            .bodyMass, .vo2Max, .respiratoryRate
        ]
        for id in identifiers {
            if let t = HKObjectType.quantityType(forIdentifier: id) { types.insert(t) }
        }
        if let sleep = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) { types.insert(sleep) }
        if let stand = HKObjectType.categoryType(forIdentifier: .appleStandHour) { types.insert(stand) }
        if let mindful = HKObjectType.categoryType(forIdentifier: .mindfulSession) { types.insert(mindful) }
        return types
    }

    private var writeTypes: Set<HKSampleType> {
        var types = Set<HKSampleType>()
        if let water = HKQuantityType.quantityType(forIdentifier: .dietaryWater) { types.insert(water) }
        return types
    }

    // MARK: - Initialization

    private init() {}

    // MARK: - Authorization

    func requestAuthorization() async -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else { return false }
        do {
            try await healthStore.requestAuthorization(toShare: writeTypes, read: readTypes)
            isAuthorized = true
            return true
        } catch {
            print("HealthKit authorization failed: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Fetch All Data

    func fetchAllHealthData() async {
        isLoading = true

        async let sleepTask: () = fetchSleepData()
        async let heartTask: () = fetchHeartData()
        async let activityTask: () = fetchActivityData()
        async let waterTask: () = fetchWaterIntake()
        async let weeklySleepTask: () = fetchWeeklySleep()
        async let weeklyStepsTask: () = fetchWeeklySteps()
        async let weeklyCaloriesTask: () = fetchWeeklyCalories()
        async let weeklyWaterTask: () = fetchWeeklyWater()
        async let hrHistoryTask: () = fetchHeartRateHistory()
        async let hrvTask: () = fetchHRV()
        async let floorsTask: () = fetchFloorsClimbed()
        async let standTask: () = fetchStandHours()
        async let weightTask: () = fetchBodyWeight()
        async let vo2Task: () = fetchVO2Max()
        async let respTask: () = fetchRespiratoryRate()
        async let mindfulTask: () = fetchMindfulMinutes()

        _ = await (sleepTask, heartTask, activityTask, waterTask,
                   weeklySleepTask, weeklyStepsTask, weeklyCaloriesTask, weeklyWaterTask,
                   hrHistoryTask, hrvTask, floorsTask, standTask,
                   weightTask, vo2Task, respTask, mindfulTask)

        lastUpdated = Date()
        isLoading = false
    }

    // MARK: - Sleep Data

    private func fetchSleepData() async {
        guard HKHealthStore.isHealthDataAvailable(),
              let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) else { return }

        let calendar = Calendar.current
        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)
        guard let startOfYesterday = calendar.date(byAdding: .day, value: -1, to: startOfToday) else { return }

        let predicate = HKQuery.predicateForSamples(withStart: startOfYesterday, end: now, options: .strictStartDate)

        let samples: [HKCategorySample] = await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: sleepType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)]
            ) { _, results, _ in
                continuation.resume(returning: (results as? [HKCategorySample]) ?? [])
            }
            healthStore.execute(query)
        }

        guard !samples.isEmpty else { return }
        processSleepSamples(samples)
    }

    private func processSleepSamples(_ samples: [HKCategorySample]) {
        var totalSleep: TimeInterval = 0
        var deep: TimeInterval = 0
        var rem: TimeInterval = 0
        var light: TimeInterval = 0
        var awake: TimeInterval = 0
        var bedtimes: [Date] = []
        var wakeTimes: [Date] = []
        var sleepStarts: [Date] = []  // Fallback for schedule from actual sleep samples
        var sleepEnds: [Date] = []

        let sleepValues: Set<Int> = [
            HKCategoryValueSleepAnalysis.asleepCore.rawValue,
            HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
            HKCategoryValueSleepAnalysis.asleepREM.rawValue,
            HKCategoryValueSleepAnalysis.asleep.rawValue
        ]

        for sample in samples {
            let duration = sample.endDate.timeIntervalSince(sample.startDate)

            switch sample.value {
            case HKCategoryValueSleepAnalysis.asleepCore.rawValue:
                totalSleep += duration
                light += duration
                sleepStarts.append(sample.startDate)
                sleepEnds.append(sample.endDate)
            case HKCategoryValueSleepAnalysis.asleepDeep.rawValue:
                totalSleep += duration
                deep += duration
                sleepStarts.append(sample.startDate)
                sleepEnds.append(sample.endDate)
            case HKCategoryValueSleepAnalysis.asleepREM.rawValue:
                totalSleep += duration
                rem += duration
                sleepStarts.append(sample.startDate)
                sleepEnds.append(sample.endDate)
            case HKCategoryValueSleepAnalysis.asleep.rawValue:
                totalSleep += duration
                light += duration
                sleepStarts.append(sample.startDate)
                sleepEnds.append(sample.endDate)
            case HKCategoryValueSleepAnalysis.awake.rawValue:
                awake += duration
            case HKCategoryValueSleepAnalysis.inBed.rawValue:
                bedtimes.append(sample.startDate)
                wakeTimes.append(sample.endDate)
            default:
                break
            }
        }

        let hours = totalSleep / 3600
        let quality = calculateSleepQuality(total: hours, deep: deep / 3600, rem: rem / 3600)

        sleepData = SleepData(hours: hours, quality: quality, deepSleep: deep / 3600, remSleep: rem / 3600)
        sleepStages = SleepStagesData(deep: deep / 3600, rem: rem / 3600, light: light / 3600, awake: awake / 3600)

        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"

        // Use inBed samples if available, otherwise fall back to actual sleep stage timestamps
        let effectiveBedtime = bedtimes.min() ?? sleepStarts.min()
        let effectiveWake = wakeTimes.max() ?? sleepEnds.max()

        if let bedtime = effectiveBedtime {
            let avgBedtime = formatter.string(from: bedtime)
            let avgWake = effectiveWake.map { formatter.string(from: $0) } ?? "--:--"
            sleepSchedule = SleepScheduleData(avgBedtime: avgBedtime, avgWakeTime: avgWake)
        }
    }

    private func calculateSleepQuality(total: Double, deep: Double, rem: Double) -> Int {
        var score = 0

        if total >= 7 && total <= 9 { score += 50 }
        else if total >= 6 && total < 7 { score += 40 }
        else if total >= 5 && total < 6 { score += 30 }
        else { score += Int(total * 5) }

        let deepPercent = total > 0 ? (deep / total) * 100 : 0
        if deepPercent >= 13 && deepPercent <= 23 { score += 25 }
        else if deepPercent >= 10 { score += 15 }
        else { score += Int(deepPercent) }

        let remPercent = total > 0 ? (rem / total) * 100 : 0
        if remPercent >= 20 && remPercent <= 25 { score += 25 }
        else if remPercent >= 15 { score += 15 }
        else { score += Int(remPercent) }

        return min(100, max(0, score))
    }

    // MARK: - Weekly Sleep

    private func fetchWeeklySleep() async {
        guard let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) else { return }

        let calendar = Calendar.current
        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)
        // Use -6 days for a 7-day window (matching fetchWeeklySum behavior)
        guard let startDate = calendar.date(byAdding: .day, value: -6, to: startOfToday) else { return }

        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: now, options: .strictStartDate)

        let samples: [HKCategorySample] = await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: sleepType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: true)]
            ) { _, results, _ in
                continuation.resume(returning: (results as? [HKCategorySample]) ?? [])
            }
            healthStore.execute(query)
        }

        // Key by yyyy-MM-dd to avoid weekday name collisions across weeks
        let dateKeyFormatter = DateFormatter()
        dateKeyFormatter.dateFormat = "yyyy-MM-dd"
        let dayLabelFormatter = DateFormatter()
        dayLabelFormatter.dateFormat = "EEE"

        let sleepValues: Set<Int> = [
            HKCategoryValueSleepAnalysis.asleepCore.rawValue,
            HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
            HKCategoryValueSleepAnalysis.asleepREM.rawValue,
            HKCategoryValueSleepAnalysis.asleep.rawValue
        ]

        var dailyTotals: [String: Double] = [:]
        for sample in samples {
            guard sleepValues.contains(sample.value) else { continue }
            let duration = sample.endDate.timeIntervalSince(sample.startDate) / 3600
            let key = dateKeyFormatter.string(from: sample.endDate)
            dailyTotals[key, default: 0] += duration
        }

        var points: [WeeklyDataPoint] = []
        for i in 0..<7 {
            guard let date = calendar.date(byAdding: .day, value: i, to: startDate) else { continue }
            let dateKey = dateKeyFormatter.string(from: date)
            let label = dayLabelFormatter.string(from: date)
            let value = dailyTotals[dateKey] ?? 0
            let isToday = calendar.isDateInToday(date)
            points.append(WeeklyDataPoint(label: label, value: round(value * 10) / 10, isToday: isToday))
        }
        weeklySleep = points
    }

    // MARK: - Heart Data

    private func fetchHeartData() async {
        guard HKHealthStore.isHealthDataAvailable() else { return }

        async let currentHR = fetchLatestHeartRate()
        async let restingHR = fetchRestingHeartRate()
        async let stats = fetchHeartRateStats()

        let (current, resting, (average, peak)) = await (currentHR, restingHR, stats)

        heartData = HeartData(
            current: current,
            resting: resting,
            max: peak,
            average: average
        )
    }

    private func fetchLatestHeartRate() async -> Int {
        guard let heartType = HKQuantityType.quantityType(forIdentifier: .heartRate) else { return 0 }
        // Only show heart rate from the last 24 hours so stale data doesn't appear as "current"
        let predicate = HKQuery.predicateForSamples(
            withStart: Calendar.current.date(byAdding: .hour, value: -24, to: Date()),
            end: Date(), options: .strictStartDate
        )
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: heartType, predicate: predicate, limit: 1,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)]
            ) { _, samples, _ in
                let hr = (samples?.first as? HKQuantitySample)?
                    .quantity.doubleValue(for: HKUnit(from: "count/min"))
                continuation.resume(returning: Int(hr ?? 0))
            }
            healthStore.execute(query)
        }
    }

    private func fetchRestingHeartRate() async -> Int {
        guard let restingType = HKQuantityType.quantityType(forIdentifier: .restingHeartRate) else { return 0 }
        // Only show resting HR from the last 7 days so stale data doesn't appear
        let predicate = HKQuery.predicateForSamples(
            withStart: Calendar.current.date(byAdding: .day, value: -7, to: Date()),
            end: Date(), options: .strictStartDate
        )
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: restingType, predicate: predicate, limit: 1,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)]
            ) { _, samples, _ in
                let hr = (samples?.first as? HKQuantitySample)?
                    .quantity.doubleValue(for: HKUnit(from: "count/min"))
                continuation.resume(returning: Int(hr ?? 0))
            }
            healthStore.execute(query)
        }
    }

    private func fetchHeartRateStats() async -> (average: Int, peak: Int) {
        guard let heartType = HKQuantityType.quantityType(forIdentifier: .heartRate) else { return (0, 0) }
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: Date(), options: .strictStartDate)

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: heartType,
                quantitySamplePredicate: predicate,
                options: [.discreteAverage, .discreteMax]
            ) { _, statistics, _ in
                let unit = HKUnit(from: "count/min")
                let avg = Int(statistics?.averageQuantity()?.doubleValue(for: unit) ?? 0)
                let peak = Int(statistics?.maximumQuantity()?.doubleValue(for: unit) ?? 0)
                continuation.resume(returning: (avg, peak))
            }
            healthStore.execute(query)
        }
    }

    // MARK: - Heart Rate History (24h)

    private func fetchHeartRateHistory() async {
        guard let heartType = HKQuantityType.quantityType(forIdentifier: .heartRate) else { return }
        let calendar = Calendar.current
        guard let start = calendar.date(byAdding: .hour, value: -24, to: Date()) else { return }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date(), options: .strictStartDate)

        let samples: [HKQuantitySample] = await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: heartType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: true)]
            ) { _, results, _ in
                continuation.resume(returning: (results as? [HKQuantitySample]) ?? [])
            }
            healthStore.execute(query)
        }

        let unit = HKUnit(from: "count/min")
        heartRateHistory = samples.map { sample in
            HeartRatePoint(time: sample.endDate, value: sample.quantity.doubleValue(for: unit))
        }
    }

    // MARK: - HRV

    private func fetchHRV() async {
        guard let hrvType = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else { return }

        let latest = await fetchLatestSample(type: hrvType, unit: .secondUnit(with: .milli))
        guard latest > 0 else { return }

        let calendar = Calendar.current
        guard let weekAgo = calendar.date(byAdding: .day, value: -7, to: Date()) else { return }
        let predicate = HKQuery.predicateForSamples(withStart: weekAgo, end: Date(), options: .strictStartDate)

        let baseline: Int = await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: hrvType,
                quantitySamplePredicate: predicate,
                options: .discreteAverage
            ) { _, statistics, _ in
                let avg = statistics?.averageQuantity()?.doubleValue(for: .secondUnit(with: .milli))
                continuation.resume(returning: Int(avg ?? 0))
            }
            healthStore.execute(query)
        }

        hrvData = HRVData(current: Int(latest), baseline: baseline > 0 ? baseline : Int(latest))
    }

    private func fetchLatestSample(type: HKQuantityType, unit: HKUnit) async -> Double {
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type, predicate: nil, limit: 1,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)]
            ) { _, samples, _ in
                let val = (samples?.first as? HKQuantitySample)?.quantity.doubleValue(for: unit)
                continuation.resume(returning: val ?? 0)
            }
            healthStore.execute(query)
        }
    }

    // MARK: - Activity Data

    private func fetchActivityData() async {
        guard HKHealthStore.isHealthDataAvailable() else { return }

        async let stepsCount = fetchTodaySteps()
        async let caloriesCount = fetchTodayCalories()
        async let exerciseMins = fetchTodayExerciseMinutes()
        async let distanceCount = fetchTodayDistance()

        let (steps, calories, minutes, distance) = await (stepsCount, caloriesCount, exerciseMins, distanceCount)

        exerciseData = ExerciseData(steps: steps, calories: calories, minutes: minutes, distance: distance)
    }

    private func fetchTodaySteps() async -> Int {
        guard let t = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return 0 }
        return await fetchTodaySum(for: t, unit: .count())
    }

    private func fetchTodayCalories() async -> Int {
        guard let t = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) else { return 0 }
        return await fetchTodaySum(for: t, unit: .kilocalorie())
    }

    private func fetchTodayExerciseMinutes() async -> Int {
        guard let t = HKQuantityType.quantityType(forIdentifier: .appleExerciseTime) else { return 0 }
        return await fetchTodaySum(for: t, unit: .minute())
    }

    private func fetchTodayDistance() async -> Double {
        guard let t = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning) else { return 0 }
        let calendar = Calendar.current
        let predicate = HKQuery.predicateForSamples(
            withStart: calendar.startOfDay(for: Date()), end: Date(), options: .strictStartDate
        )
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: t, quantitySamplePredicate: predicate, options: .cumulativeSum
            ) { _, statistics, _ in
                let d = statistics?.sumQuantity()?.doubleValue(for: .mile()) ?? 0
                continuation.resume(returning: round(d * 10) / 10)
            }
            healthStore.execute(query)
        }
    }

    private func fetchTodaySum(for type: HKQuantityType, unit: HKUnit) async -> Int {
        let calendar = Calendar.current
        let predicate = HKQuery.predicateForSamples(
            withStart: calendar.startOfDay(for: Date()), end: Date(), options: .strictStartDate
        )
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum
            ) { _, statistics, _ in
                let v = statistics?.sumQuantity()?.doubleValue(for: unit) ?? 0
                continuation.resume(returning: Int(v))
            }
            healthStore.execute(query)
        }
    }

    // MARK: - Floors Climbed

    private func fetchFloorsClimbed() async {
        guard let t = HKQuantityType.quantityType(forIdentifier: .flightsClimbed) else { return }
        floorsClimbed = await fetchTodaySum(for: t, unit: .count())
    }

    // MARK: - Stand Hours

    private func fetchStandHours() async {
        guard let standType = HKCategoryType.categoryType(forIdentifier: .appleStandHour) else { return }
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: Date(), options: .strictStartDate)

        let count: Int = await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: standType, predicate: predicate,
                limit: HKObjectQueryNoLimit, sortDescriptors: nil
            ) { _, samples, _ in
                let stood = (samples as? [HKCategorySample])?.filter {
                    $0.value == HKCategoryValueAppleStandHour.stood.rawValue
                }.count ?? 0
                continuation.resume(returning: stood)
            }
            healthStore.execute(query)
        }
        standHours = count
    }

    // MARK: - Weekly Steps

    private func fetchWeeklySteps() async {
        guard let stepsType = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return }
        weeklySteps = await fetchWeeklySum(for: stepsType, unit: .count())
    }

    // MARK: - Weekly Calories

    private func fetchWeeklyCalories() async {
        guard let type = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) else { return }
        weeklyCalories = await fetchWeeklySum(for: type, unit: .kilocalorie())
    }

    // MARK: - Weekly Water

    private func fetchWeeklyWater() async {
        guard let waterType = HKQuantityType.quantityType(forIdentifier: .dietaryWater) else { return }
        let raw = await fetchWeeklySum(for: waterType, unit: .liter())
        // Convert liters to glasses (1 glass = 0.25L) using consistent Int truncation
        // matching fetchWaterIntake which uses Int(liters / 0.25)
        weeklyWater = raw.map {
            WeeklyDataPoint(label: $0.label, value: Double(Int($0.value / 0.25)), isToday: $0.isToday)
        }
    }

    private func fetchWeeklySum(for type: HKQuantityType, unit: HKUnit) async -> [WeeklyDataPoint] {
        let calendar = Calendar.current
        let now = Date()
        guard let startDate = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: now)) else {
            return []
        }
        let anchorDate = calendar.startOfDay(for: startDate)
        let interval = DateComponents(day: 1)

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsCollectionQuery(
                quantityType: type,
                quantitySamplePredicate: HKQuery.predicateForSamples(
                    withStart: anchorDate, end: now, options: .strictStartDate
                ),
                options: .cumulativeSum,
                anchorDate: anchorDate,
                intervalComponents: interval
            )
            query.initialResultsHandler = { _, collection, _ in
                var points: [WeeklyDataPoint] = []
                let dayFormatter = DateFormatter()
                dayFormatter.dateFormat = "EEE"
                let todayLabel = dayFormatter.string(from: now)

                collection?.enumerateStatistics(from: anchorDate, to: now) { stats, _ in
                    let value = stats.sumQuantity()?.doubleValue(for: unit) ?? 0
                    let label = dayFormatter.string(from: stats.startDate)
                    points.append(WeeklyDataPoint(label: label, value: round(value * 10) / 10, isToday: label == todayLabel))
                }
                continuation.resume(returning: points)
            }
            healthStore.execute(query)
        }
    }

    // MARK: - Water Intake (Today)

    private func fetchWaterIntake() async {
        guard let waterType = HKQuantityType.quantityType(forIdentifier: .dietaryWater) else { return }
        let calendar = Calendar.current
        let predicate = HKQuery.predicateForSamples(
            withStart: calendar.startOfDay(for: Date()), end: Date(), options: .strictStartDate
        )

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            let query = HKStatisticsQuery(
                quantityType: waterType, quantitySamplePredicate: predicate, options: .cumulativeSum
            ) { [weak self] _, statistics, _ in
                DispatchQueue.main.async {
                    if let sum = statistics?.sumQuantity() {
                        let glasses = Int(sum.doubleValue(for: .liter()) / 0.25)
                        self?.waterIntake = WaterIntake(current: glasses, goal: 8)
                    }
                    continuation.resume(returning: ())
                }
            }
            healthStore.execute(query)
        }
    }

    // MARK: - Log Water

    func logWater(glasses: Int = 1) async -> Bool {
        guard let waterType = HKQuantityType.quantityType(forIdentifier: .dietaryWater) else { return false }
        let quantity = HKQuantity(unit: .liter(), doubleValue: Double(glasses) * 0.25)
        let sample = HKQuantitySample(type: waterType, quantity: quantity, start: Date(), end: Date())

        do {
            try await healthStore.save(sample)
            await fetchWaterIntake()
            await fetchWeeklyWater()
            return true
        } catch {
            print("Failed to log water: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Body Weight

    private func fetchBodyWeight() async {
        guard let t = HKQuantityType.quantityType(forIdentifier: .bodyMass) else { return }
        let val = await fetchLatestSample(type: t, unit: .pound())
        bodyWeight = round(val * 10) / 10
    }

    // MARK: - VO2 Max

    private func fetchVO2Max() async {
        guard let t = HKQuantityType.quantityType(forIdentifier: .vo2Max) else { return }
        let unit = HKUnit.literUnit(with: .milli).unitDivided(by: HKUnit.gramUnit(with: .kilo).unitMultiplied(by: .minute()))
        vo2Max = round(await fetchLatestSample(type: t, unit: unit) * 10) / 10
    }

    // MARK: - Respiratory Rate

    private func fetchRespiratoryRate() async {
        guard let t = HKQuantityType.quantityType(forIdentifier: .respiratoryRate) else { return }
        respiratoryRate = round(await fetchLatestSample(type: t, unit: HKUnit(from: "count/min")) * 10) / 10
    }

    // MARK: - Mindful Minutes

    private func fetchMindfulMinutes() async {
        guard let mindfulType = HKCategoryType.categoryType(forIdentifier: .mindfulSession) else { return }
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: Date(), options: .strictStartDate)

        let minutes: Int = await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: mindfulType, predicate: predicate,
                limit: HKObjectQueryNoLimit, sortDescriptors: nil
            ) { _, samples, _ in
                let total = (samples as? [HKCategorySample])?.reduce(0.0) { sum, sample in
                    sum + sample.endDate.timeIntervalSince(sample.startDate)
                } ?? 0
                continuation.resume(returning: Int(total / 60))
            }
            healthStore.execute(query)
        }
        mindfulMinutes = minutes
    }

    // MARK: - Wellness Score (Computed)

    var wellnessScore: Int {
        var score = 0
        var factors = 0

        if sleepData.hours > 0 {
            factors += 1
            let sleepScore = min(100, Int((sleepData.hours / 8.0) * 100))
            score += min(sleepScore, 100)
        }
        if exerciseData.steps > 0 {
            factors += 1
            score += min(Int(Double(exerciseData.steps) / 10000.0 * 100), 100)
        }
        if heartData.resting > 0 {
            factors += 1
            let hrScore = heartData.resting <= 60 ? 100 : heartData.resting <= 80 ? 75 : 50
            score += hrScore
        }
        if waterIntake.current > 0 {
            factors += 1
            score += min(Int(Double(waterIntake.current) / Double(waterIntake.goal) * 100), 100)
        }
        if exerciseData.minutes > 0 {
            factors += 1
            score += min(Int(Double(exerciseData.minutes) / 30.0 * 100), 100)
        }

        return factors > 0 ? score / factors : 0
    }

    // MARK: - Goal Streaks (Computed)

    var stepsStreak: Int {
        weeklySteps.reversed().prefix(while: { $0.value >= 10000 }).count
    }

    var sleepStreak: Int {
        weeklySleep.reversed().prefix(while: { $0.value >= 7 }).count
    }

    var waterStreak: Int {
        weeklyWater.reversed().prefix(while: { $0.value >= 8 }).count
    }

    // MARK: - Personal Bests (Computed from weekly)

    var bestStepsDay: (label: String, value: Int)? {
        guard let best = weeklySteps.max(by: { $0.value < $1.value }), best.value > 0 else { return nil }
        return (best.label, Int(best.value))
    }

    var bestSleepDay: (label: String, value: Double)? {
        guard let best = weeklySleep.max(by: { $0.value < $1.value }), best.value > 0 else { return nil }
        return (best.label, best.value)
    }

    // MARK: - Fitness Score (0–100)

    var fitnessScore: Int {
        var total = 0
        var weight = 0

        if exerciseData.steps > 0 {
            total += min(100, Int(Double(exerciseData.steps) / 10000.0 * 100)) * 35
            weight += 35
        }
        if exerciseData.minutes > 0 {
            total += min(100, Int(Double(exerciseData.minutes) / 30.0 * 100)) * 25
            weight += 25
        }
        if vo2Max > 0 {
            let v = vo2Max >= 50 ? 100 : vo2Max >= 40 ? 80 : vo2Max >= 30 ? 60 : 40
            total += v * 20
            weight += 20
        }
        if heartData.resting > 0 {
            let h = heartData.resting <= 60 ? 100 : heartData.resting <= 80 ? 75 : 50
            total += h * 20
            weight += 20
        }
        return weight > 0 ? total / weight : 0
    }

    // MARK: - Cardio Fitness Level (Computed from VO2 Max)

    var cardioFitnessLevel: String {
        guard vo2Max > 0 else { return "No data" }
        if vo2Max >= 50 { return "High" }
        if vo2Max >= 40 { return "Above Average" }
        if vo2Max >= 30 { return "Average" }
        return "Below Average"
    }

    // MARK: - Computed Insights

    var sleepInsights: [String] {
        var insights: [String] = []
        let avg = weeklySleep.map(\.value).reduce(0, +) / max(Double(weeklySleep.count), 1)

        if sleepData.hours > 0 {
            let diff = sleepData.hours - avg
            if abs(diff) > 0.5 {
                let direction = diff > 0 ? "more" : "less"
                insights.append("You slept \(String(format: "%.0f", abs(diff * 60))) min \(direction) than your average.")
            }

            if sleepData.quality >= 80 {
                insights.append("Great sleep quality last night!")
            } else if sleepData.quality < 60 {
                insights.append("Sleep quality was low. Try a consistent bedtime.")
            }

            let consistency = weeklySleep.filter { $0.value >= 7 && $0.value <= 9 }.count
            insights.append("Sleep consistency: \(consistency)/\(weeklySleep.count) nights in ideal range.")
        }

        if insights.isEmpty { insights.append("Start tracking sleep for personalized insights.") }
        return insights
    }

    var heartInsights: [String] {
        var insights: [String] = []
        if heartData.resting > 0 {
            if heartData.resting < 60 { insights.append("Resting heart rate is in an athletic range.") }
            else if heartData.resting <= 80 { insights.append("Resting heart rate is in a healthy range.") }
            else { insights.append("Resting heart rate is elevated. Consider relaxation.") }
        }
        if hrvData.current > 0 {
            insights.append("HRV is \(hrvData.status.lowercased()) (\(hrvData.current) ms).")
        }
        if heartData.max > 0 {
            insights.append("Peak heart rate today: \(heartData.max) bpm.")
        }
        if insights.isEmpty { insights.append("Wear your watch to track heart rate.") }
        return insights
    }

    var activityInsights: [String] {
        var insights: [String] = []
        let avgSteps = weeklySteps.map(\.value).reduce(0, +) / max(Double(weeklySteps.count), 1)

        if exerciseData.steps > 0 {
            if Double(exerciseData.steps) > avgSteps * 1.1 {
                insights.append("Above your average step count today!")
            } else if Double(exerciseData.steps) < avgSteps * 0.7 {
                insights.append("Steps are below average. A short walk helps.")
            }
        }
        if exerciseData.minutes >= 30 {
            insights.append("Exercise goal reached!")
        } else if exerciseData.minutes > 0 {
            insights.append("\(30 - exerciseData.minutes) more minutes to hit your exercise goal.")
        }
        if floorsClimbed > 0 {
            insights.append("Climbed \(floorsClimbed) flights today.")
        }
        if insights.isEmpty { insights.append("Start moving to see activity insights.") }
        return insights
    }

    var hydrationInsights: [String] {
        var insights: [String] = []
        let avgGlasses = weeklyWater.map(\.value).reduce(0, +) / max(Double(weeklyWater.count), 1)
        let remaining = max(0, waterIntake.goal - waterIntake.current)

        if remaining == 0 {
            insights.append("Hydration goal reached!")
        } else if remaining > 0 {
            insights.append("\(remaining) more glasses to reach your goal.")
        }
        if avgGlasses > 0 {
            let daysMetGoal = weeklyWater.filter { $0.value >= 8 }.count
            insights.append("You met your water goal \(daysMetGoal)/\(weeklyWater.count) days this week.")
        }
        insights.append("Aim for a glass every 2 hours.")
        return insights
    }
}
