import Foundation
import SwiftUI

// MARK: - Academic Calendar Backing Storage

/// Thread-safe backing store for academic calendar data.
/// Used because Swift extensions cannot add stored properties to @Observable classes.
@MainActor
final class AcademicCalendarStore {
    static let shared = AcademicCalendarStore()
    var calendarConfig: AcademicCalendarConfig?
    var reportCardComments: [ReportCardComment] = []
    private init() {}
}

// MARK: - Academic Calendar & Report Card

extension AppViewModel {

    // MARK: - Calendar Config Access

    /// The current academic calendar configuration.
    /// In production this would be loaded from Supabase; in demo mode we provide sample data.
    var academicCalendarConfig: AcademicCalendarConfig {
        AcademicCalendarStore.shared.calendarConfig ?? Self.demoAcademicCalendar
    }

    // MARK: - Report Card Comments Access

    var reportCardComments: [ReportCardComment] {
        AcademicCalendarStore.shared.reportCardComments
    }

    // MARK: - Load Academic Calendar

    func loadAcademicCalendar() async {
        if isDemoMode {
            AcademicCalendarStore.shared.calendarConfig = Self.demoAcademicCalendar
            return
        }
        // Production: load from Supabase; fallback to demo
        AcademicCalendarStore.shared.calendarConfig = Self.demoAcademicCalendar
    }

    // MARK: - Add / Edit / Delete Terms

    func addTerm(_ term: AcademicTerm) {
        var config = AcademicCalendarStore.shared.calendarConfig ?? AcademicCalendarConfig()
        config.terms.append(term)
        AcademicCalendarStore.shared.calendarConfig = config
    }

    func updateTerm(_ term: AcademicTerm) {
        var config = AcademicCalendarStore.shared.calendarConfig ?? AcademicCalendarConfig()
        if let index = config.terms.firstIndex(where: { $0.id == term.id }) {
            config.terms[index] = term
        }
        AcademicCalendarStore.shared.calendarConfig = config
    }

    func deleteTerm(_ termId: UUID) {
        var config = AcademicCalendarStore.shared.calendarConfig ?? AcademicCalendarConfig()
        config.terms.removeAll { $0.id == termId }
        config.gradingPeriods.removeAll { $0.termId == termId }
        AcademicCalendarStore.shared.calendarConfig = config
    }

    // MARK: - Add / Edit / Delete Events

    func addEvent(_ event: AcademicEvent) {
        var config = AcademicCalendarStore.shared.calendarConfig ?? AcademicCalendarConfig()
        config.events.append(event)
        AcademicCalendarStore.shared.calendarConfig = config
    }

    func updateEvent(_ event: AcademicEvent) {
        var config = AcademicCalendarStore.shared.calendarConfig ?? AcademicCalendarConfig()
        if let index = config.events.firstIndex(where: { $0.id == event.id }) {
            config.events[index] = event
        }
        AcademicCalendarStore.shared.calendarConfig = config
    }

    func deleteEvent(_ eventId: UUID) {
        var config = AcademicCalendarStore.shared.calendarConfig ?? AcademicCalendarConfig()
        config.events.removeAll { $0.id == eventId }
        AcademicCalendarStore.shared.calendarConfig = config
    }

    // MARK: - Add / Edit / Delete Grading Periods

    func addGradingPeriod(_ period: GradingPeriod) {
        var config = AcademicCalendarStore.shared.calendarConfig ?? AcademicCalendarConfig()
        config.gradingPeriods.append(period)
        AcademicCalendarStore.shared.calendarConfig = config
    }

    func updateGradingPeriod(_ period: GradingPeriod) {
        var config = AcademicCalendarStore.shared.calendarConfig ?? AcademicCalendarConfig()
        if let index = config.gradingPeriods.firstIndex(where: { $0.id == period.id }) {
            config.gradingPeriods[index] = period
        }
        AcademicCalendarStore.shared.calendarConfig = config
    }

    func deleteGradingPeriod(_ periodId: UUID) {
        var config = AcademicCalendarStore.shared.calendarConfig ?? AcademicCalendarConfig()
        config.gradingPeriods.removeAll { $0.id == periodId }
        AcademicCalendarStore.shared.calendarConfig = config
    }

    // MARK: - Report Card Comments CRUD

    func addReportCardComment(_ comment: ReportCardComment) {
        let store = AcademicCalendarStore.shared
        store.reportCardComments.removeAll {
            $0.studentId == comment.studentId && $0.courseId == comment.courseId && $0.termId == comment.termId
        }
        store.reportCardComments.append(comment)
    }

    func reportCardComment(studentId: UUID, courseId: UUID, termId: UUID) -> ReportCardComment? {
        reportCardComments.first {
            $0.studentId == studentId && $0.courseId == courseId && $0.termId == termId
        }
    }

    // MARK: - Generate Report Card

