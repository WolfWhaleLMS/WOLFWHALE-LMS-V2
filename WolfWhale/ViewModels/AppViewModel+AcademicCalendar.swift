import Foundation
import SwiftUI

// MARK: - Academic Calendar Backing Storage
// Kept for backward compatibility with any code that references AcademicCalendarStore directly.

@MainActor
final class AcademicCalendarStore {
    static let shared = AcademicCalendarStore()
    var calendarConfig: AcademicCalendarConfig?
    var reportCardComments: [ReportCardComment] = []
    private init() {}
}

// MARK: - Academic Calendar & Report Card (Delegating to AcademicCalendarViewModel)

extension AppViewModel {

    // MARK: - Calendar Config Access (delegates to sub-VM)

    var academicCalendarConfig: AcademicCalendarConfig {
        academicCalendarVM.academicCalendarConfig
    }

    // MARK: - Report Card Comments Access (delegates to sub-VM)

    var reportCardComments: [ReportCardComment] {
        academicCalendarVM.reportCardComments
    }

    // MARK: - Load Academic Calendar (delegates to sub-VM)

    func loadAcademicCalendar() async {
        await academicCalendarVM.loadAcademicCalendar(isDemoMode: isDemoMode)
        // Keep the legacy backing store in sync
        AcademicCalendarStore.shared.calendarConfig = academicCalendarVM.calendarConfig
    }

    // MARK: - Add / Edit / Delete Terms (delegates to sub-VM)

    func addTerm(_ term: AcademicTerm) {
        academicCalendarVM.addTerm(term)
        AcademicCalendarStore.shared.calendarConfig = academicCalendarVM.calendarConfig
    }

    func updateTerm(_ term: AcademicTerm) {
        academicCalendarVM.updateTerm(term)
        AcademicCalendarStore.shared.calendarConfig = academicCalendarVM.calendarConfig
    }

    func deleteTerm(_ termId: UUID) {
        academicCalendarVM.deleteTerm(termId)
        AcademicCalendarStore.shared.calendarConfig = academicCalendarVM.calendarConfig
    }

    // MARK: - Add / Edit / Delete Events (delegates to sub-VM)

    func addEvent(_ event: AcademicEvent) {
        academicCalendarVM.addEvent(event)
        AcademicCalendarStore.shared.calendarConfig = academicCalendarVM.calendarConfig
    }

    func updateEvent(_ event: AcademicEvent) {
        academicCalendarVM.updateEvent(event)
        AcademicCalendarStore.shared.calendarConfig = academicCalendarVM.calendarConfig
    }

    func deleteEvent(_ eventId: UUID) {
        academicCalendarVM.deleteEvent(eventId)
        AcademicCalendarStore.shared.calendarConfig = academicCalendarVM.calendarConfig
    }

    // MARK: - Add / Edit / Delete Grading Periods (delegates to sub-VM)

    func addGradingPeriod(_ period: GradingPeriod) {
        academicCalendarVM.addGradingPeriod(period)
        AcademicCalendarStore.shared.calendarConfig = academicCalendarVM.calendarConfig
    }

    func updateGradingPeriod(_ period: GradingPeriod) {
        academicCalendarVM.updateGradingPeriod(period)
        AcademicCalendarStore.shared.calendarConfig = academicCalendarVM.calendarConfig
    }

    func deleteGradingPeriod(_ periodId: UUID) {
        academicCalendarVM.deleteGradingPeriod(periodId)
        AcademicCalendarStore.shared.calendarConfig = academicCalendarVM.calendarConfig
    }

    // MARK: - Report Card Comments CRUD (delegates to sub-VM)

    func addReportCardComment(_ comment: ReportCardComment) {
        academicCalendarVM.addReportCardComment(comment)
        AcademicCalendarStore.shared.reportCardComments = academicCalendarVM.reportCardComments
    }

    func reportCardComment(studentId: UUID, courseId: UUID, termId: UUID) -> ReportCardComment? {
        academicCalendarVM.reportCardComment(studentId: studentId, courseId: courseId, termId: termId)
    }

    // MARK: - Generate Report Card (delegates to sub-VM)

    func generateReportCard(for studentId: UUID, termId: UUID) -> ReportCardEntry? {
        academicCalendarVM.generateReportCard(
            for: studentId,
            termId: termId,
            grades: grades,
            courses: courses,
            attendance: attendance,
            allUsers: allUsers,
            currentUser: currentUser
        )
    }

    func generateAllReportCards(termId: UUID) -> [ReportCardEntry] {
        academicCalendarVM.generateAllReportCards(
            termId: termId,
            grades: grades,
            courses: courses,
            attendance: attendance,
            allUsers: allUsers,
            currentUser: currentUser
        )
    }

    // MARK: - Comment Templates (delegates to sub-VM)

    static let commentTemplates: [CommentTemplate] = AcademicCalendarViewModel.commentTemplates

    // MARK: - Demo Data (delegates to sub-VM)

    static var demoAcademicCalendar: AcademicCalendarConfig {
        AcademicCalendarViewModel.demoAcademicCalendar
    }
}
