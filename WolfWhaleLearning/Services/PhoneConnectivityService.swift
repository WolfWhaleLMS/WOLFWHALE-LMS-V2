import Foundation
import WatchConnectivity

/// Sends LMS data from the iPhone app to the paired Apple Watch via WatchConnectivity.
///
/// Usage in the main app:
/// ```
/// // In AppViewModel or wherever loadData() completes:
/// let phoneConnectivity = PhoneConnectivityService()
/// phoneConnectivity.sendDataToWatch(
///     assignments: assignments,
///     schedule: courses,
///     grades: grades
/// )
/// ```
///
/// The service packages data into lightweight Codable structs and sends them
/// as `applicationContext`, which is the most battery-efficient transfer method
/// since watchOS only processes the latest context (no queue of outdated updates).
@Observable
@MainActor
final class PhoneConnectivityService: NSObject {

    /// Whether the paired watch is reachable right now.
    var isWatchReachable: Bool = false

    /// Whether a watch app is installed on the paired watch.
    var isWatchAppInstalled: Bool = false

    /// Error message from the last send attempt, if any.
    var lastError: String?

    /// Timestamp of the last successful data send.
    var lastSendDate: Date?

    // MARK: - Private

    private let encoder = JSONEncoder()

    // MARK: - Init

    override init() {
        super.init()
        activateSession()
    }

    // MARK: - Session

    private func activateSession() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    // MARK: - Send Data to Watch

    /// Packages assignments, schedule entries, and grades into lightweight structs
    /// and sends them to the watch as `applicationContext`.
    ///
    /// Call this method after `loadData()` completes in `AppViewModel`.
    ///
    /// - Parameters:
    ///   - assignments: The full list of `Assignment` objects from the main app.
    ///   - courses: The full list of `Course` objects (used to derive schedule entries).
    ///   - grades: The full list of `GradeEntry` objects from the main app.
    func sendDataToWatch(
        assignments: [Assignment],
        courses: [Course],
        grades: [GradeEntry]
    ) {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated else {
            lastError = "Watch session not activated"
            return
        }

        #if os(iOS)
        guard session.isPaired else {
            lastError = "No Apple Watch paired"
            return
        }
        guard session.isWatchAppInstalled else {
            lastError = "Watch app not installed"
            return
        }
        #endif

        // Convert main app models to lightweight watch models
        let watchAssignments = assignments
            .filter { !$0.isSubmitted }
            .sorted { $0.dueDate < $1.dueDate }
            .prefix(20)
            .map { assignment in
                WatchAssignmentTransfer(
                    id: assignment.id,
                    title: assignment.title,
                    courseName: assignment.courseName,
                    dueDate: assignment.dueDate,
                    points: assignment.points,
                    isSubmitted: assignment.isSubmitted,
                    grade: assignment.grade
                )
            }

        // Build schedule entries from courses.
        // The main app does not have a dedicated schedule model with times,
        // so we generate synthetic time slots based on course order.
        // In a production app, these would come from a real schedule/timetable API.
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let watchSchedule = courses.enumerated().map { index, course in
            // Generate a synthetic time slot: classes start at 8:00 and each lasts 50 minutes with 10-minute breaks.
            let startHour = 8 + index
            let startTime = calendar.date(bySettingHour: startHour, minute: 0, second: 0, of: today) ?? today
            let endTime = calendar.date(byAdding: .minute, value: 50, to: startTime) ?? startTime

            return WatchScheduleTransfer(
                id: course.id,
                courseName: course.title,
                startTime: startTime,
                endTime: endTime,
                roomNumber: "\(100 + index * 10 + Int.random(in: 1...9))"
            )
        }

        let watchGrades = grades.map { grade in
            WatchGradeTransfer(
                id: grade.id,
                courseName: grade.courseName,
                letterGrade: grade.letterGrade,
                numericGrade: grade.numericGrade,
                courseColor: grade.courseColor,
                courseIcon: grade.courseIcon
            )
        }

        // Encode to Data
        var context: [String: Any] = [:]

        do {
            context["assignments"] = try encoder.encode(Array(watchAssignments))
            context["schedule"] = try encoder.encode(watchSchedule)
            context["grades"] = try encoder.encode(watchGrades)

            try session.updateApplicationContext(context)
            lastSendDate = Date()
            lastError = nil
        } catch {
            lastError = "Failed to send: \(error.localizedDescription)"
            #if DEBUG
            print("[PhoneConnectivityService] Error sending to watch: \(error)")
            #endif
        }
    }
}

// MARK: - WCSessionDelegate

extension PhoneConnectivityService: WCSessionDelegate {

    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        Task { @MainActor in
            if let error {
                self.lastError = "Session activation error: \(error.localizedDescription)"
            }
            #if os(iOS)
            self.isWatchReachable = session.isReachable
            self.isWatchAppInstalled = session.isWatchAppInstalled
            #endif
        }
    }

    #if os(iOS)
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {
        // No-op. Required by the protocol on iOS.
    }

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        // Re-activate after switching watches.
        session.activate()
    }

    nonisolated func sessionWatchStateDidChange(_ session: WCSession) {
        Task { @MainActor in
            self.isWatchReachable = session.isReachable
            self.isWatchAppInstalled = session.isWatchAppInstalled
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            self.isWatchReachable = session.isReachable
        }
    }
    #endif
}

// MARK: - Transfer Models (Mirror of WatchDataModels, used on the iOS side for encoding)

/// These structs duplicate the watch-side models so that the iOS target does not
/// need to import the watch target's code. The field names and types must match
/// exactly so the watch can decode what the phone encodes.

private struct WatchAssignmentTransfer: Codable {
    let id: UUID
    let title: String
    let courseName: String
    let dueDate: Date
    let points: Int
    let isSubmitted: Bool
    let grade: Double?
}

private struct WatchScheduleTransfer: Codable {
    let id: UUID
    let courseName: String
    let startTime: Date
    let endTime: Date
    let roomNumber: String
}

private struct WatchGradeTransfer: Codable {
    let id: UUID
    let courseName: String
    let letterGrade: String
    let numericGrade: Double
    let courseColor: String
    let courseIcon: String
}
