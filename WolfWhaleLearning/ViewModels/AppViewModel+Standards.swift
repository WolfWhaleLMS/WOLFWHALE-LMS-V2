import Foundation
import Supabase

// MARK: - Private Storage for Teacher Notes & Standards

/// Instance-level storage for teacher notes and learning standards.
/// Uses ObjectIdentifier-keyed dictionaries so each AppViewModel instance
/// gets its own independent data, while keeping stored properties out of
/// the main AppViewModel.swift file.
@MainActor
private enum NotesStorage {
    static var teacherNotes: [ObjectIdentifier: [TeacherNote]] = [:]
    static var learningStandards: [ObjectIdentifier: [LearningStandard]] = [:]
}

// MARK: - Teacher Notes & Learning Standards

extension AppViewModel {

    // MARK: - Storage Accessors

    /// All teacher notes across courses for this view model instance.
    internal var storedTeacherNotes: [TeacherNote] {
        get { NotesStorage.teacherNotes[ObjectIdentifier(self)] ?? [] }
        set { NotesStorage.teacherNotes[ObjectIdentifier(self)] = newValue }
    }

    /// All available learning standards. Pre-populated with Common Core mock data.
    internal var storedLearningStandards: [LearningStandard] {
        get {
            let key = ObjectIdentifier(self)
            if NotesStorage.learningStandards[key]?.isEmpty ?? true {
                NotesStorage.learningStandards[key] = MockStandards.allStandards
            }
            return NotesStorage.learningStandards[key] ?? MockStandards.allStandards
        }
        set { NotesStorage.learningStandards[ObjectIdentifier(self)] = newValue }
    }

    // MARK: - Teacher Notes Methods

    /// Load notes for a specific student in a course.
    func loadTeacherNotes(studentId: UUID, courseId: UUID) {
        if isDemoMode {
            ensureDemoNotes(studentId: studentId, courseId: courseId)
            return
        }

        Task {
            do {
                struct NoteDTO: Decodable {
                    let id: UUID
                    let teacherId: UUID
                    let studentId: UUID
                    let courseId: UUID
                    let content: String
                    let category: String
                    let isPrivate: Bool
                    let createdAt: String
                    let updatedAt: String?

                    enum CodingKeys: String, CodingKey {
                        case id
                        case teacherId = "teacher_id"
                        case studentId = "student_id"
                        case courseId = "course_id"
                        case content, category
                        case isPrivate = "is_private"
                        case createdAt = "created_at"
                        case updatedAt = "updated_at"
                    }
                }

                let dtos: [NoteDTO] = try await supabaseClient
                    .from("teacher_notes")
                    .select()
                    .eq("student_id", value: studentId.uuidString)
                    .eq("course_id", value: courseId.uuidString)
                    .order("created_at", ascending: false)
                    .execute()
                    .value

                let formatter = ISO8601DateFormatter()
                let notes = dtos.map { dto in
                    TeacherNote(
                        id: dto.id,
                        teacherId: dto.teacherId,
                        studentId: dto.studentId,
                        courseId: dto.courseId,
                        content: dto.content,
                        category: NoteCategory(rawValue: dto.category) ?? .general,
                        isPrivate: dto.isPrivate,
                        createdDate: formatter.date(from: dto.createdAt) ?? Date(),
                        updatedDate: dto.updatedAt.flatMap { formatter.date(from: $0) }
                    )
                }

                storedTeacherNotes.removeAll { $0.studentId == studentId && $0.courseId == courseId }
                storedTeacherNotes.append(contentsOf: notes)
            } catch {
                #if DEBUG
                print("[AppViewModel] loadTeacherNotes failed: \(error)")
                #endif
            }
        }
    }

    /// Add a new note for a student.
    func addTeacherNote(studentId: UUID, courseId: UUID, content: String, category: NoteCategory, isPrivate: Bool = true) {
        guard let user = currentUser else { return }

        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            dataError = "Note content cannot be empty."
            return
        }

        let newNote = TeacherNote(
            teacherId: user.id,
            studentId: studentId,
            courseId: courseId,
            content: trimmed,
            category: category,
            isPrivate: isPrivate
        )
        storedTeacherNotes.insert(newNote, at: 0)

