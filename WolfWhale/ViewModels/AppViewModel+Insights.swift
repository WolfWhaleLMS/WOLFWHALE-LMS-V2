import Foundation

// MARK: - At-Risk Student Models

nonisolated enum RiskLevel: String, Sendable, Comparable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"

    nonisolated static func < (lhs: RiskLevel, rhs: RiskLevel) -> Bool {
        let order: [RiskLevel] = [.low, .medium, .high]
        return (order.firstIndex(of: lhs) ?? 0) < (order.firstIndex(of: rhs) ?? 0)
    }
}

nonisolated struct AtRiskStudent: Identifiable, Sendable {
    let id: UUID
    let studentId: UUID
    let studentName: String
    let currentGrade: Double
    let riskFactors: [String]
    let riskLevel: RiskLevel

    init(studentId: UUID, studentName: String, currentGrade: Double, riskFactors: [String], riskLevel: RiskLevel) {
        self.id = studentId
        self.studentId = studentId
        self.studentName = studentName
        self.currentGrade = currentGrade
        self.riskFactors = riskFactors
        self.riskLevel = riskLevel
    }
}

// NOTE: GradeTrend enum is defined in GradeModels.swift

// MARK: - Student Insight (per-student analytics)

nonisolated struct StudentInsight: Identifiable, Sendable {
    let id: UUID
    let studentId: UUID
    let studentName: String
    let currentGrade: Double
    let gradeTrend: GradeTrend
    let attendanceRate: Double
    let submissionRate: Double
    let lastActiveDate: Date
    let gradeHistory: [Double]
    let isAtRisk: Bool
    let riskFactors: [String]
    let riskLevel: RiskLevel?
}

// MARK: - Sort Options

enum StudentInsightSortOption: String, CaseIterable, Identifiable {
    case gradeAsc = "Grade (Low to High)"
    case gradeDesc = "Grade (High to Low)"
    case trendDeclining = "Trend (Declining First)"
    case attendanceAsc = "Attendance (Low to High)"
    case name = "Name (A-Z)"

    var id: String { rawValue }
}

// MARK: - AppViewModel Insights Extension

extension AppViewModel {

    // MARK: - At-Risk Students

    /// Returns students who are at risk in a given course based on defined criteria:
    /// - Grade below 70% AND declining trend
    /// - OR missing 3+ consecutive assignments
    /// - OR attendance below 80%
    func atRiskStudents(for courseId: UUID) -> [AtRiskStudent] {
        let insights = studentInsights(for: courseId)
        return insights.compactMap { insight -> AtRiskStudent? in
            guard insight.isAtRisk else { return nil }
            return AtRiskStudent(
                studentId: insight.studentId,
                studentName: insight.studentName,
                currentGrade: insight.currentGrade,
                riskFactors: insight.riskFactors,
                riskLevel: insight.riskLevel ?? .low
            )
        }
        .sorted { $0.riskLevel > $1.riskLevel }
    }

    /// Refreshes the cached at-risk students list. Call after data loads or changes.
    func refreshAtRiskStudentsCache() {
        cachedAtRiskStudents = allAtRiskStudents()
    }

    /// Returns all at-risk students across all courses the teacher owns.
    func allAtRiskStudents() -> [AtRiskStudent] {
        var seen = Set<UUID>()
        var result: [AtRiskStudent] = []
        for course in courses {
            for student in atRiskStudents(for: course.id) {
                if !seen.contains(student.studentId) {
                    seen.insert(student.studentId)
                    result.append(student)
                }
            }
        }
        return result.sorted { $0.riskLevel > $1.riskLevel }
    }

    // MARK: - Student Insights

