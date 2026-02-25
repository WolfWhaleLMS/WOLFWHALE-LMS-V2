import Foundation
import UserNotifications
import Supabase

// MARK: - ParentFeaturesViewModel
/// Manages parent-specific state and logic: children, parent alerts, conferences,
/// absence alerts, weekly digest, and conference scheduling.
/// Extracted from AppViewModel+ParentFeatures.swift to reduce god-class complexity.

@Observable
@MainActor
class ParentFeaturesViewModel {

    // MARK: - Data

    /// Linked children for the parent user.
    var children: [ChildInfo] = []

    /// Active parent alerts (low grades, absences, upcoming due dates).
    var parentAlerts: [ParentAlert] = []

    /// Conferences (parent-teacher meetings).
    var conferences: [Conference] = []

    /// Teacher available time slots for conference scheduling.
    var teacherAvailableSlots: [TeacherAvailableSlot] = []

    /// Whether real-time absence alerts are enabled.
    var absenceAlertEnabled: Bool = true

    /// Error surfaced to the UI.
    var dataError: String?

    // MARK: - Dependencies

    let dataService = DataService.shared

    // MARK: - Computed: Unread Alerts

    var unreadParentAlertCount: Int {
        parentAlerts.filter { !$0.isRead }.count
    }

    // MARK: - Computed: My Conferences

    /// Conferences for the current user (parent sees their conferences, teacher sees theirs).
    func myConferences(for user: User?) -> [Conference] {
        guard let user else { return [] }
        switch user.role {
        case .parent:
            return conferences.filter { $0.parentId == user.id }
        case .teacher:
            return conferences.filter { $0.teacherId == user.id }
        default:
            return conferences
        }
    }

    /// Upcoming conferences for the current user, sorted by date.
    func upcomingConferences(for user: User?) -> [Conference] {
        myConferences(for: user)
            .filter { $0.isUpcoming }
            .sorted { $0.date < $1.date }
    }

    /// Past/completed conferences for the current user.
    func pastConferences(for user: User?) -> [Conference] {
        myConferences(for: user)
            .filter { !$0.isUpcoming }
            .sorted { $0.date > $1.date }
    }

    // MARK: - Parent Alerts

    /// Scans every linked child for low grades, absences today, and upcoming due
    /// dates within 24 hours, then populates `parentAlerts` and fires local
    /// notifications for each new alert.
    func scheduleParentAlerts() {
        var alerts: [ParentAlert] = []
        let now = Date()
        let calendar = Calendar.current

        for child in children {
            // 1. Low grades (< 70%)
            for course in child.courses where course.numericGrade < 70 {
                alerts.append(ParentAlert(
                    type: .lowGrade,
                    childId: child.id,
                    childName: child.name,
                    title: "Low Grade: \(course.courseName)",
                    message: "\(child.name) has a \(String(format: "%.0f", course.numericGrade))% in \(course.courseName).",
                    courseName: course.courseName
                ))
            }

            // 2. Attendance alert -- flag children whose rate is at or below 90%
            if child.attendanceRate <= 0.90 {
                alerts.append(ParentAlert(
                    type: .absence,
                    childId: child.id,
                    childName: child.name,
                    title: "Attendance Alert",
                    message: "\(child.name)'s attendance rate is \(Int(child.attendanceRate * 100))%. Please contact the school if needed.",
                    courseName: "General"
                ))
            }

            // 3. Due dates within 24 hours
            for assignment in child.recentAssignments {
                guard !assignment.isSubmitted,
                      assignment.dueDate > now,
                      let dayAhead = calendar.date(byAdding: .hour, value: 24, to: now),
                      assignment.dueDate <= dayAhead else { continue }

                alerts.append(ParentAlert(
                    type: .upcomingDueDate,
                    childId: child.id,
                    childName: child.name,
                    title: "Due Soon: \(assignment.title)",
                    message: "\(assignment.title) for \(assignment.courseName) is due \(assignment.dueDate.formatted(.relative(presentation: .named))).",
                    courseName: assignment.courseName
                ))
            }
        }

        parentAlerts = alerts

        // Schedule a local notification for each unread alert
        Task.detached(priority: .utility) { @MainActor in
            let center = UNUserNotificationCenter.current()
            for alert in alerts where !alert.isRead {
                let content = UNMutableNotificationContent()
                content.title = alert.title
                content.body = alert.message
                content.sound = .default
                content.categoryIdentifier = "PARENT_ALERT"
                content.userInfo = [
                    "type": alert.type.rawValue,
                    "childId": alert.childId.uuidString,
                    "alertId": alert.id.uuidString
                ]

                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
                let identifier = "parent-alert-\(alert.id.uuidString)"
                let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

                do {
                    try await center.add(request)
                } catch {
                    #if DEBUG
                    print("[ParentFeaturesViewModel] Failed to schedule parent alert notification: \(error)")
                    #endif
                }
            }
        }
    }