        if !isDemoMode {
            Task {
                do {
                    try await supabaseClient
                        .from("teacher_notes")
                        .insert([
                            "id": newNote.id.uuidString,
                            "teacher_id": user.id.uuidString,
                            "student_id": studentId.uuidString,
                            "course_id": courseId.uuidString,
                            "content": trimmed,
                            "category": category.rawValue,
                            "is_private": isPrivate ? "true" : "false"
                        ])
                        .execute()
                } catch {
                    storedTeacherNotes.removeAll { $0.id == newNote.id }
                    dataError = "Failed to save note. Please try again."
                    #if DEBUG
                    print("[AppViewModel] addTeacherNote failed: \(error)")
                    #endif
                }
            }
        }
    }

    /// Update an existing note.
    func updateTeacherNote(noteId: UUID, content: String, category: NoteCategory, isPrivate: Bool) {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            dataError = "Note content cannot be empty."
            return
        }

        guard let idx = storedTeacherNotes.firstIndex(where: { $0.id == noteId }) else { return }
        let oldNote = storedTeacherNotes[idx]
        storedTeacherNotes[idx].content = trimmed
        storedTeacherNotes[idx].category = category
        storedTeacherNotes[idx].isPrivate = isPrivate
        storedTeacherNotes[idx].updatedDate = Date()

        if !isDemoMode {
            Task {
                do {
                    try await supabaseClient
                        .from("teacher_notes")
                        .update([
                            "content": trimmed,
                            "category": category.rawValue,
                            "is_private": isPrivate ? "true" : "false",
                            "updated_at": ISO8601DateFormatter().string(from: Date())
                        ])
                        .eq("id", value: noteId.uuidString)
                        .execute()
                } catch {
                    if let idx = storedTeacherNotes.firstIndex(where: { $0.id == noteId }) {
                        storedTeacherNotes[idx] = oldNote
                    }
                    dataError = "Failed to update note."
                    #if DEBUG
                    print("[AppViewModel] updateTeacherNote failed: \(error)")
                    #endif
                }
            }
        }
    }

    /// Delete a note.
    func deleteTeacherNote(noteId: UUID) {
        guard let idx = storedTeacherNotes.firstIndex(where: { $0.id == noteId }) else { return }
        let removed = storedTeacherNotes.remove(at: idx)

        if !isDemoMode {
            Task {
                do {
                    try await supabaseClient
                        .from("teacher_notes")
                        .delete()
                        .eq("id", value: noteId.uuidString)
                        .execute()
                } catch {
                    storedTeacherNotes.insert(removed, at: min(idx, storedTeacherNotes.count))
                    dataError = "Failed to delete note."
                    #if DEBUG
                    print("[AppViewModel] deleteTeacherNote failed: \(error)")
                    #endif
                }
            }
        }
    }

    /// Notes for a specific student in a specific course, sorted newest first.
    func notes(forStudent studentId: UUID, inCourse courseId: UUID) -> [TeacherNote] {
        storedTeacherNotes.filter { $0.studentId == studentId && $0.courseId == courseId }
            .sorted { $0.createdDate > $1.createdDate }
    }

    /// Total note count for a student in a course.
    func noteCount(forStudent studentId: UUID, inCourse courseId: UUID) -> Int {
        storedTeacherNotes.filter { $0.studentId == studentId && $0.courseId == courseId }.count
    }

    // MARK: - Standards Mastery

    /// Computes the average grade for a specific standard across all tagged assignments in a course.
    func standardMastery(standardId: UUID, courseId: UUID) -> Double? {
        let taggedAssignments = assignments.filter {
            $0.courseId == courseId && $0.standardIds.contains(standardId) && $0.grade != nil
        }
        guard !taggedAssignments.isEmpty else { return nil }
        let total = taggedAssignments.compactMap(\.grade).reduce(0, +)
        return total / Double(taggedAssignments.count)
    }

    /// Computes per-student mastery for a specific standard in a course.
    func studentStandardMastery(standardId: UUID, courseId: UUID) -> [(studentName: String, studentId: UUID?, average: Double)] {
        let taggedAssignments = assignments.filter {
            $0.courseId == courseId && $0.standardIds.contains(standardId) && $0.grade != nil
        }

        var grouped: [String: (studentId: UUID?, grades: [Double])] = [:]
        for a in taggedAssignments {
            let name = a.studentName ?? "Unknown"
            if grouped[name] == nil {
                grouped[name] = (studentId: a.studentId, grades: [])
            }
            if let grade = a.grade {
                grouped[name]?.grades.append(grade)
            }
        }

        return grouped.map { entry in
            let avg = entry.value.grades.isEmpty ? 0 : entry.value.grades.reduce(0, +) / Double(entry.value.grades.count)
            return (studentName: entry.key, studentId: entry.value.studentId, average: avg)
        }
        .sorted { $0.studentName.localizedStandardCompare($1.studentName) == .orderedAscending }
    }

    /// All standards referenced by assignments in a given course.
    func standardsUsedInCourse(_ courseId: UUID) -> [LearningStandard] {
        let usedIds = Set(assignments.filter { $0.courseId == courseId }.flatMap(\.standardIds))
        return storedLearningStandards.filter { usedIds.contains($0.id) }
    }

    /// Standards for a specific assignment by its standardIds.
    func standards(forAssignment assignment: Assignment) -> [LearningStandard] {
        storedLearningStandards.filter { assignment.standardIds.contains($0.id) }
    }

    /// Tag standards to an assignment (updates local state; in production would also persist).
    func updateAssignmentStandards(assignmentId: UUID, standardIds: [UUID]) {
        if let idx = assignments.firstIndex(where: { $0.id == assignmentId }) {
            assignments[idx].standardIds = standardIds
        }
    }

    // MARK: - Demo Data Helpers

    private func ensureDemoNotes(studentId: UUID, courseId: UUID) {
        guard !storedTeacherNotes.contains(where: { $0.studentId == studentId && $0.courseId == courseId }) else { return }
        guard let user = currentUser else { return }

        let sampleNotes: [TeacherNote] = [
            TeacherNote(
                teacherId: user.id, studentId: studentId, courseId: courseId,
                content: "Showed great improvement on the last quiz. Consider recommending for advanced track.",
                category: .academic, isPrivate: true,
                createdDate: Date().addingTimeInterval(-86400 * 5)
            ),
            TeacherNote(
                teacherId: user.id, studentId: studentId, courseId: courseId,
                content: "Was disruptive during group work on Monday. Spoke with student after class.",
                category: .behavioral, isPrivate: true,
                createdDate: Date().addingTimeInterval(-86400 * 3)
            ),
            TeacherNote(
                teacherId: user.id, studentId: studentId, courseId: courseId,
                content: "Absent twice this week. Parent notified via email.",
                category: .attendance, isPrivate: true,
                createdDate: Date().addingTimeInterval(-86400)
            ),
        ]
        storedTeacherNotes.append(contentsOf: sampleNotes)
    }
}