    func generateReportCard(for studentId: UUID, termId: UUID) -> ReportCardEntry? {
        let config = academicCalendarConfig
        guard let term = config.terms.first(where: { $0.id == termId }) else { return nil }

        let studentName: String
        if let user = allUsers.first(where: { $0.id == studentId }) {
            studentName = user.fullName ?? "\(user.firstName ?? "") \(user.lastName ?? "")"
        } else if let current = currentUser, current.id == studentId {
            studentName = current.fullName
        } else {
            studentName = "Student"
        }

        let courseEntries: [ReportCardCourseEntry] = grades.map { grade in
            let comment = reportCardComment(studentId: studentId, courseId: grade.courseId, termId: termId)
            let teacherName = courses.first(where: { $0.id == grade.courseId })?.teacherName ?? "Teacher"
            return ReportCardCourseEntry(
                courseId: grade.courseId,
                courseName: grade.courseName,
                teacherName: teacherName,
                numericGrade: grade.numericGrade,
                letterGrade: grade.letterGrade,
                teacherComment: comment?.comment
            )
        }

        let gpa: Double
        if courseEntries.isEmpty {
            gpa = 0
        } else {
            gpa = courseEntries.reduce(0) { $0 + $1.numericGrade } / Double(courseEntries.count)
        }

        let studentAttendance = attendance
        let attendanceSummary = ReportCardAttendance(
            presentCount: studentAttendance.filter { $0.status == .present }.count,
            absentCount: studentAttendance.filter { $0.status == .absent }.count,
            tardyCount: studentAttendance.filter { $0.status == .tardy }.count,
            excusedCount: studentAttendance.filter { $0.status == .excused }.count
        )

        return ReportCardEntry(
            studentId: studentId,
            studentName: studentName,
            termName: term.name,
            courseEntries: courseEntries,
            gpa: gpa,
            attendanceSummary: attendanceSummary
        )
    }

    func generateAllReportCards(termId: UUID) -> [ReportCardEntry] {
        let studentUsers = allUsers.filter { $0.role.lowercased() == "student" }
        if studentUsers.isEmpty, let current = currentUser {
            if let card = generateReportCard(for: current.id, termId: termId) {
                return [card]
            }
            return []
        }
        return studentUsers.compactMap { generateReportCard(for: $0.id, termId: termId) }
    }

    // MARK: - Comment Templates

    static let commentTemplates: [CommentTemplate] = [
        // Positive
        CommentTemplate(text: "Excellent work ethic and consistently high-quality submissions.", category: .positive),
        CommentTemplate(text: "Demonstrates strong understanding of the material.", category: .positive),
        CommentTemplate(text: "Outstanding participation in class discussions.", category: .positive),
        CommentTemplate(text: "Shows great creativity and critical thinking skills.", category: .positive),
        CommentTemplate(text: "A pleasure to have in class. Always prepared and engaged.", category: .positive),
        CommentTemplate(text: "Consistently goes above and beyond expectations.", category: .positive),
        CommentTemplate(text: "Has shown tremendous growth this term.", category: .positive),
        CommentTemplate(text: "Demonstrates excellent leadership and teamwork skills.", category: .positive),

        // Needs Improvement
        CommentTemplate(text: "Needs to participate more in class discussions.", category: .improvement),
        CommentTemplate(text: "Should focus on completing homework assignments on time.", category: .improvement),
        CommentTemplate(text: "Would benefit from additional study time and practice.", category: .improvement),
        CommentTemplate(text: "Attendance has been inconsistent and affects performance.", category: .improvement),
        CommentTemplate(text: "Needs to review feedback on assignments more carefully.", category: .improvement),
        CommentTemplate(text: "Should seek help during office hours when struggling.", category: .improvement),
        CommentTemplate(text: "Test preparation strategies need improvement.", category: .improvement),
        CommentTemplate(text: "Organization and time management skills need development.", category: .improvement),

        // General
        CommentTemplate(text: "Making steady progress throughout the term.", category: .general),
        CommentTemplate(text: "Performs well on tests but could improve daily work.", category: .general),
        CommentTemplate(text: "A quiet but attentive student.", category: .general),
        CommentTemplate(text: "Works well independently and collaboratively.", category: .general),
        CommentTemplate(text: "Has potential to achieve higher grades with more effort.", category: .general),
        CommentTemplate(text: "Adapts well to different learning activities.", category: .general),
    ]

    // MARK: - Demo Data

