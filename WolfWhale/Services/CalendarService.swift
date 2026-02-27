import EventKit
import Foundation
import os

// MARK: - ScheduleEntry

/// Represents a single class meeting in a weekly schedule.
nonisolated struct ScheduleEntry: Identifiable, Hashable, Sendable {
    let id: UUID
    var courseName: String
    var courseId: UUID
    var dayOfWeek: Int          // 1 = Sunday … 7 = Saturday (EKWeekday-compatible)
    var startHour: Int          // 0–23
    var startMinute: Int        // 0–59
    var endHour: Int
    var endMinute: Int
    var location: String?
}

// MARK: - CalendarService

@Observable
@MainActor
final class CalendarService {

    private static let logger = Logger(subsystem: "com.wolfwhale.lms", category: "CalendarService")

    // MARK: Public state

    var isAuthorized = false
    var selectedCalendar: EKCalendar?
    /// User-facing error message set when a calendar sync operation fails.
    var syncError: String?
    var syncedEventCount: Int { syncedIdentifiers.count }
    var lastSyncDate: Date? {
        get { UserDefaults.standard.object(forKey: Self.lastSyncKey) as? Date }
        set { UserDefaults.standard.set(newValue, forKey: Self.lastSyncKey) }
    }

    // MARK: Private

    private var eventStore: EKEventStore?
    private static let calendarTitle = "WolfWhale LMS"
    private static let identifiersKey = "wolfwhale_synced_event_ids"
    private static let lastSyncKey = "wolfwhale_last_sync_date"
    private static let calendarIdKey = "wolfwhale_calendar_id"

    private var syncedIdentifiers: [String: String] {
        get { UserDefaults.standard.dictionary(forKey: Self.identifiersKey) as? [String: String] ?? [:] }
        set { UserDefaults.standard.set(newValue, forKey: Self.identifiersKey) }
    }

    // MARK: - Initializer

    init() {
        // EKEventStore() does not throw — no need for do/catch.
        let store = EKEventStore()
        self.eventStore = store
        checkAuthorizationStatus()
    }

    // MARK: - Authorization

    /// Check the current calendar authorization status.
    func checkAuthorizationStatus() {
        guard eventStore != nil else {
            isAuthorized = false
            return
        }
        let status = EKEventStore.authorizationStatus(for: .event)
        switch status {
        case .authorized, .fullAccess:
            isAuthorized = true
        default:
            isAuthorized = false
        }
    }

    /// Request write access to the user's calendar. Returns `true` if granted.
    @discardableResult
    func requestAccess() async -> Bool {
        guard let eventStore else {
            isAuthorized = false
            return false
        }
        do {
            let granted = try await eventStore.requestFullAccessToEvents()
            isAuthorized = granted
            return granted
        } catch {
            isAuthorized = false
            return false
        }
    }

    // MARK: - Calendar Management

    /// Find the existing "WolfWhale LMS" calendar or create one with a blue color.
    func getOrCreateWolfWhaleCalendar() -> EKCalendar? {
        guard let eventStore else { return nil }

        // Check saved calendar identifier first
        if let savedId = UserDefaults.standard.string(forKey: Self.calendarIdKey),
           let existing = eventStore.calendar(withIdentifier: savedId) {
            selectedCalendar = existing
            return existing
        }

        // Search for an existing calendar by title
        let calendars = eventStore.calendars(for: .event)
        if let existing = calendars.first(where: { $0.title == Self.calendarTitle }) {
            UserDefaults.standard.set(existing.calendarIdentifier, forKey: Self.calendarIdKey)
            selectedCalendar = existing
            return existing
        }

        // Create a new calendar
        let newCalendar = EKCalendar(for: .event, eventStore: eventStore)
        newCalendar.title = Self.calendarTitle
        newCalendar.cgColor = CGColor(red: 0.2, green: 0.5, blue: 1.0, alpha: 1.0) // blue

        // Use the default calendar source, or fall back to local
        if let defaultSource = eventStore.defaultCalendarForNewEvents?.source {
            newCalendar.source = defaultSource
        } else if let local = eventStore.sources.first(where: { $0.sourceType == .local }) {
            newCalendar.source = local
        } else if let fallback = eventStore.sources.first {
            newCalendar.source = fallback
        }

        do {
            try eventStore.saveCalendar(newCalendar, commit: true)
            UserDefaults.standard.set(newCalendar.calendarIdentifier, forKey: Self.calendarIdKey)
        } catch {
            #if DEBUG
            print("[CalendarService] Failed to create calendar: \(error)")
            #endif
        }

        selectedCalendar = newCalendar
        return newCalendar
    }

