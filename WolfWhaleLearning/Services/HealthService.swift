import HealthKit
import Foundation

// MARK: - DailyStudyData

/// Represents a single day's study minutes for the weekly chart.
struct DailyStudyData: Identifiable, Sendable {
    let id = UUID()
    let date: Date
    let minutes: Double

    var dayLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }
}

// MARK: - HealthService

@Observable
@MainActor
final class HealthService {

    // MARK: Public state

    var isAuthorized = false
    var todaySteps: Int = 0
    var todayStudyMinutes: Double = 0
    var lastSleepHours: Double = 0
    var weeklyStudyData: [DailyStudyData] = []
    var isLoading = false

    // Study session tracking
    var isStudySessionActive = false
    var studySessionStartDate: Date?
    var studySessionElapsed: TimeInterval = 0

    // MARK: Private

    private let healthStore = HKHealthStore()
    private var timerTask: Task<Void, Never>?

    // MARK: - Initializer

    init() {
        checkAuthorizationStatus()
    }

    // MARK: - Authorization

    /// Check if HealthKit data is available on this device.
    var isHealthKitAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    /// Check current authorization status by attempting a lightweight query.
    func checkAuthorizationStatus() {
        guard isHealthKitAvailable else {
            isAuthorized = false
            return
        }

        // Check if we have previously been granted access by looking at
        // the authorization status for a type we write (mindful session).
        if let mindfulType = HKObjectType.categoryType(forIdentifier: .mindfulSession) {
            let status = healthStore.authorizationStatus(for: mindfulType)
            isAuthorized = status == .sharingAuthorized
        }
    }