    static var demoAcademicCalendar: AcademicCalendarConfig {
        let calendar = Calendar.current
        let now = Date()
        let year = calendar.component(.year, from: now)
        let month = calendar.component(.month, from: now)

        let academicYearStart: Int
        let academicYearEnd: Int
        if month >= 8 {
            academicYearStart = year
            academicYearEnd = year + 1
        } else {
            academicYearStart = year - 1
            academicYearEnd = year
        }

        let fallTermId = UUID()
        let springTermId = UUID()

        let fallStart = calendar.date(from: DateComponents(year: academicYearStart, month: 9, day: 3))!
        let fallEnd = calendar.date(from: DateComponents(year: academicYearStart, month: 12, day: 20))!
        let springStart = calendar.date(from: DateComponents(year: academicYearEnd, month: 1, day: 8))!
        let springEnd = calendar.date(from: DateComponents(year: academicYearEnd, month: 6, day: 15))!

        let terms = [
            AcademicTerm(id: fallTermId, name: "Fall \(academicYearStart)", startDate: fallStart, endDate: fallEnd, type: .semester),
            AcademicTerm(id: springTermId, name: "Spring \(academicYearEnd)", startDate: springStart, endDate: springEnd, type: .semester),
        ]

        let events: [AcademicEvent] = [
            AcademicEvent(title: "Labour Day", date: calendar.date(from: DateComponents(year: academicYearStart, month: 9, day: 2))!, type: .holiday, description: "School closed"),
            AcademicEvent(title: "Thanksgiving", date: calendar.date(from: DateComponents(year: academicYearStart, month: 10, day: 14))!, type: .holiday, description: "School closed for Thanksgiving"),
            AcademicEvent(title: "Fall Midterm Exams", date: calendar.date(from: DateComponents(year: academicYearStart, month: 10, day: 21))!, endDate: calendar.date(from: DateComponents(year: academicYearStart, month: 10, day: 25))!, type: .examPeriod, description: "Midterm examination period"),
            AcademicEvent(title: "Midterm Grades Due", date: calendar.date(from: DateComponents(year: academicYearStart, month: 10, day: 30))!, type: .gradeDeadline, description: "All midterm grades must be submitted"),
            AcademicEvent(title: "Parent-Teacher Conferences", date: calendar.date(from: DateComponents(year: academicYearStart, month: 11, day: 7))!, endDate: calendar.date(from: DateComponents(year: academicYearStart, month: 11, day: 8))!, type: .parentConference, description: "Fall parent-teacher conference days"),
            AcademicEvent(title: "Winter Break", date: calendar.date(from: DateComponents(year: academicYearStart, month: 12, day: 21))!, endDate: calendar.date(from: DateComponents(year: academicYearEnd, month: 1, day: 7))!, type: .noSchool, description: "Winter holiday break"),
            AcademicEvent(title: "Fall Final Exams", date: calendar.date(from: DateComponents(year: academicYearStart, month: 12, day: 13))!, endDate: calendar.date(from: DateComponents(year: academicYearStart, month: 12, day: 19))!, type: .examPeriod, description: "Fall semester final exams"),
            AcademicEvent(title: "Fall Final Grades Due", date: calendar.date(from: DateComponents(year: academicYearStart, month: 12, day: 23))!, type: .gradeDeadline, description: "All fall final grades must be submitted"),
            AcademicEvent(title: "Science Fair", date: calendar.date(from: DateComponents(year: academicYearEnd, month: 3, day: 15))!, type: .schoolEvent, description: "Annual school science fair"),
            AcademicEvent(title: "Spring Break", date: calendar.date(from: DateComponents(year: academicYearEnd, month: 3, day: 17))!, endDate: calendar.date(from: DateComponents(year: academicYearEnd, month: 3, day: 21))!, type: .noSchool, description: "Spring break week"),
            AcademicEvent(title: "Spring Midterm Exams", date: calendar.date(from: DateComponents(year: academicYearEnd, month: 3, day: 24))!, endDate: calendar.date(from: DateComponents(year: academicYearEnd, month: 3, day: 28))!, type: .examPeriod, description: "Spring midterm exams"),
            AcademicEvent(title: "Spring Final Exams", date: calendar.date(from: DateComponents(year: academicYearEnd, month: 6, day: 9))!, endDate: calendar.date(from: DateComponents(year: academicYearEnd, month: 6, day: 13))!, type: .examPeriod, description: "Spring semester final exams"),
            AcademicEvent(title: "Spring Final Grades Due", date: calendar.date(from: DateComponents(year: academicYearEnd, month: 6, day: 18))!, type: .gradeDeadline, description: "All spring final grades must be submitted"),
        ]

        let gradingPeriods: [GradingPeriod] = [
            GradingPeriod(name: "Fall Midterm", termId: fallTermId, startDate: fallStart, endDate: calendar.date(from: DateComponents(year: academicYearStart, month: 10, day: 25))!, gradeSubmissionDeadline: calendar.date(from: DateComponents(year: academicYearStart, month: 10, day: 30))!),
            GradingPeriod(name: "Fall Final", termId: fallTermId, startDate: calendar.date(from: DateComponents(year: academicYearStart, month: 10, day: 26))!, endDate: fallEnd, gradeSubmissionDeadline: calendar.date(from: DateComponents(year: academicYearStart, month: 12, day: 23))!),
            GradingPeriod(name: "Spring Midterm", termId: springTermId, startDate: springStart, endDate: calendar.date(from: DateComponents(year: academicYearEnd, month: 3, day: 28))!, gradeSubmissionDeadline: calendar.date(from: DateComponents(year: academicYearEnd, month: 4, day: 2))!),
            GradingPeriod(name: "Spring Final", termId: springTermId, startDate: calendar.date(from: DateComponents(year: academicYearEnd, month: 3, day: 29))!, endDate: springEnd, gradeSubmissionDeadline: calendar.date(from: DateComponents(year: academicYearEnd, month: 6, day: 18))!),
        ]

        return AcademicCalendarConfig(terms: terms, events: events, gradingPeriods: gradingPeriods)
    }
}
