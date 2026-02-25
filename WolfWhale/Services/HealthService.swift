import Foundation
import HealthKit
import Observation

// MARK: - Models

nonisolated struct WellnessData: Sendable {
    let steps: Int
    let distance: Double // meters
    let activeCalories: Double
    let restingHeartRate: Double?
    let sleepHours: Double?
    let wellnessScore: Int
    let weeklySteps: [DailyStepCount]
}

nonisolated struct DailyStepCount: Identifiable, Hashable, Sendable {
    let id: UUID
    let date: Date
    let steps: Int
}

nonisolated struct PEWorkout: Identifiable, Hashable, Sendable {
    let id: UUID
    let activityType: String
    let startDate: Date
    let endDate: Date
    let caloriesBurned: Double
    let distance: Double?
    let averageHeartRate: Double?
}

// MARK: - HealthService

@MainActor
@Observable
final class HealthService {
    var error: String?
    var isLoading = false
    var isAuthorized = false
    var wellnessData: WellnessData?
    var workoutHistory: [PEWorkout] = []
    var isWorkoutActive = false
    var activeWorkoutStart: Date?
    var hydrationGlasses: Int = 0

    private let healthStore = HKHealthStore()
    private var workoutSession: HKWorkoutBuilder?

    private let hydrationKey = "com.wolfwhale.hydrationGlasses"
    private let hydrationDateKey = "com.wolfwhale.hydrationDate"

    init() {
        loadHydration()
    }

    // MARK: - Authorization

