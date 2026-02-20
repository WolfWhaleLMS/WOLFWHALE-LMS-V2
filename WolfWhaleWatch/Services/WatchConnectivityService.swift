import Foundation
import WatchConnectivity

/// Receives data from the paired iPhone app via WatchConnectivity and persists it
/// locally so the watch can display information even when the phone is out of range.
///
/// Data flow:
///   iPhone PhoneConnectivityService --[applicationContext]--> WatchConnectivityService
///
/// The service decodes three collections from the context dictionary:
///   - "assignments" -> [WatchAssignment]
///   - "schedule"    -> [WatchScheduleEntry]
///   - "grades"      -> [WatchGrade]
///
/// Received data is also written to UserDefaults so it survives app restarts.
@Observable
@MainActor
final class WatchConnectivityService: NSObject {

    // MARK: - Published Data

    var assignments: [WatchAssignment] = []
    var schedule: [WatchScheduleEntry] = []
    var grades: [WatchGrade] = []

    /// Timestamp of the last successful data update from the phone.
    var lastSyncDate: Date?

    /// Human-readable error from the most recent sync attempt, if any.
    var syncError: String?

    // MARK: - Private

    private let defaults = UserDefaults.standard
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    private static let assignmentsKey = "watch_assignments"
    private static let scheduleKey = "watch_schedule"
    private static let gradesKey = "watch_grades"
    private static let lastSyncKey = "watch_last_sync"

    // MARK: - Init

    override init() {
        super.init()
        loadFromDisk()
        activateSession()
    }

    // MARK: - Session Activation

    private func activateSession() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    // MARK: - Persistence

    /// Saves current in-memory data to UserDefaults for offline access.
    private func saveToDisk() {
        if let data = try? encoder.encode(assignments) {
            defaults.set(data, forKey: Self.assignmentsKey)
        }
        if let data = try? encoder.encode(schedule) {
            defaults.set(data, forKey: Self.scheduleKey)
        }
        if let data = try? encoder.encode(grades) {
            defaults.set(data, forKey: Self.gradesKey)
        }
        if let syncDate = lastSyncDate {
            defaults.set(syncDate.timeIntervalSince1970, forKey: Self.lastSyncKey)
        }
    }

    /// Loads previously saved data from UserDefaults.
    private func loadFromDisk() {
        if let data = defaults.data(forKey: Self.assignmentsKey),
           let decoded = try? decoder.decode([WatchAssignment].self, from: data) {
            assignments = decoded
        }
        if let data = defaults.data(forKey: Self.scheduleKey),
           let decoded = try? decoder.decode([WatchScheduleEntry].self, from: data) {
            schedule = decoded
        }
        if let data = defaults.data(forKey: Self.gradesKey),
           let decoded = try? decoder.decode([WatchGrade].self, from: data) {
            grades = decoded
        }
        let ts = defaults.double(forKey: Self.lastSyncKey)
        if ts > 0 {
            lastSyncDate = Date(timeIntervalSince1970: ts)
        }
    }

    // MARK: - Context Processing

    /// Parses the applicationContext dictionary sent by the iPhone app and updates
    /// the in-memory collections, then persists to disk.
    nonisolated private func processContext(_ context: [String: Any]) {
        Task { @MainActor in
            var didUpdate = false

            if let rawAssignments = context["assignments"] as? Data,
               let decoded = try? self.decoder.decode([WatchAssignment].self, from: rawAssignments) {
                self.assignments = decoded
                didUpdate = true
            }

            if let rawSchedule = context["schedule"] as? Data,
               let decoded = try? self.decoder.decode([WatchScheduleEntry].self, from: rawSchedule) {
                self.schedule = decoded
                didUpdate = true
            }

            if let rawGrades = context["grades"] as? Data,
               let decoded = try? self.decoder.decode([WatchGrade].self, from: rawGrades) {
                self.grades = decoded
                didUpdate = true
            }

            if didUpdate {
                self.lastSyncDate = Date()
                self.syncError = nil
                self.saveToDisk()
            }
        }
    }
}

// MARK: - WCSessionDelegate

extension WatchConnectivityService: WCSessionDelegate {

    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        if let error {
            Task { @MainActor in
                self.syncError = "Activation failed: \(error.localizedDescription)"
            }
        }

        // Process any context that was delivered while the session was inactive.
        if activationState == .activated {
            let context = session.receivedApplicationContext
            if !context.isEmpty {
                processContext(context)
            }
        }
    }

    /// Called when the iPhone sends updated applicationContext.
    nonisolated func session(
        _ session: WCSession,
        didReceiveApplicationContext applicationContext: [String: Any]
    ) {
        processContext(applicationContext)
    }
}