    /// Mark a single parent alert as read.
    func markParentAlertRead(_ alertId: UUID) {
        guard let index = parentAlerts.firstIndex(where: { $0.id == alertId }) else { return }
        parentAlerts[index].isRead = true
    }

    /// Mark all parent alerts as read.
    func markAllParentAlertsRead() {
        for index in parentAlerts.indices {
            parentAlerts[index].isRead = true
        }
    }

    // MARK: - Real-Time Absence Alert

    /// Call this when attendance is saved. For every student marked absent,
    /// immediately generate a parent alert and push notification.
    func triggerAbsenceAlerts(
        absentStudentNames: [(studentId: UUID, studentName: String)],
        courseName: String,
        date: Date
    ) {
        guard absenceAlertEnabled else { return }

        for student in absentStudentNames {
            for child in children where child.name == student.studentName {
                let alert = ParentAlert(
                    type: .absence,
                    childId: child.id,
                    childName: child.name,
                    title: "Absence Alert: \(child.name)",
                    message: "\(child.name) was marked absent in \(courseName) on \(formatDateShort(date)).",
                    courseName: courseName,
                    date: Date()
                )
                parentAlerts.insert(alert, at: 0)

                let content = UNMutableNotificationContent()
                content.title = "Absence Alert"
                content.body = "\(child.name) was marked absent in \(courseName)."
                content.sound = .default
                content.categoryIdentifier = "PARENT_ALERT"
                content.userInfo = [
                    "type": ParentAlertType.absence.rawValue,
                    "childId": child.id.uuidString,
                    "alertId": alert.id.uuidString
                ]

                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
                let request = UNNotificationRequest(
                    identifier: "absence-alert-\(alert.id.uuidString)",
                    content: content,
                    trigger: trigger
                )
                UNUserNotificationCenter.current().add(request)
            }
        }
    }

    // MARK: - Conference Scheduling

    /// Loads conferences and available slots from Supabase for the current user.
    func loadConferencesIfNeeded(currentUser: User?, isDemoMode: Bool, courses: [Course]) async {
        guard let user = currentUser, !isDemoMode else {
            if isDemoMode, let user = currentUser {
                loadDemoConferenceData(currentUser: user, courses: courses)
            }
            return
        }

        do {
            conferences = try await dataService.fetchConferences(userId: user.id, role: user.role)

            if user.role == .parent {
                teacherAvailableSlots = try await dataService.fetchTeacherSlots()
            } else if user.role == .teacher {
                teacherAvailableSlots = try await dataService.fetchTeacherSlots(teacherId: user.id)
            }
        } catch {
            #if DEBUG
            print("[ParentFeaturesViewModel] Failed to load conferences: \(error)")
            #endif
        }
    }

    /// Parent requests a conference with a teacher for a specific child.
    func bookConference(
        teacherId: UUID,
        teacherName: String,
        childName: String,
        slotId: UUID,
        notes: String?,
        currentUser: User?
    ) {
        guard let user = currentUser, user.role == .parent else { return }

        guard let slotIndex = teacherAvailableSlots.firstIndex(where: { $0.id == slotId }) else { return }
        let slot = teacherAvailableSlots[slotIndex]

        teacherAvailableSlots[slotIndex].isBooked = true

        let conference = Conference(
            parentId: user.id,
            teacherId: teacherId,
            teacherName: teacherName,
            parentName: user.fullName,
            childName: childName,
            date: slot.date,
            duration: slot.durationMinutes,
            status: .requested,
            notes: notes,
            location: "Room 101"
        )
        conferences.append(conference)

        Task {
            do {
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

                let dto = InsertConferenceDTO(
                    tenantId: UUID(uuidString: user.schoolId ?? ""),
                    parentId: user.id,
                    teacherId: teacherId,
                    teacherName: teacherName,
                    parentName: user.fullName,
                    childName: childName,
                    conferenceDate: formatter.string(from: slot.date),
                    duration: slot.durationMinutes,
                    status: "requested",
                    notes: notes,
                    location: "Room 101",
                    slotId: slotId
                )
                _ = try await dataService.createConference(dto)
                try await dataService.updateSlotBookedStatus(slotId: slotId, isBooked: true)
            } catch {
                if let idx = self.teacherAvailableSlots.firstIndex(where: { $0.id == slotId }) {
                    self.teacherAvailableSlots[idx].isBooked = false
                }
                self.conferences.removeAll { $0.id == conference.id }
                #if DEBUG
                print("[ParentFeaturesViewModel] Failed to book conference: \(error)")
                #endif
            }
        }

        scheduleConferenceNotification(conference: conference, message: "Conference requested with \(teacherName) for \(childName).")
    }