    /// Request HealthKit authorization for reading steps, sleep, mindful minutes
    /// and writing mindful minutes.
    @discardableResult
    func requestAuthorization() async -> Bool {
        guard isHealthKitAvailable else { return false }

        // Types to read
        var readTypes = Set<HKObjectType>()
        if let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) {
            readTypes.insert(stepType)
        }
        if let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) {
            readTypes.insert(sleepType)
        }
        if let mindfulType = HKCategoryType.categoryType(forIdentifier: .mindfulSession) {
            readTypes.insert(mindfulType)
        }

        // Types to write
        var writeTypes = Set<HKSampleType>()
        if let mindfulType = HKCategoryType.categoryType(forIdentifier: .mindfulSession) {
            writeTypes.insert(mindfulType)
        }

        do {
            try await healthStore.requestAuthorization(toShare: writeTypes, read: readTypes)
            checkAuthorizationStatus()
            if isAuthorized {
                await refreshAllData()
            }
            return isAuthorized
        } catch {
            #if DEBUG
            print("[HealthService] Authorization failed: \(error)")
            #endif
            isAuthorized = false
            return false
        }
    }

    // MARK: - Refresh All Data

    /// Fetch all wellness data: steps, sleep, study minutes, and weekly chart.
    func refreshAllData() async {
        guard isAuthorized else { return }
        isLoading = true

        async let steps = fetchTodaySteps()
        async let sleep = fetchLastNightSleep()
        async let study = fetchTodayStudyMinutes()
        async let weekly = fetchWeeklyStudyData()

        todaySteps = await steps
        lastSleepHours = await sleep
        todayStudyMinutes = await study
        weeklyStudyData = await weekly

        isLoading = false
    }

    // MARK: - Step Count

    /// Read today's cumulative step count.
    private func fetchTodaySteps() async -> Int {
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return 0 }

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: Date(), options: .strictStartDate)

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: stepType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, result, error in
                if let error {
                    #if DEBUG
                    print("[HealthService] Step count error: \(error)")
                    #endif
                    continuation.resume(returning: 0)
                    return
                }

                let steps = result?.sumQuantity()?.doubleValue(for: .count()) ?? 0
                continuation.resume(returning: Int(steps))
            }
            healthStore.execute(query)
        }
    }

    // MARK: - Sleep Analysis

    /// Read last night's total sleep duration in hours.
    /// Looks for sleep samples between 8 PM yesterday and noon today.
    private func fetchLastNightSleep() async -> Double {
        guard let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) else { return 0 }

        let calendar = Calendar.current
        let now = Date()

        // Window: 8 PM yesterday to 12 PM today
        guard let yesterday8PM = calendar.date(bySettingHour: 20, minute: 0, second: 0, of: calendar.date(byAdding: .day, value: -1, to: now) ?? now),
              let todayNoon = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: now) else {
            return 0
        }

        let predicate = HKQuery.predicateForSamples(withStart: yesterday8PM, end: todayNoon, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: sleepType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error {
                    #if DEBUG
                    print("[HealthService] Sleep query error: \(error)")
                    #endif
                    continuation.resume(returning: 0)
                    return
                }

                guard let sleepSamples = samples as? [HKCategorySample] else {
                    continuation.resume(returning: 0)
                    return
                }

                // Sum only asleepUnspecified, asleepCore, asleepDeep, asleepREM
                let asleepValues: Set<Int> = [
                    HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
                    HKCategoryValueSleepAnalysis.asleepCore.rawValue,
                    HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
                    HKCategoryValueSleepAnalysis.asleepREM.rawValue
                ]

                var totalSeconds: TimeInterval = 0
                for sample in sleepSamples {
                    if asleepValues.contains(sample.value) {
                        totalSeconds += sample.endDate.timeIntervalSince(sample.startDate)
                    }
                }

                let hours = totalSeconds / 3600.0
                continuation.resume(returning: hours)
            }
            healthStore.execute(query)
        }
    }

    // MARK: - Study Minutes (Mindful Sessions)

    /// Read today's total study time from saved mindful sessions.
    private func fetchTodayStudyMinutes() async -> Double {
        return await fetchStudyMinutes(for: Date())
    }

    /// Read total mindful-session minutes for a specific day.
    private func fetchStudyMinutes(for date: Date) async -> Double {
        guard let mindfulType = HKCategoryType.categoryType(forIdentifier: .mindfulSession) else { return 0 }

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else { return 0 }

        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: mindfulType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error {
                    #if DEBUG
                    print("[HealthService] Study minutes error: \(error)")
                    #endif
                    continuation.resume(returning: 0)
                    return
                }

                guard let sessions = samples as? [HKCategorySample] else {
                    continuation.resume(returning: 0)
                    return
                }

                var totalSeconds: TimeInterval = 0
                for session in sessions {
                    totalSeconds += session.endDate.timeIntervalSince(session.startDate)
                }

                continuation.resume(returning: totalSeconds / 60.0)
            }
            healthStore.execute(query)
        }
    }

    // MARK: - Weekly Study Data

    /// Fetch daily study totals for the last 7 days.
    func fetchWeeklyStudyData() async -> [DailyStudyData] {
        let calendar = Calendar.current
        var data: [DailyStudyData] = []

        for dayOffset in (0..<7).reversed() {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: Date()) else { continue }
            let minutes = await fetchStudyMinutes(for: date)
            data.append(DailyStudyData(date: date, minutes: minutes))
        }

        return data
    }

    // MARK: - Study Session Tracking

    /// Start a study session timer.
    func startStudySession() {
        studySessionStartDate = Date()
        studySessionElapsed = 0
        isStudySessionActive = true

        // Update elapsed time every second
        timerTask?.cancel()
        timerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { break }
                await MainActor.run {
                    guard let self, let start = self.studySessionStartDate else { return }
                    self.studySessionElapsed = Date().timeIntervalSince(start)
                }
            }
        }
    }

    /// Stop the current study session and save it as a mindful session in HealthKit.
    func stopStudySession() async {
        timerTask?.cancel()
        timerTask = nil

        guard let startDate = studySessionStartDate else {
            isStudySessionActive = false
            return
        }

        let endDate = Date()
        isStudySessionActive = false
        studySessionStartDate = nil

        // Only save if the session was at least 30 seconds
        guard endDate.timeIntervalSince(startDate) >= 30 else {
            studySessionElapsed = 0
            return
        }

        await saveMindfulSession(start: startDate, end: endDate)
        studySessionElapsed = 0
        await refreshAllData()
    }

    /// Save a mindful session to HealthKit.
    private func saveMindfulSession(start: Date, end: Date) async {
        guard let mindfulType = HKCategoryType.categoryType(forIdentifier: .mindfulSession) else { return }

        let sample = HKCategorySample(
            type: mindfulType,
            value: HKCategoryValue.notApplicable.rawValue,
            start: start,
            end: end
        )

        do {
            try await healthStore.save(sample)
            #if DEBUG
            let minutes = end.timeIntervalSince(start) / 60.0
            print("[HealthService] Saved mindful session: \(String(format: "%.1f", minutes)) minutes")
            #endif
        } catch {
            #if DEBUG
            print("[HealthService] Failed to save mindful session: \(error)")
            #endif
        }
    }

    // MARK: - Formatted Helpers

    /// Format elapsed time as "MM:SS" or "H:MM:SS".
    var formattedElapsedTime: String {
        let totalSeconds = Int(studySessionElapsed)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }

    /// Format sleep hours as "Xh Ym".
    var formattedSleepDuration: String {
        let hours = Int(lastSleepHours)
        let minutes = Int((lastSleepHours - Double(hours)) * 60)
        if hours > 0 && minutes > 0 {
            return "\(hours)h \(minutes)m"
        } else if hours > 0 {
            return "\(hours)h"
        } else {
            return "\(minutes)m"
        }
    }

    /// Format study minutes as "Xh Ym" or "X min".
    var formattedStudyTime: String {
        let totalMinutes = Int(todayStudyMinutes)
        if totalMinutes >= 60 {
            let hours = totalMinutes / 60
            let mins = totalMinutes % 60
            return mins > 0 ? "\(hours)h \(mins)m" : "\(hours)h"
        } else {
            return "\(totalMinutes) min"
        }
    }
}