    // MARK: - Sync Assignment

    /// Create a calendar event for a single assignment's due date.
    /// Skips assignments whose due date is already in the past.
    /// Throws if the event cannot be saved to the calendar.
    func syncAssignmentToCalendar(assignment: Assignment) throws {
        guard isAuthorized, let eventStore else { return }
        // Do not create calendar events for assignments that are already past due
        guard assignment.dueDate > Date() else { return }
        guard let calendar = selectedCalendar ?? getOrCreateWolfWhaleCalendar() else { return }
        let key = "assignment-\(assignment.id.uuidString)"

        // Remove existing event if already synced (to update)
        if let existingId = syncedIdentifiers[key] {
            removeEvent(identifier: existingId)
        }

        let event = EKEvent(eventStore: eventStore)
        event.title = "[\(assignment.courseName)] \(assignment.title)"
        event.notes = "Points: \(assignment.points)\n\(assignment.instructions)"
        event.startDate = assignment.dueDate
        event.endDate = Calendar.current.date(byAdding: .hour, value: 1, to: assignment.dueDate) ?? assignment.dueDate
        event.calendar = calendar

        // Alarms: 1 hour before and 24 hours before
        let oneHourAlarm = EKAlarm(relativeOffset: -3600)       // -1 hour
        let oneDayAlarm = EKAlarm(relativeOffset: -86400)       // -24 hours
        event.alarms = [oneDayAlarm, oneHourAlarm]

        do {
            try eventStore.save(event, span: .thisEvent, commit: true)
            var ids = syncedIdentifiers
            ids[key] = event.eventIdentifier
            syncedIdentifiers = ids
            syncError = nil
        } catch {
            Self.logger.error("[CalendarService] Failed to save assignment event '\(assignment.title, privacy: .public)': \(error.localizedDescription, privacy: .public)")
            syncError = "Failed to sync assignment to calendar: \(error.localizedDescription)"
            throw error
        }
    }

    // MARK: - Bulk Sync Assignments

    /// Sync all upcoming (non-submitted) assignments to the calendar.
    /// Individual failures are logged but do not prevent other assignments from syncing.
    func syncAllAssignments(assignments: [Assignment]) {
        guard isAuthorized else { return }
        let upcoming = assignments.filter { !$0.isSubmitted && $0.dueDate > Date() }
        var failureCount = 0
        for assignment in upcoming {
            do {
                try syncAssignmentToCalendar(assignment: assignment)
            } catch {
                failureCount += 1
                // Error already logged in syncAssignmentToCalendar
            }
        }
        if failureCount > 0 {
            syncError = "Failed to sync \(failureCount) of \(upcoming.count) assignments to calendar."
            Self.logger.error("[CalendarService] Bulk sync completed with \(failureCount) failures out of \(upcoming.count) assignments")
        } else {
            syncError = nil
        }
        lastSyncDate = Date()
    }

    // MARK: - Sync Schedule