    /// Computes per-student analytics for a given course.
    func studentInsights(for courseId: UUID) -> [StudentInsight] {
        let courseAssignments = assignments.filter { $0.courseId == courseId }
        let courseName = courses.first(where: { $0.id == courseId })?.title ?? ""

        // Gather unique students from assignments (teacher view shows all student submissions)
        var studentMap: [String: (id: UUID, assignments: [Assignment])] = [:]
        for assignment in courseAssignments {
            let name = assignment.studentName ?? "Unknown Student"
            let sid = assignment.studentId ?? UUID()
            if studentMap[name] == nil {
                studentMap[name] = (id: sid, assignments: [])
            }
            studentMap[name]?.assignments.append(assignment)
        }

        // Also gather attendance data for this course
        let courseAttendance = attendance.filter { $0.courseName == courseName }

        return studentMap.map { (name, info) in
            let studentAssignments = info.assignments.sorted { $0.dueDate < $1.dueDate }

            // Current grade: average of graded assignments
            let gradedAssignments = studentAssignments.filter { $0.grade != nil }
            let currentGrade: Double
            if gradedAssignments.isEmpty {
                currentGrade = 0
            } else {
                currentGrade = gradedAssignments.reduce(0.0) { $0 + ($1.grade ?? 0) } / Double(gradedAssignments.count)
            }

            // Grade history (chronological grades for sparkline)
            let gradeHistory = gradedAssignments.compactMap { $0.grade }

            // Grade trend
            let gradeTrend = Self.calculateTrend(grades: gradeHistory)

            // Attendance rate
            let studentAttendance = courseAttendance.filter { $0.studentName == name }
            let attendanceRate: Double
            if studentAttendance.isEmpty {
                attendanceRate = 1.0 // No records means we assume present
            } else {
                let presentCount = studentAttendance.filter { $0.status == .present || $0.status == .tardy }.count
                attendanceRate = Double(presentCount) / Double(studentAttendance.count)
            }

            // Submission rate
            let totalAssignments = studentAssignments.count
            let submittedCount = studentAssignments.filter { $0.isSubmitted }.count
            let submissionRate: Double = totalAssignments > 0 ? Double(submittedCount) / Double(totalAssignments) : 1.0

            // Last active date: most recent submission or attendance
            let lastSubmissionDate = studentAssignments.filter { $0.isSubmitted }.max(by: { $0.dueDate < $1.dueDate })?.dueDate
            let lastAttendanceDate = studentAttendance.max(by: { $0.date < $1.date })?.date
            let lastActiveDate: Date
            if let sub = lastSubmissionDate, let att = lastAttendanceDate {
                lastActiveDate = max(sub, att)
            } else {
                lastActiveDate = lastSubmissionDate ?? lastAttendanceDate ?? Date()
            }

            // Consecutive missed assignments
            let consecutiveMissed = Self.consecutiveMissedAssignments(studentAssignments)

            // At-risk evaluation
            var riskFactors: [String] = []

            // Criterion 1: Grade below 70% AND declining trend
            if currentGrade < 70 && gradeTrend == .declining && !gradedAssignments.isEmpty {
                riskFactors.append("Grade below 70% with declining trend")
            }

            // Criterion 2: Missing 3+ consecutive assignments
            if consecutiveMissed >= 3 {
                riskFactors.append("Missing \(consecutiveMissed) consecutive assignments")
            }

            // Criterion 3: Attendance below 80%
            if attendanceRate < 0.80 && !studentAttendance.isEmpty {
                riskFactors.append("Attendance below 80% (\(Int(attendanceRate * 100))%)")
            }

            let isAtRisk = !riskFactors.isEmpty

            // Risk level based on number and severity of factors
            let riskLevel: RiskLevel?
            if !isAtRisk {
                riskLevel = nil
            } else if riskFactors.count >= 3 || (currentGrade < 50 && gradeTrend == .declining) {
                riskLevel = .high
            } else if riskFactors.count >= 2 || currentGrade < 60 {
                riskLevel = .medium
            } else {
                riskLevel = .low
            }

            return StudentInsight(
                id: info.id,
                studentId: info.id,
                studentName: name,
                currentGrade: currentGrade,
                gradeTrend: gradeTrend,
                attendanceRate: attendanceRate,
                submissionRate: submissionRate,
                lastActiveDate: lastActiveDate,
                gradeHistory: gradeHistory,
                isAtRisk: isAtRisk,
                riskFactors: riskFactors,
                riskLevel: riskLevel
            )
        }
    }

    // MARK: - Helpers

    /// Calculates grade trend from a sequence of grades.
    /// Uses simple linear regression slope on the last several grades.
    private static func calculateTrend(grades: [Double]) -> GradeTrend {
        guard grades.count >= 2 else { return .stable }

        // Use last 5 grades for trend analysis
        let recent = Array(grades.suffix(5))
        let n = Double(recent.count)

        // Simple linear regression: slope of y = mx + b
        let xMean = (n - 1) / 2.0
        let yMean = recent.reduce(0, +) / n

        var numerator = 0.0
        var denominator = 0.0
        for (i, grade) in recent.enumerated() {
            let x = Double(i)
            numerator += (x - xMean) * (grade - yMean)
            denominator += (x - xMean) * (x - xMean)
        }

        guard denominator > 0 else { return .stable }
        let slope = numerator / denominator

        // Threshold: slope > 2 per assignment = improving, < -2 = declining
        if slope > 2.0 {
            return .improving
        } else if slope < -2.0 {
            return .declining
        } else {
            return .stable
        }
    }

    /// Counts the maximum run of consecutive unsubmitted assignments sorted by due date,
    /// looking from the most recent backward.
    private static func consecutiveMissedAssignments(_ assignments: [Assignment]) -> Int {
        // Sort by due date descending (most recent first)
        let sorted = assignments.sorted { $0.dueDate > $1.dueDate }
        var count = 0
        for assignment in sorted {
            // Only count past-due assignments that were not submitted
            if assignment.dueDate < Date() && !assignment.isSubmitted {
                count += 1
            } else {
                break
            }
        }
        return count
    }
}