    /// Parent cancels a conference.
    func cancelConference(_ conferenceId: UUID) {
        guard let index = conferences.firstIndex(where: { $0.id == conferenceId }) else { return }
        let previousStatus = conferences[index].status
        conferences[index].status = .cancelled

        let conference = conferences[index]
        if let slotIndex = teacherAvailableSlots.firstIndex(where: {
            $0.teacherId == conference.teacherId &&
            Calendar.current.isDate($0.date, equalTo: conference.date, toGranularity: .minute)
        }) {
            teacherAvailableSlots[slotIndex].isBooked = false
        }

        Task {
            do {
                try await dataService.updateConferenceStatus(conferenceId: conferenceId, status: "cancelled")
                if let slot = teacherAvailableSlots.first(where: {
                    $0.teacherId == conference.teacherId &&
                    Calendar.current.isDate($0.date, equalTo: conference.date, toGranularity: .minute)
                }) {
                    try await dataService.updateSlotBookedStatus(slotId: slot.id, isBooked: false)
                }
            } catch {
                if let idx = self.conferences.firstIndex(where: { $0.id == conferenceId }) {
                    self.conferences[idx].status = previousStatus
                }
                #if DEBUG
                print("[ParentFeaturesViewModel] Failed to cancel conference: \(error)")
                #endif
            }
        }
    }

    // MARK: - Teacher: Manage Availability

    func addAvailableSlot(date: Date, durationMinutes: Int = 15, currentUser: User?) {
        guard let user = currentUser, user.role == .teacher else { return }

        let slot = TeacherAvailableSlot(
            teacherId: user.id,
            date: date,
            durationMinutes: durationMinutes
        )
        teacherAvailableSlots.append(slot)

        Task {
            do {
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

                let dto = InsertTeacherSlotDTO(
                    tenantId: UUID(uuidString: user.schoolId ?? ""),
                    teacherId: user.id,
                    slotDate: formatter.string(from: date),
                    durationMinutes: durationMinutes
                )
                _ = try await dataService.createTeacherSlot(dto)
            } catch {
                self.teacherAvailableSlots.removeAll { $0.id == slot.id }
                #if DEBUG
                print("[ParentFeaturesViewModel] Failed to add slot: \(error)")
                #endif
            }
        }
    }

    func removeAvailableSlot(_ slotId: UUID) {
        let removed = teacherAvailableSlots.first { $0.id == slotId }
        teacherAvailableSlots.removeAll { $0.id == slotId }

        Task {
            do {
                try await dataService.deleteTeacherSlot(slotId: slotId)
            } catch {
                if let removed {
                    self.teacherAvailableSlots.append(removed)
                }
                #if DEBUG
                print("[ParentFeaturesViewModel] Failed to remove slot: \(error)")
                #endif
            }
        }
    }

    /// Teacher approves a conference request.
    func approveConference(_ conferenceId: UUID) {
        guard let index = conferences.firstIndex(where: { $0.id == conferenceId }) else { return }
        conferences[index].status = .confirmed

        let conf = conferences[index]

        Task {
            do {
                try await dataService.updateConferenceStatus(conferenceId: conferenceId, status: "confirmed")
            } catch {
                if let idx = self.conferences.firstIndex(where: { $0.id == conferenceId }) {
                    self.conferences[idx].status = .requested
                }
                #if DEBUG
                print("[ParentFeaturesViewModel] Failed to approve conference: \(error)")
                #endif
            }
        }

        scheduleConferenceNotification(
            conference: conf,
            message: "Your conference with \(conf.teacherName) regarding \(conf.childName) has been confirmed for \(conf.timeSlotLabel)."
        )
    }

