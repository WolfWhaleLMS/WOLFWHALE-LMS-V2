import Foundation
import UserNotifications

// MARK: - Conference Scheduling, Absence Alerts & Weekly Digest (Delegating to ParentFeaturesViewModel)

extension AppViewModel {

    // MARK: - Conference Data Loading (delegates to sub-VM)

    func loadConferencesIfNeeded() async {
        // Sync parent data to the sub-VM
        parentFeaturesVM.children = children
        parentFeaturesVM.conferences = conferences
        parentFeaturesVM.teacherAvailableSlots = teacherAvailableSlots

        await parentFeaturesVM.loadConferencesIfNeeded(currentUser: currentUser, isDemoMode: isDemoMode, courses: courses)

        // Pull state back
        conferences = parentFeaturesVM.conferences
        teacherAvailableSlots = parentFeaturesVM.teacherAvailableSlots
    }

    // MARK: - Parent: Book Conference (delegates to sub-VM)

    func bookConference(
        teacherId: UUID,
        teacherName: String,
        childName: String,
        slotId: UUID,
        notes: String?
    ) {
        parentFeaturesVM.children = children
        parentFeaturesVM.conferences = conferences
        parentFeaturesVM.teacherAvailableSlots = teacherAvailableSlots

        parentFeaturesVM.bookConference(
            teacherId: teacherId,
            teacherName: teacherName,
            childName: childName,
            slotId: slotId,
            notes: notes,
            currentUser: currentUser
        )

        conferences = parentFeaturesVM.conferences
        teacherAvailableSlots = parentFeaturesVM.teacherAvailableSlots
    }

    /// Parent cancels a conference. (delegates to sub-VM)
    func cancelConference(_ conferenceId: UUID) {
        parentFeaturesVM.conferences = conferences
        parentFeaturesVM.teacherAvailableSlots = teacherAvailableSlots

        parentFeaturesVM.cancelConference(conferenceId)

        conferences = parentFeaturesVM.conferences
        teacherAvailableSlots = parentFeaturesVM.teacherAvailableSlots
    }

    // MARK: - Teacher: Manage Availability (delegates to sub-VM)

    func addAvailableSlot(date: Date, durationMinutes: Int = 15) {
        parentFeaturesVM.teacherAvailableSlots = teacherAvailableSlots

        parentFeaturesVM.addAvailableSlot(date: date, durationMinutes: durationMinutes, currentUser: currentUser)

        teacherAvailableSlots = parentFeaturesVM.teacherAvailableSlots
    }

    func removeAvailableSlot(_ slotId: UUID) {
        parentFeaturesVM.teacherAvailableSlots = teacherAvailableSlots

        parentFeaturesVM.removeAvailableSlot(slotId)

        teacherAvailableSlots = parentFeaturesVM.teacherAvailableSlots
    }

    /// Teacher approves a conference request. (delegates to sub-VM)
    func approveConference(_ conferenceId: UUID) {
        parentFeaturesVM.conferences = conferences

        parentFeaturesVM.approveConference(conferenceId)

        conferences = parentFeaturesVM.conferences
    }

    /// Teacher declines a conference request. (delegates to sub-VM)
    func declineConference(_ conferenceId: UUID) {
        parentFeaturesVM.conferences = conferences
        parentFeaturesVM.teacherAvailableSlots = teacherAvailableSlots

        parentFeaturesVM.declineConference(conferenceId)

        conferences = parentFeaturesVM.conferences
        teacherAvailableSlots = parentFeaturesVM.teacherAvailableSlots
    }

    /// Conferences for the current user (parent sees their conferences, teacher sees theirs).
    var myConferences: [Conference] {
        parentFeaturesVM.conferences = conferences
        return parentFeaturesVM.myConferences(for: currentUser)
    }

    /// Upcoming conferences for the current user, sorted by date.
    var upcomingConferences: [Conference] {
        parentFeaturesVM.conferences = conferences
        return parentFeaturesVM.upcomingConferences(for: currentUser)
    }

    /// Past/completed conferences for the current user.
    var pastConferences: [Conference] {
        parentFeaturesVM.conferences = conferences
        return parentFeaturesVM.pastConferences(for: currentUser)
    }

    // MARK: - Real-Time Absence Alert (delegates to sub-VM)

    func triggerAbsenceAlerts(
        absentStudentNames: [(studentId: UUID, studentName: String)],
        courseName: String,
        date: Date
    ) {
        parentFeaturesVM.absenceAlertEnabled = absenceAlertEnabled
        parentFeaturesVM.children = children
        parentFeaturesVM.parentAlerts = parentAlerts

        parentFeaturesVM.triggerAbsenceAlerts(
            absentStudentNames: absentStudentNames,
            courseName: courseName,
            date: date
        )

        parentAlerts = parentFeaturesVM.parentAlerts
    }

    // MARK: - Demo Data Loaders (delegates to sub-VM)

    func loadDemoConferenceData() {
        guard let user = currentUser else { return }
        parentFeaturesVM.children = children

        parentFeaturesVM.loadDemoConferenceData(currentUser: user, courses: courses)

        conferences = parentFeaturesVM.conferences
        teacherAvailableSlots = parentFeaturesVM.teacherAvailableSlots
    }
}
