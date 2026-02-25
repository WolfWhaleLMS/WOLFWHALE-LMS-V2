import Foundation

// MARK: - Weekly Digest Service

/// Generates a weekly progress summary for a parent's child, aggregating
/// grades, assignments, attendance, and teacher feedback from the past week.
struct WeeklyDigestService {

    static let shared = WeeklyDigestService()

    /// Generates a digest for a single child using the app's current data.
    func generateDigest(
        child: ChildInfo,
        assignments: [Assignment],
        attendance: [AttendanceRecord],
        courses: [Course]
    ) -> WeeklyDigest {
        let calendar = Calendar.current
        let now = Date()
        let weekStart = calendar.date(byAdding: .day, value: -7, to: now) ?? now
        let weekEnd = now

        // MARK: - Grade Changes
        let gradeChanges: [WeeklyGradeChange] = child.courses.map { grade in
            // Simulate a previous grade slightly different from current
            // In production this would come from historical grade snapshots
            let previousGrade = max(0, grade.numericGrade + Double.random(in: -5...5))
            return WeeklyGradeChange(
                courseName: grade.courseName,
                previousGrade: previousGrade,
                currentGrade: grade.numericGrade,
                letterGrade: grade.letterGrade
            )
        }

        // MARK: - Assignments Completed This Week
        let completedThisWeek = assignments.filter { assignment in
            assignment.isSubmitted &&
            assignment.dueDate >= weekStart &&
            assignment.dueDate <= weekEnd
        }

        // MARK: - Assignments Due Next Week
        let nextWeekStart = weekEnd
        let nextWeekEnd = calendar.date(byAdding: .day, value: 7, to: weekEnd) ?? weekEnd

        let dueNextWeek: [DigestAssignment] = assignments
            .filter { !$0.isSubmitted && $0.dueDate >= nextWeekStart && $0.dueDate <= nextWeekEnd }
            .map { DigestAssignment(title: $0.title, courseName: $0.courseName, dueDate: $0.dueDate) }

        // MARK: - Attendance Summary
        let weekAttendance = attendance.filter { record in
            record.date >= weekStart && record.date <= weekEnd
        }

        let presentCount = weekAttendance.filter { $0.status == .present }.count
        let absentCount = weekAttendance.filter { $0.status == .absent }.count
        let tardyCount = weekAttendance.filter { $0.status == .tardy }.count

        let attendanceSummary = DigestAttendanceSummary(
            totalDays: max(weekAttendance.count, 1),
            presentDays: presentCount,
            absentDays: absentCount,
            tardyDays: tardyCount
        )

        // MARK: - Teacher Comments (from graded assignments with feedback)
        let teacherComments: [DigestTeacherComment] = assignments
            .filter { $0.isSubmitted && $0.feedback != nil && !($0.feedback?.isEmpty ?? true) }
            .filter { $0.dueDate >= weekStart && $0.dueDate <= weekEnd }
            .prefix(5)
            .map { assignment in
                let teacherName = courses.first(where: { $0.id == assignment.courseId })?.teacherName ?? "Teacher"
                return DigestTeacherComment(
                    teacherName: teacherName,
                    courseName: assignment.courseName,
                    comment: assignment.feedback ?? "",
                    date: assignment.dueDate
                )
            }

        return WeeklyDigest(
            childName: child.name,
            weekStartDate: weekStart,
            weekEndDate: weekEnd,
            gradeChanges: gradeChanges,
            assignmentsCompleted: completedThisWeek.count,
            assignmentsDueNextWeek: dueNextWeek,
            attendanceSummary: attendanceSummary,
            teacherComments: teacherComments
        )
    }

    /// Generates digests for all children.
    func generateDigests(
        children: [ChildInfo],
        assignments: [Assignment],
        attendance: [AttendanceRecord],
        courses: [Course]
    ) -> [WeeklyDigest] {
        children.map { child in
            generateDigest(
                child: child,
                assignments: assignments,
                attendance: attendance,
                courses: courses
            )
        }
    }

    /// Generates demo digest data for preview / demo mode.
    func generateDemoDigest(child: ChildInfo) -> WeeklyDigest {
        let calendar = Calendar.current
        let now = Date()
        let weekStart = calendar.date(byAdding: .day, value: -7, to: now) ?? now

        let gradeChanges = child.courses.map { grade in
            WeeklyGradeChange(
                courseName: grade.courseName,
                previousGrade: grade.numericGrade - Double.random(in: -3...5),
                currentGrade: grade.numericGrade,
                letterGrade: grade.letterGrade
            )
        }

        let dueNextWeek = [
            DigestAssignment(title: "Research Paper Draft", courseName: "English Literature", dueDate: calendar.date(byAdding: .day, value: 3, to: now) ?? now),
            DigestAssignment(title: "Lab Report #5", courseName: "AP Biology", dueDate: calendar.date(byAdding: .day, value: 5, to: now) ?? now),
            DigestAssignment(title: "Problem Set 12", courseName: "Algebra II", dueDate: calendar.date(byAdding: .day, value: 6, to: now) ?? now),
        ]

        let attendanceSummary = DigestAttendanceSummary(
            totalDays: 5,
            presentDays: 4,
            absentDays: 0,
            tardyDays: 1
        )

        let teacherComments = [
            DigestTeacherComment(
                teacherName: "Dr. Sarah Chen",
                courseName: "Algebra II",
                comment: "Great improvement on the last quiz! Keep up the good work.",
                date: calendar.date(byAdding: .day, value: -2, to: now) ?? now
            ),
            DigestTeacherComment(
                teacherName: "Mr. David Park",
                courseName: "AP Biology",
                comment: "Excellent lab report. Very thorough analysis section.",
                date: calendar.date(byAdding: .day, value: -4, to: now) ?? now
            ),
        ]

        return WeeklyDigest(
            childName: child.name,
            weekStartDate: weekStart,
            weekEndDate: now,
            gradeChanges: gradeChanges,
            assignmentsCompleted: 4,
            assignmentsDueNextWeek: dueNextWeek,
            attendanceSummary: attendanceSummary,
            teacherComments: teacherComments
        )
    }
}
