import Foundation
import Supabase

@MainActor @Observable
final class EnrollmentService {

    // MARK: - State

    var error: String?
    var isLoading = false
    var catalogCourses: [CourseCatalogEntry] = []
    var pendingRequests: [EnrollmentRequest] = []   // For teachers
    var myEnrollments: [EnrollmentRequest] = []     // For students

    private let dataService = DataService.shared

    // MARK: - Date Helpers

    private let iso8601: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }()

    private func parseDate(_ str: String?) -> Date {
        guard let str else { return Date() }
        return iso8601.date(from: str)
            ?? dateFormatter.date(from: str)
            ?? Date()
    }

    private func formatDate(_ date: Date) -> String {
        iso8601.string(from: date)
    }

    // MARK: - Student: Fetch Course Catalog

    /// Fetches all courses available in the tenant for the catalog view.
    /// Resolves current enrollment counts, teacher names, and the student's enrollment status per course.
    func fetchCourseCatalog(tenantId: UUID) async {
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            // Fetch all courses in the tenant
            let courseDTOs: [CourseDTO] = try await supabaseClient
                .from("courses")
                .select()
                .eq("tenant_id", value: tenantId.uuidString)
                .execute()
                .value

            if courseDTOs.isEmpty {
                catalogCourses = []
                return
            }

            let courseIds = courseDTOs.map(\.id)

            // Batch fetch enrollment counts
            let allEnrollments: [EnrollmentDTO] = try await supabaseClient
                .from("course_enrollments")
                .select()
                .in("course_id", values: courseIds.map(\.uuidString))
                .execute()
                .value

            var enrollmentCountByCourse: [UUID: Int] = [:]
            for enrollment in allEnrollments {
                enrollmentCountByCourse[enrollment.courseId, default: 0] += 1
            }

            // Batch fetch teacher/creator names
            let creatorIds = Array(Set(courseDTOs.compactMap(\.createdBy)))
            var teacherNameMap: [UUID: String] = [:]
            if !creatorIds.isEmpty {
                let profiles: [ProfileDTO] = try await supabaseClient
                    .from("profiles")
                    .select()
                    .in("id", values: creatorIds.map(\.uuidString))
                    .execute()
                    .value
                for p in profiles {
                    teacherNameMap[p.id] = "\(p.firstName ?? "") \(p.lastName ?? "")"
                }
            }

            // Build catalog entries
            // NOTE: enrollmentStatus per-student is set to nil here;
            // call enrichCatalogWithStudentStatus(studentId:) after to overlay the student's status.
            catalogCourses = courseDTOs.map { dto in
                CourseCatalogEntry(
                    id: dto.id,
                    name: dto.name,
                    description: dto.description ?? "",
                    teacherName: dto.createdBy.flatMap { teacherNameMap[$0] } ?? "Unknown",
                    schedule: nil,
                    subject: dto.subject,
                    gradeLevel: dto.gradeLevel,
                    currentEnrollment: enrollmentCountByCourse[dto.id] ?? 0,
                    maxEnrollment: 30, // Default capacity per course
                    enrollmentStatus: nil
                )
            }
        } catch {
            self.error = "Failed to load course catalog: \(UserFacingError.message(from: error))"
        }
    }

    /// Overlays the student's enrollment status onto the catalog entries.
    func enrichCatalogWithStudentStatus(studentId: UUID) async {
        do {
            let enrollments: [EnrollmentDTO] = try await supabaseClient
                .from("course_enrollments")
                .select()
                .eq("student_id", value: studentId.uuidString)
                .execute()
                .value

            var statusByCourse: [UUID: EnrollmentStatus] = [:]
            for e in enrollments {
                let status: EnrollmentStatus
                switch e.status?.lowercased() {
                case "active", "enrolled": status = .enrolled
                case "pending": status = .pending
                case "waitlisted": status = .waitlisted
                case "dropped": status = .dropped
                case "denied": status = .denied
                default: status = .enrolled
                }
                statusByCourse[e.courseId] = status
            }

            catalogCourses = catalogCourses.map { entry in
                CourseCatalogEntry(
                    id: entry.id,
                    name: entry.name,
                    description: entry.description,
                    teacherName: entry.teacherName,
                    schedule: entry.schedule,
                    subject: entry.subject,
                    gradeLevel: entry.gradeLevel,
                    currentEnrollment: entry.currentEnrollment,
                    maxEnrollment: entry.maxEnrollment,
                    enrollmentStatus: statusByCourse[entry.id]
                )
            }
        } catch {
            #if DEBUG
            print("[EnrollmentService] Failed to enrich catalog with student status: \(error)")
            #endif
        }
    }

    // MARK: - Student: Request Enrollment

    func requestEnrollment(courseId: UUID, studentId: UUID) async -> Bool {
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            // Check for existing enrollment
            let existing: [EnrollmentDTO] = try await supabaseClient
                .from("course_enrollments")
                .select()
                .eq("student_id", value: studentId.uuidString)
                .eq("course_id", value: courseId.uuidString)
                .execute()
                .value

            if !existing.isEmpty {
                error = "You already have an enrollment record for this course."
                return false
            }

            // Insert enrollment with "pending" status for approval flow
            let dto = InsertEnrollmentDTO(
                tenantId: nil,
                courseId: courseId,
                studentId: studentId,
                teacherId: nil,
                status: "pending",
                enrolledAt: formatDate(Date())
            )
            try await supabaseClient
                .from("course_enrollments")
                .insert(dto)
                .execute()

            // Update the local catalog entry status
            if let index = catalogCourses.firstIndex(where: { $0.id == courseId }) {
                let entry = catalogCourses[index]
                catalogCourses[index] = CourseCatalogEntry(
                    id: entry.id,
                    name: entry.name,
                    description: entry.description,
                    teacherName: entry.teacherName,
                    schedule: entry.schedule,
                    subject: entry.subject,
                    gradeLevel: entry.gradeLevel,
                    currentEnrollment: entry.currentEnrollment,
                    maxEnrollment: entry.maxEnrollment,
                    enrollmentStatus: .pending
                )
            }

            return true
        } catch {
            self.error = "Failed to request enrollment: \(UserFacingError.message(from: error))"
            return false
        }
    }

    // MARK: - Student: Drop Course

    func dropCourse(enrollmentId: UUID, studentId: UUID) async -> Bool {
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            // Find the enrollment to get the course ID for local state update
            let enrollments: [EnrollmentDTO] = try await supabaseClient
                .from("course_enrollments")
                .select()
                .eq("student_id", value: studentId.uuidString)
                .execute()
                .value

            // Delete the enrollment row
            try await supabaseClient
                .from("course_enrollments")
                .delete()
                .eq("student_id", value: studentId.uuidString)
                .eq("id", value: enrollmentId.uuidString)
                .execute()

            // Find what course it belonged to and update local state
            if let dropped = enrollments.first(where: { $0.id == enrollmentId }) {
                if let index = catalogCourses.firstIndex(where: { $0.id == dropped.courseId }) {
                    let entry = catalogCourses[index]
                    catalogCourses[index] = CourseCatalogEntry(
                        id: entry.id,
                        name: entry.name,
                        description: entry.description,
                        teacherName: entry.teacherName,
                        schedule: entry.schedule,
                        subject: entry.subject,
                        gradeLevel: entry.gradeLevel,
                        currentEnrollment: max(0, entry.currentEnrollment - 1),
                        maxEnrollment: entry.maxEnrollment,
                        enrollmentStatus: nil
                    )
                }
            }

            // Remove from myEnrollments
            myEnrollments.removeAll { $0.id == enrollmentId }

            return true
        } catch {
            self.error = "Failed to drop course: \(UserFacingError.message(from: error))"
            return false
        }
    }

    // MARK: - Student: Join Waitlist

    func joinWaitlist(courseId: UUID, studentId: UUID) async -> Bool {
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            let existing: [EnrollmentDTO] = try await supabaseClient
                .from("course_enrollments")
                .select()
                .eq("student_id", value: studentId.uuidString)
                .eq("course_id", value: courseId.uuidString)
                .execute()
                .value

            if !existing.isEmpty {
                error = "You already have an enrollment record for this course."
                return false
            }

            let dto = InsertEnrollmentDTO(
                tenantId: nil,
                courseId: courseId,
                studentId: studentId,
                teacherId: nil,
                status: "waitlisted",
                enrolledAt: formatDate(Date())
            )
            try await supabaseClient
                .from("course_enrollments")
                .insert(dto)
                .execute()

            // Update local catalog
            if let index = catalogCourses.firstIndex(where: { $0.id == courseId }) {
                let entry = catalogCourses[index]
                catalogCourses[index] = CourseCatalogEntry(
                    id: entry.id,
                    name: entry.name,
                    description: entry.description,
                    teacherName: entry.teacherName,
                    schedule: entry.schedule,
                    subject: entry.subject,
                    gradeLevel: entry.gradeLevel,
                    currentEnrollment: entry.currentEnrollment,
                    maxEnrollment: entry.maxEnrollment,
                    enrollmentStatus: .waitlisted
                )
            }

            return true
        } catch {
            self.error = "Failed to join waitlist: \(UserFacingError.message(from: error))"
            return false
        }
    }

    // MARK: - Student: Fetch My Enrollments

    func fetchMyEnrollments(studentId: UUID) async {
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            let enrollments: [EnrollmentDTO] = try await supabaseClient
                .from("course_enrollments")
                .select()
                .eq("student_id", value: studentId.uuidString)
                .execute()
                .value

            if enrollments.isEmpty {
                myEnrollments = []
                return
            }

            // Fetch course names
            let courseIds = enrollments.map(\.courseId)
            let courseDTOs: [CourseDTO] = try await supabaseClient
                .from("courses")
                .select()
                .in("id", values: courseIds.map(\.uuidString))
                .execute()
                .value
            var courseNameMap: [UUID: String] = [:]
            for c in courseDTOs { courseNameMap[c.id] = c.name }

            // Fetch student name
            let profile: ProfileDTO = try await supabaseClient
                .from("profiles")
                .select()
                .eq("id", value: studentId.uuidString)
                .single()
                .execute()
                .value
            let studentName = "\(profile.firstName ?? "") \(profile.lastName ?? "")"

            myEnrollments = enrollments.compactMap { e in
                guard let id = e.id else { return nil }
                let status: EnrollmentStatus
                switch e.status?.lowercased() {
                case "active", "enrolled": status = .enrolled
                case "pending": status = .pending
                case "waitlisted": status = .waitlisted
                case "dropped": status = .dropped
                case "denied": status = .denied
                default: status = .enrolled
                }
                return EnrollmentRequest(
                    id: id,
                    studentId: studentId,
                    studentName: studentName,
                    courseId: e.courseId,
                    courseName: courseNameMap[e.courseId] ?? "Unknown",
                    requestDate: parseDate(e.enrolledAt),
                    status: status,
                    reviewedBy: nil,
                    reviewDate: nil,
                    note: nil
                )
            }
        } catch {
            self.error = "Failed to load enrollments: \(UserFacingError.message(from: error))"
        }
    }

    // MARK: - Teacher: Fetch Pending Requests

    func fetchPendingRequests(teacherId: UUID) async {
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            // Find courses created by this teacher
            let courseDTOs: [CourseDTO] = try await supabaseClient
                .from("courses")
                .select()
                .eq("created_by", value: teacherId.uuidString)
                .execute()
                .value

            if courseDTOs.isEmpty {
                pendingRequests = []
                return
            }

            let courseIds = courseDTOs.map(\.id)
            var courseNameMap: [UUID: String] = [:]
            for c in courseDTOs { courseNameMap[c.id] = c.name }

            // Fetch pending enrollments for these courses
            let enrollments: [EnrollmentDTO] = try await supabaseClient
                .from("course_enrollments")
                .select()
                .in("course_id", values: courseIds.map(\.uuidString))
                .eq("status", value: "pending")
                .execute()
                .value

            if enrollments.isEmpty {
                pendingRequests = []
                return
            }

            // Resolve student names
            let studentIds = Array(Set(enrollments.map(\.studentId)))
            var studentNameMap: [UUID: String] = [:]
            if !studentIds.isEmpty {
                let profiles: [ProfileDTO] = try await supabaseClient
                    .from("profiles")
                    .select()
                    .in("id", values: studentIds.map(\.uuidString))
                    .execute()
                    .value
                for p in profiles {
                    studentNameMap[p.id] = "\(p.firstName ?? "") \(p.lastName ?? "")"
                }
            }

            pendingRequests = enrollments.compactMap { e in
                guard let id = e.id else { return nil }
                return EnrollmentRequest(
                    id: id,
                    studentId: e.studentId,
                    studentName: studentNameMap[e.studentId] ?? "Unknown Student",
                    courseId: e.courseId,
                    courseName: courseNameMap[e.courseId] ?? "Unknown Course",
                    requestDate: parseDate(e.enrolledAt),
                    status: .pending,
                    reviewedBy: nil,
                    reviewDate: nil,
                    note: nil
                )
            }
        } catch {
            self.error = "Failed to load pending requests: \(UserFacingError.message(from: error))"
        }
    }

    // MARK: - Teacher: Approve Enrollment

    func approveEnrollment(requestId: UUID, reviewerId: UUID) async -> Bool {
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            // Update the enrollment status to "active"
            try await supabaseClient
                .from("course_enrollments")
                .update(["status": "active"])
                .eq("id", value: requestId.uuidString)
                .execute()

            // Remove from local pending list
            pendingRequests.removeAll { $0.id == requestId }
            return true
        } catch {
            self.error = "Failed to approve enrollment: \(UserFacingError.message(from: error))"
            return false
        }
    }

    // MARK: - Teacher: Deny Enrollment

    func denyEnrollment(requestId: UUID, reviewerId: UUID, reason: String?) async -> Bool {
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            // Update the enrollment status to "denied"
            try await supabaseClient
                .from("course_enrollments")
                .update(["status": "denied"])
                .eq("id", value: requestId.uuidString)
                .execute()

            // Remove from local pending list
            pendingRequests.removeAll { $0.id == requestId }
            return true
        } catch {
            self.error = "Failed to deny enrollment: \(UserFacingError.message(from: error))"
            return false
        }
    }

    // MARK: - Search / Filter (Client-side)

    func searchCatalog(query: String) -> [CourseCatalogEntry] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return catalogCourses }
        return catalogCourses.filter {
            $0.name.localizedStandardContains(trimmed) ||
            $0.teacherName.localizedStandardContains(trimmed) ||
            $0.description.localizedStandardContains(trimmed) ||
            ($0.subject?.localizedStandardContains(trimmed) ?? false)
        }
    }

    func filterBySubject(_ subject: String) -> [CourseCatalogEntry] {
        guard !subject.isEmpty else { return catalogCourses }
        return catalogCourses.filter {
            $0.subject?.localizedStandardContains(subject) ?? false
        }
    }
}
