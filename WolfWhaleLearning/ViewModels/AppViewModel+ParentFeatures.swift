import Foundation
import UserNotifications

// MARK: - Conference Scheduling, Absence Alerts & Weekly Digest

extension AppViewModel {

    // MARK: - Conference Properties (stored as arrays on AppViewModel)

    // NOTE: conferences and teacherAvailableSlots are declared as stored
    // properties in this extension file's companion section below the class.
    // Because Swift @Observable requires stored properties on the class itself,
    // we use a lightweight wrapper pattern: the views call these methods
    // which operate on the `conferences` and `teacherAvailableSlots` arrays
    // that are added to AppViewModel via the stored-property block at the bottom.

    // MARK: - Parent: Book Conference

    /// Parent requests a conference with a teacher for a specific child.
    func bookConference(
        teacherId: UUID,
        teacherName: String,
        childName: String,
        slotId: UUID,
        notes: String?
    ) {
        guard let user = currentUser, user.role == .parent else { return }

        // Mark the slot as booked
        if let slotIndex = teacherAvailableSlots.firstIndex(where: { $0.id == slotId }) {
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

            // Send a local notification about the booking
            scheduleConferenceNotification(conference: conference, message: "Conference requested with \(teacherName) for \(childName).")
        }
    }

    /// Parent cancels a conference.
    func cancelConference(_ conferenceId: UUID) {
        guard let index = conferences.firstIndex(where: { $0.id == conferenceId }) else { return }
        conferences[index].status = .cancelled

        // Free up the slot
        let conference = conferences[index]
        if let slotIndex = teacherAvailableSlots.firstIndex(where: {
            $0.teacherId == conference.teacherId &&
            Calendar.current.isDate($0.date, equalTo: conference.date, toGranularity: .minute)
        }) {
            teacherAvailableSlots[slotIndex].isBooked = false
        }
    }

    // MARK: - Teacher: Manage Availability

    /// Teacher adds an available time slot for conferences.
    func addAvailableSlot(date: Date, durationMinutes: Int = 15) {
        guard let user = currentUser, user.role == .teacher else { return }

        let slot = TeacherAvailableSlot(
            teacherId: user.id,
            date: date,
            durationMinutes: durationMinutes
        )
        teacherAvailableSlots.append(slot)
    }

    /// Teacher removes an available time slot.
    func removeAvailableSlot(_ slotId: UUID) {
        teacherAvailableSlots.removeAll { $0.id == slotId }
    }

    /// Teacher approves a conference request.
    func approveConference(_ conferenceId: UUID) {
        guard let index = conferences.firstIndex(where: { $0.id == conferenceId }) else { return }
        conferences[index].status = .confirmed

        let conf = conferences[index]
        scheduleConferenceNotification(
            conference: conf,
            message: "Your conference with \(conf.teacherName) regarding \(conf.childName) has been confirmed for \(conf.timeSlotLabel)."
        )
    }

    /// Teacher declines a conference request.
    func declineConference(_ conferenceId: UUID) {
        guard let index = conferences.firstIndex(where: { $0.id == conferenceId }) else { return }
        conferences[index].status = .cancelled

        // Free the slot
        let conf = conferences[index]
        if let slotIndex = teacherAvailableSlots.firstIndex(where: {
            $0.teacherId == conf.teacherId &&
            Calendar.current.isDate($0.date, equalTo: conf.date, toGranularity: .minute)
        }) {
            teacherAvailableSlots[slotIndex].isBooked = false
        }
    }

    /// Conferences for the current user (parent sees their conferences, teacher sees theirs).
    var myConferences: [Conference] {
        guard let user = currentUser else { return [] }
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
    var upcomingConferences: [Conference] {
        myConferences
            .filter { $0.isUpcoming }
            .sorted { $0.date < $1.date }
    }

    /// Past/completed conferences for the current user.
    var pastConferences: [Conference] {
        myConferences
            .filter { !$0.isUpcoming }
            .sorted { $0.date > $1.date }
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
            // Find parent-linked children that match the absent student
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

                // Push a local notification immediately
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

    // MARK: - Demo Data Loaders

    /// Loads demo conference and slot data for the current user's role.
    func loadDemoConferenceData() {
        guard let user = currentUser else { return }
        let calendar = Calendar.current

        if user.role == .parent {
            // Generate some demo teacher availability slots
            let teacherNames = courses.isEmpty
                ? ["Dr. Sarah Chen", "Mr. David Park", "Ms. Emily Torres"]
                : courses.map(\.teacherName)
            let uniqueTeachers = Array(Set(teacherNames))

            var slots: [TeacherAvailableSlot] = []
            var confs: [Conference] = []

            for (tIndex, teacherName) in uniqueTeachers.enumerated() {
                let teacherId = UUID()
                // Generate 3 available slots per teacher over the next 2 weeks
                for dayOffset in [2, 5, 8] {
                    guard let slotDate = calendar.date(byAdding: .day, value: dayOffset, to: Date()) else { continue }
                    let hour = 9 + tIndex  // stagger hours: 9 AM, 10 AM, 11 AM
                    guard let dateWithTime = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: slotDate) else { continue }

                    slots.append(TeacherAvailableSlot(
                        teacherId: teacherId,
                        date: dateWithTime,
                        durationMinutes: 15
                    ))
                }

                // Add one confirmed conference in the past
                if let pastDate = calendar.date(byAdding: .day, value: -3, to: Date()),
                   let pastWithTime = calendar.date(bySettingHour: 10, minute: 0, second: 0, of: pastDate) {
                    let childName = children.first?.name ?? "Alex Rivera"
                    confs.append(Conference(
                        parentId: user.id,
                        teacherId: teacherId,
                        teacherName: teacherName,
                        parentName: user.fullName,
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

        } else if user.role == .teacher {
            // Generate teacher-side availability
            var slots: [TeacherAvailableSlot] = []
            var confs: [Conference] = []

            for dayOffset in [1, 3, 5, 7, 10, 12] {
                guard let slotDate = calendar.date(byAdding: .day, value: dayOffset, to: Date()),
                      let dateWithTime = calendar.date(bySettingHour: 14, minute: 0, second: 0, of: slotDate) else { continue }

                let isBooked = dayOffset <= 3  // first two are booked
                slots.append(TeacherAvailableSlot(
                    teacherId: user.id,
                    date: dateWithTime,
                    durationMinutes: 15,
                    isBooked: isBooked
                ))

                if isBooked {
                    confs.append(Conference(
                        parentId: UUID(),
                        teacherId: user.id,
                        teacherName: user.fullName,
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