    /// Sync class schedule entries as recurring weekly events.
    /// Individual failures are logged but do not prevent other entries from syncing.
    func syncScheduleToCalendar(schedule: [ScheduleEntry]) {
        guard isAuthorized, let eventStore else { return }
        guard let calendar = selectedCalendar ?? getOrCreateWolfWhaleCalendar() else { return }

        var failureCount = 0
        for entry in schedule {
            let key = "schedule-\(entry.id.uuidString)"

            // Remove existing if already synced
            if let existingId = syncedIdentifiers[key] {
                removeEvent(identifier: existingId)
            }

            let event = EKEvent(eventStore: eventStore)
            event.title = entry.courseName
            event.location = entry.location
            event.calendar = calendar

            // Build start/end dates for the next occurrence of this weekday
            let cal = Calendar.current
            var startComponents = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())
            startComponents.weekday = entry.dayOfWeek
            startComponents.hour = entry.startHour
            startComponents.minute = entry.startMinute

            var endComponents = startComponents
            endComponents.hour = entry.endHour
            endComponents.minute = entry.endMinute

            guard var startDate = cal.date(from: startComponents),
                  var endDate = cal.date(from: endComponents) else { continue }

            // If the computed start date is in the past, advance by one week
            if startDate < Date() {
                startDate = cal.date(byAdding: .weekOfYear, value: 1, to: startDate) ?? startDate
                endDate = cal.date(byAdding: .weekOfYear, value: 1, to: endDate) ?? endDate
            }

            event.startDate = startDate
            event.endDate = endDate

            // Weekly recurrence — repeat for ~16 weeks (a semester)
            let recurrenceEnd = EKRecurrenceEnd(occurrenceCount: 16)
            let rule = EKRecurrenceRule(
                recurrenceWith: .weekly,
                interval: 1,
                end: recurrenceEnd
            )
            event.recurrenceRules = [rule]

            do {
                try eventStore.save(event, span: .futureEvents, commit: true)
                var ids = syncedIdentifiers
                ids[key] = event.eventIdentifier
                syncedIdentifiers = ids
            } catch {
                failureCount += 1
                Self.logger.error("[CalendarService] Failed to save schedule event '\(entry.courseName, privacy: .public)': \(error.localizedDescription, privacy: .public)")
            }
        }

        if failureCount > 0 {
            syncError = "Failed to sync \(failureCount) of \(schedule.count) schedule entries to calendar."
            Self.logger.error("[CalendarService] Schedule sync completed with \(failureCount) failures out of \(schedule.count) entries")
        } else {
            syncError = nil
        }
        lastSyncDate = Date()
    }

    // MARK: - Remove Events

    /// Remove a single synced event by its EKEvent identifier.
    func removeEvent(identifier: String) {
        guard let eventStore else { return }
        guard let event = eventStore.event(withIdentifier: identifier) else { return }
        do {
            try eventStore.remove(event, span: .futureEvents, commit: true)
            // Clean from stored identifiers
            var ids = syncedIdentifiers
            for (key, value) in ids where value == identifier {
                ids.removeValue(forKey: key)
            }
            syncedIdentifiers = ids
        } catch {
            #if DEBUG
            print("[CalendarService] Failed to remove event: \(error)")
            #endif
        }
    }

    /// Remove all WolfWhale-synced events and clear stored identifiers.
    func removeAllWolfWhaleEvents() {
        guard let eventStore else { return }
        let ids = syncedIdentifiers
        for (_, eventId) in ids {
            if let event = eventStore.event(withIdentifier: eventId) {
                do {
                    try eventStore.remove(event, span: .futureEvents, commit: true)
                } catch {
                    Self.logger.error("[CalendarService] Failed to remove event \(eventId, privacy: .public): \(error.localizedDescription, privacy: .public)")
                }
            }
        }
        syncedIdentifiers = [:]
        lastSyncDate = nil
    }

    // MARK: - Available Calendars

    /// Returns all writable calendars for the user to pick from.
    var availableCalendars: [EKCalendar] {
        eventStore?.calendars(for: .event).filter { $0.allowsContentModifications } ?? []
    }

    /// Set the target calendar by identifier.
    func selectCalendar(identifier: String) {
        if let cal = eventStore?.calendar(withIdentifier: identifier) {
            selectedCalendar = cal
            UserDefaults.standard.set(identifier, forKey: Self.calendarIdKey)
        }
    }
}
