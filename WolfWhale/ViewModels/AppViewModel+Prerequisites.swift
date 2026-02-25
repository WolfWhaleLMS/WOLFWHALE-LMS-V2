import Foundation

// MARK: - Prerequisites & Section Management

extension AppViewModel {

    // MARK: - Prerequisite Checking

    /// Returns `true` if the current student has completed all prerequisites for the given course.
    /// A course is considered completed when its `progress` is >= 1.0 (100%).
    /// If the course has no prerequisites, this returns `true`.
    func hasCompletedPrerequisites(for courseId: UUID) -> Bool {
        // Find the target course in all known courses
        let targetCourse = courses.first(where: { $0.id == courseId })
            ?? allAvailableCourses.first(where: { $0.id == courseId })

        guard let target = targetCourse else { return true }

        // No prerequisites means always eligible
        if target.prerequisiteIds.isEmpty { return true }

        // Check that every prerequisite course exists in the student's enrolled courses
        // and has been completed (progress >= 1.0)
        for prereqId in target.prerequisiteIds {
            guard let enrolled = courses.first(where: { $0.id == prereqId }),
                  enrolled.progress >= 1.0 else {
                return false
            }
        }
        return true
    }

    /// Returns the names of prerequisite courses that the student has NOT yet completed.
    func missingPrerequisites(for courseId: UUID) -> [String] {
        let targetCourse = courses.first(where: { $0.id == courseId })
            ?? allAvailableCourses.first(where: { $0.id == courseId })

        guard let target = targetCourse else { return [] }
        if target.prerequisiteIds.isEmpty { return [] }

        var missing: [String] = []
        for prereqId in target.prerequisiteIds {
            let enrolled = courses.first(where: { $0.id == prereqId })
            if enrolled == nil || (enrolled?.progress ?? 0) < 1.0 {
                // Try to find the course name from any known source
                let name = courses.first(where: { $0.id == prereqId })?.title
                    ?? allAvailableCourses.first(where: { $0.id == prereqId })?.title
                    ?? "Unknown Course"
                missing.append(name)
            }
        }
        return missing
    }

    // MARK: - Section Management

    /// Returns all sections (courses sharing the same base title pattern) for a given course.
    /// Sections are identified by having the same title prefix and a non-nil sectionNumber.
    func sectionsForCourse(_ course: Course) -> [Course] {
        let baseName = sectionBaseName(for: course)
        return allAvailableCourses.filter { sectionBaseName(for: $0) == baseName && $0.sectionNumber != nil }
            + courses.filter { sectionBaseName(for: $0) == baseName && $0.sectionNumber != nil }
    }

    /// Extracts the base course name by stripping section-related suffixes.
    private func sectionBaseName(for course: Course) -> String {
        // If no section, use the full title
        guard course.sectionNumber != nil else { return course.title }
        // Strip trailing " - Section X", " (Period X)", etc.
        var name = course.title
        if let range = name.range(of: " - Section \\d+", options: .regularExpression) {
            name = String(name[name.startIndex..<range.lowerBound])
        }
        if let range = name.range(of: " \\(Period \\d+\\)", options: .regularExpression) {
            name = String(name[name.startIndex..<range.lowerBound])
        }
        return name
    }

    /// Creates a new section by cloning a course with a new section number and label.
    /// Used by admins to create multiple sections of the same course.
    func createSection(
        from sourceCourse: Course,
        sectionNumber: Int,
        sectionLabel: String,
        maxCapacity: Int,
        teacherName: String? = nil
    ) {
        let newCourse = Course(
            id: UUID(),
            title: sourceCourse.title,
            description: sourceCourse.description,
            teacherName: teacherName ?? sourceCourse.teacherName,
            iconSystemName: sourceCourse.iconSystemName,
            colorName: sourceCourse.colorName,
            modules: sourceCourse.modules,
            enrolledStudentCount: 0,
            progress: 0,
            classCode: "\(sourceCourse.classCode.prefix(4))-S\(sectionNumber)-\(Int.random(in: 1000...9999))",
            prerequisiteIds: sourceCourse.prerequisiteIds,
            prerequisitesDescription: sourceCourse.prerequisitesDescription,
            sectionNumber: sectionNumber,
            sectionLabel: sectionLabel,
            maxCapacity: maxCapacity
        )

        if isDemoMode {
            allAvailableCourses.append(newCourse)
        } else {
            // In production, would call Supabase to create the course
            // For now, add locally and the next sync will persist
            allAvailableCourses.append(newCourse)
        }
    }

    /// Simulates transferring a student between two sections (demo mode friendly).
    func transferStudent(studentName: String, fromSection: UUID, toSection: UUID) {
        // Decrement source section enrollment
        if let idx = allAvailableCourses.firstIndex(where: { $0.id == fromSection }) {
            allAvailableCourses[idx].enrolledStudentCount = max(0, allAvailableCourses[idx].enrolledStudentCount - 1)
        } else if let idx = courses.firstIndex(where: { $0.id == fromSection }) {
            courses[idx].enrolledStudentCount = max(0, courses[idx].enrolledStudentCount - 1)
        }

        // Increment destination section enrollment
        if let idx = allAvailableCourses.firstIndex(where: { $0.id == toSection }) {
            allAvailableCourses[idx].enrolledStudentCount += 1
        } else if let idx = courses.firstIndex(where: { $0.id == toSection }) {
            courses[idx].enrolledStudentCount += 1
        }
    }
}