    func requestAuthorization() async {
        guard HKHealthStore.isHealthDataAvailable() else {
            error = "HealthKit is not available on this device."
            return
        }

        var readTypes: Set<HKObjectType> = [HKObjectType.workoutType()]
        if let stepCount = HKQuantityType.quantityType(forIdentifier: .stepCount) { readTypes.insert(stepCount) }
        if let distance = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning) { readTypes.insert(distance) }
        if let energy = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) { readTypes.insert(energy) }
        if let heartRate = HKQuantityType.quantityType(forIdentifier: .heartRate) { readTypes.insert(heartRate) }
        if let restingHR = HKQuantityType.quantityType(forIdentifier: .restingHeartRate) { readTypes.insert(restingHR) }
        if let sleep = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) { readTypes.insert(sleep) }

        var writeTypes: Set<HKSampleType> = [HKObjectType.workoutType()]
        if let energy = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) { writeTypes.insert(energy) }

        do {
            try await healthStore.requestAuthorization(toShare: writeTypes, read: readTypes)
            isAuthorized = true
            await loadAllData()
        } catch {
            self.error = "Authorization failed: \(error.localizedDescription)"
            isAuthorized = false
        }
    }

    // MARK: - Load All Data

    func loadAllData() async {
        isLoading = true
        error = nil

        async let stepsResult = fetchTodaySteps()
        async let distanceResult = fetchTodayDistance()
        async let caloriesResult = fetchTodayActiveCalories()
        async let heartRateResult = fetchRestingHeartRate()
        async let sleepResult = fetchSleepHours()
        async let weeklyResult = fetchWeeklySteps()
        async let workoutsResult = fetchWorkoutHistory()

        let steps = await stepsResult
        let distance = await distanceResult
        let calories = await caloriesResult
        let heartRate = await heartRateResult
        let sleep = await sleepResult
        let weekly = await weeklyResult
        let workouts = await workoutsResult

        let score = calculateWellnessScore(
            steps: steps,
            activeCalories: calories,
            sleepHours: sleep
        )

        wellnessData = WellnessData(
            steps: steps,
            distance: distance,
            activeCalories: calories,
            restingHeartRate: heartRate,
            sleepHours: sleep,
            wellnessScore: score,
            weeklySteps: weekly
        )

        workoutHistory = workouts
        isLoading = false
    }

    // MARK: - Today's Step Count

    private func fetchTodaySteps() async -> Int {
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return 0 }

        let predicate = todayPredicate()
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: stepType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, statistics, error in
                if let error {
                    Task { @MainActor in
                        self.error = "Steps fetch failed: \(error.localizedDescription)"
                    }
                    continuation.resume(returning: 0)
                    return
                }
                let steps = statistics?.sumQuantity()?.doubleValue(for: .count()) ?? 0
                continuation.resume(returning: Int(steps))
            }
            healthStore.execute(query)
        }
    }

    // MARK: - Today's Distance

    private func fetchTodayDistance() async -> Double {
        guard let distanceType = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning) else { return 0 }

        let predicate = todayPredicate()
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: distanceType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, statistics, _ in
                let distance = statistics?.sumQuantity()?.doubleValue(for: .meter()) ?? 0
                continuation.resume(returning: distance)
            }
            healthStore.execute(query)
        }
    }

    // MARK: - Today's Active Calories

    private func fetchTodayActiveCalories() async -> Double {
        guard let calorieType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) else { return 0 }

        let predicate = todayPredicate()
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: calorieType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, statistics, _ in
                let calories = statistics?.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0
                continuation.resume(returning: calories)
            }
            healthStore.execute(query)
        }
    }

    // MARK: - Resting Heart Rate

    private func fetchRestingHeartRate() async -> Double? {
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .restingHeartRate) else { return nil }

        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: heartRateType,
                predicate: nil,
                limit: 1,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, _ in
                guard let sample = samples?.first as? HKQuantitySample else {
                    continuation.resume(returning: nil)
                    return
                }
                let bpm = sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
                continuation.resume(returning: bpm)
            }
            healthStore.execute(query)
        }
    }

    // MARK: - Sleep Data

    private func fetchSleepHours() async -> Double? {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return nil }

        let calendar = Calendar.current
        let now = Date()
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: now) else { return nil }
        let startOfYesterday = calendar.startOfDay(for: yesterday)
        let predicate = HKQuery.predicateForSamples(withStart: startOfYesterday, end: now, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: sleepType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, _ in
                guard let sleepSamples = samples as? [HKCategorySample] else {
                    continuation.resume(returning: nil)
                    return
                }

                let asleepValues: Set<Int> = [
                    HKCategoryValueSleepAnalysis.asleepCore.rawValue,
                    HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
                    HKCategoryValueSleepAnalysis.asleepREM.rawValue,
                    HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue
                ]

                var totalSleep: TimeInterval = 0
                for sample in sleepSamples {
                    if asleepValues.contains(sample.value) {
                        totalSleep += sample.endDate.timeIntervalSince(sample.startDate)
                    }
                }

                let hours = totalSleep / 3600.0
                continuation.resume(returning: hours > 0 ? hours : nil)
            }
            healthStore.execute(query)
        }
    }

    // MARK: - Weekly Steps (7-Day Trend)

    private func fetchWeeklySteps() async -> [DailyStepCount] {
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return [] }

        let calendar = Calendar.current
        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)
        guard let sevenDaysAgo = calendar.date(byAdding: .day, value: -6, to: startOfToday) else { return [] }

        let predicate = HKQuery.predicateForSamples(withStart: sevenDaysAgo, end: now, options: .strictStartDate)
        let interval = DateComponents(day: 1)

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsCollectionQuery(
                quantityType: stepType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum,
                anchorDate: sevenDaysAgo,
                intervalComponents: interval
            )

            query.initialResultsHandler = { _, results, error in
                guard let results, error == nil else {
                    continuation.resume(returning: [])
                    return
                }

                var dailySteps: [DailyStepCount] = []
                results.enumerateStatistics(from: sevenDaysAgo, to: now) { statistics, _ in
                    let steps = statistics.sumQuantity()?.doubleValue(for: .count()) ?? 0
                    let entry = DailyStepCount(
                        id: UUID(),
                        date: statistics.startDate,
                        steps: Int(steps)
                    )
                    dailySteps.append(entry)
                }
                continuation.resume(returning: dailySteps)
            }

            healthStore.execute(query)
        }
    }

    // MARK: - Workout History

    private func fetchWorkoutHistory() async -> [PEWorkout] {
        let workoutType = HKObjectType.workoutType()
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: workoutType,
                predicate: nil,
                limit: 20,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, _ in
                guard let workouts = samples as? [HKWorkout] else {
                    continuation.resume(returning: [])
                    return
                }

                let peWorkouts = workouts.map { workout in
                    PEWorkout(
                        id: UUID(),
                        activityType: Self.workoutActivityName(workout.workoutActivityType),
                        startDate: workout.startDate,
                        endDate: workout.endDate,
                        caloriesBurned: workout.statistics(for: HKQuantityType(.activeEnergyBurned))?.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0,
                        distance: workout.statistics(for: HKQuantityType(.distanceWalkingRunning))?.sumQuantity()?.doubleValue(for: .meter()),
                        averageHeartRate: nil
                    )
                }
                continuation.resume(returning: peWorkouts)
            }
            healthStore.execute(query)
        }
    }

    // MARK: - PE Workout Session

    func startPEWorkout(activityType: HKWorkoutActivityType = .functionalStrengthTraining) async {
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = activityType
        configuration.locationType = .indoor

        do {
            let builder = HKWorkoutBuilder(healthStore: healthStore, configuration: configuration, device: .local())
            try await builder.beginCollection(at: Date())
            workoutSession = builder
            activeWorkoutStart = Date()
            isWorkoutActive = true
        } catch {
            self.error = "Failed to start workout: \(error.localizedDescription)"
        }
    }

    func stopPEWorkout() async {
        guard let builder = workoutSession else {
            error = "No active workout to stop."
            return
        }

        do {
            try await builder.endCollection(at: Date())
            try await builder.finishWorkout()
            workoutSession = nil
            isWorkoutActive = false
            activeWorkoutStart = nil
            await loadAllData()
        } catch {
            self.error = "Failed to stop workout: \(error.localizedDescription)"
        }
    }

    // MARK: - Wellness Score Calculation

    /// Calculates a 0-100 wellness score based on activity levels vs. daily recommendations.
    /// - Steps: target 10,000 (40 pts max)
    /// - Active Calories: target 400 kcal (30 pts max)
    /// - Sleep: target 8 hours (30 pts max)
    private func calculateWellnessScore(steps: Int, activeCalories: Double, sleepHours: Double?) -> Int {
        let stepScore = min(Double(steps) / 10_000.0, 1.0) * 40.0
        let calorieScore = min(activeCalories / 400.0, 1.0) * 30.0

        var sleepScore: Double = 0
        if let sleep = sleepHours, sleep > 0 {
            // Optimal range: 7-9 hours
            if sleep >= 7 && sleep <= 9 {
                sleepScore = 30.0
            } else if sleep < 7 {
                sleepScore = (sleep / 7.0) * 30.0
            } else {
                // Over 9 hours, slight penalty
                sleepScore = max(30.0 - (sleep - 9.0) * 5.0, 15.0)
            }
        }

        let total = stepScore + calorieScore + sleepScore
        return min(Int(total.rounded()), 100)
    }

    // MARK: - Hydration Tracking (UserDefaults)

    func incrementHydration() {
        hydrationGlasses += 1
        saveHydration()
    }

    func decrementHydration() {
        guard hydrationGlasses > 0 else { return }
        hydrationGlasses -= 1
        saveHydration()
    }

    private func saveHydration() {
        let defaults = UserDefaults.standard
        let today = Calendar.current.startOfDay(for: Date())
        defaults.set(hydrationGlasses, forKey: hydrationKey)
        defaults.set(today.timeIntervalSince1970, forKey: hydrationDateKey)
    }

    private func loadHydration() {
        let defaults = UserDefaults.standard
        let savedTimestamp = defaults.double(forKey: hydrationDateKey)
        let savedDate = Date(timeIntervalSince1970: savedTimestamp)
        let today = Calendar.current.startOfDay(for: Date())

        if Calendar.current.isDate(savedDate, inSameDayAs: today) {
            hydrationGlasses = defaults.integer(forKey: hydrationKey)
        } else {
            // Reset for a new day
            hydrationGlasses = 0
            saveHydration()
        }
    }

    // MARK: - Helpers

    private func todayPredicate() -> NSPredicate {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        return HKQuery.predicateForSamples(withStart: startOfDay, end: Date(), options: .strictStartDate)
    }

    nonisolated private static func workoutActivityName(_ type: HKWorkoutActivityType) -> String {
        switch type {
        case .running: return "Running"
        case .walking: return "Walking"
        case .cycling: return "Cycling"
        case .swimming: return "Swimming"
        case .basketball: return "Basketball"
        case .soccer: return "Soccer"
        case .tennis: return "Tennis"
        case .volleyball: return "Volleyball"
        case .dance: return "Dance"
        case .functionalStrengthTraining: return "Strength Training"
        case .traditionalStrengthTraining: return "Weight Training"
        case .yoga: return "Yoga"
        case .gymnastics: return "Gymnastics"
        case .trackAndField: return "Track & Field"
        case .baseball: return "Baseball"
        case .badminton: return "Badminton"
        case .hockey: return "Hockey"
        case .tableTennis: return "Table Tennis"
        case .jumpRope: return "Jump Rope"
        case .flexibility: return "Flexibility"
        case .cooldown: return "Cooldown"
        default: return "Workout"
        }
    }
}