    /// Teacher declines a conference request.
    func declineConference(_ conferenceId: UUID) {
        guard let index = conferences.firstIndex(where: { $0.id == conferenceId }) else { return }
        conferences[index].status = .cancelled

        let conf = conferences[index]
        if let slotIndex = teacherAvailableSlots.firstIndex(where: {
            $0.teacherId == conf.teacherId &&
            Calendar.current.isDate($0.date, equalTo: conf.date, toGranularity: .minute)
        }) {
            teacherAvailableSlots[slotIndex].isBooked = false
        }

        Task {
            do {
                try await dataService.updateConferenceStatus(conferenceId: conferenceId, status: "cancelled")
                if let slot = teacherAvailableSlots.first(where: {
                    $0.teacherId == conf.teacherId &&
                    Calendar.current.isDate($0.date, equalTo: conf.date, toGranularity: .minute)
                }) {
                    try await dataService.updateSlotBookedStatus(slotId: slot.id, isBooked: false)
                }
            } catch {
                #if DEBUG
                print("[ParentFeaturesViewModel] Failed to decline conference: \(error)")
                #endif
            }
        }
    }

    // MARK: - Demo Data

    func loadDemoConferenceData(currentUser: User, courses: [Course]) {
        let calendar = Calendar.current

        if currentUser.role == .parent {
            let teacherNames = courses.isEmpty
                ? ["Dr. Sarah Chen", "Mr. David Park", "Ms. Emily Torres"]
                : courses.map(\.teacherName)
            let uniqueTeachers = Array(Set(teacherNames))

            var slots: [TeacherAvailableSlot] = []
            var confs: [Conference] = []

            for (tIndex, teacherName) in uniqueTeachers.enumerated() {
                let teacherId = UUID()
                for dayOffset in [2, 5, 8] {
                    guard let slotDate = calendar.date(byAdding: .day, value: dayOffset, to: Date()) else { continue }
                    let hour = 9 + tIndex
                    guard let dateWithTime = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: slotDate) else { continue }

                    slots.append(TeacherAvailableSlot(
                        teacherId: teacherId,
                        date: dateWithTime,
                        durationMinutes: 15
                    ))
                }

                if let pastDate = calendar.date(byAdding: .day, value: -3, to: Date()),
                   let pastWithTime = calendar.date(bySettingHour: 10, minute: 0, second: 0, of: pastDate) {
                    let childName = children.first?.name ?? "Alex Rivera"
                    confs.append(Conference(
                        parentId: currentUser.id,
                        teacherId: teacherId,
                        teacherName: teacherName,
                        parentName: currentUser.fullName,
                        childName: childName,
                        date: pastWithTime,
                        duration: 15,
                        status: .completed,
                        notes: "Discussed academic progress and study strategies.",
                        location: "Room 101"
                    ))
                }
            }

            teacherAvailableSlots = slots
            conferences = confs

        } else if currentUser.role == .teacher {
            var slots: [TeacherAvailableSlot] = []
            var confs: [Conference] = []

            for dayOffset in [1, 3, 5, 7, 10, 12] {
                guard let slotDate = calendar.date(byAdding: .day, value: dayOffset, to: Date()),
                      let dateWithTime = calendar.date(bySettingHour: 14, minute: 0, second: 0, of: slotDate) else { continue }

                let isBooked = dayOffset <= 3
                slots.append(TeacherAvailableSlot(
                    teacherId: currentUser.id,
                    date: dateWithTime,
                    durationMinutes: 15,
                    isBooked: isBooked
                ))

                if isBooked {
                    confs.append(Conference(
                        parentId: UUID(),
                        teacherId: currentUser.id,
                        teacherName: currentUser.fullName,
                        parentName: "Maria Rivera",
                        childName: "Alex Rivera",
                        date: dateWithTime,
                        duration: 15,
                        status: dayOffset == 1 ? .requested : .confirmed,
                        notes: "Regarding recent test scores",
                        location: "Room 101"
                    ))
                }
            }

            teacherAvailableSlots = slots
            conferences = confs
        }
    }

    // MARK: - Helpers

    private func scheduleConferenceNotification(conference: Conference, message: String) {
        let content = UNMutableNotificationContent()
        content.title = "Conference Update"
        content.body = message
        content.sound = .default
        content.categoryIdentifier = "CONFERENCE"

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "conference-\(conference.id.uuidString)",
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }

    private func formatDateShort(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}
