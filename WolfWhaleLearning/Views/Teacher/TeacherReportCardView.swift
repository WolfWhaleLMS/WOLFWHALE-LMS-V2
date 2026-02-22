import SwiftUI

struct TeacherReportCardView: View {
    let viewModel: AppViewModel
    @State private var selectedTermId: UUID?
    @State private var selectedCourseId: UUID?
    @State private var comments: [UUID: String] = [:]  // studentId -> comment text
    @State private var showTemplates = false
    @State private var templateTargetStudentId: UUID?
    @State private var savedCount = 0
    @State private var showSavedConfirmation = false
    @State private var hapticTrigger = false

    private let commentCharLimit = 500

    private var config: AcademicCalendarConfig {
        viewModel.academicCalendarConfig
    }

    private var teacherCourses: [Course] {
        viewModel.courses.filter { $0.teacherName == viewModel.currentUser?.fullName }
    }

    /// Students for the selected course, derived from grades
    private var studentsForCourse: [(id: UUID, name: String, grade: GradeEntry?)] {
        guard let courseId = selectedCourseId else { return [] }

        // Get students from grades for this course
        let courseGrades = viewModel.grades.filter { $0.courseId == courseId }

        if courseGrades.isEmpty {
            // Fallback: use allUsers who are students
            let students = viewModel.allUsers.filter { $0.role.lowercased() == "student" }
            if students.isEmpty, let current = viewModel.currentUser {
                // Demo fallback: show current user
                return [(id: current.id, name: current.fullName, grade: nil)]
            }
            return students.map { profile in
                let name = profile.fullName ?? "\(profile.firstName ?? "") \(profile.lastName ?? "")"
                return (id: profile.id, name: name, grade: nil)
            }
        }

        // Use a set to deduplicate by courseId (each grade entry represents one student's grade in the course)
        return courseGrades.map { grade in
            (id: grade.id, name: grade.courseName, grade: grade)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 16) {
                    termSelectionSection
                    if selectedTermId != nil {
                        courseSelectionSection
                    }
                    if selectedTermId != nil && selectedCourseId != nil {
                        studentCommentsSection
                        saveButton
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Report Card Comments")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showTemplates) {
                CommentTemplatesSheet(
                    onSelect: { template in
                        if let studentId = templateTargetStudentId {
                            let existing = comments[studentId] ?? ""
                            let newText = existing.isEmpty ? template : "\(existing) \(template)"
                            comments[studentId] = String(newText.prefix(commentCharLimit))
                        }
                        showTemplates = false
                    }
                )
            }
            .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
            .sensoryFeedback(.success, trigger: showSavedConfirmation)
            .task {
                await viewModel.loadAcademicCalendar()
            }
        }
    }

    // MARK: - Term Selection

    private var termSelectionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Select Term", systemImage: "calendar.badge.clock")
                .font(.headline)

            if config.terms.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                    Text("No terms configured. Ask an administrator to set up the academic calendar.")
                        .font(.subheadline)
                        .foregroundStyle(Color(.secondaryLabel))
                }
                .padding(14)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(config.terms) { term in
                            Button {
                                hapticTrigger.toggle()
                                withAnimation {
                                    selectedTermId = term.id
                                    selectedCourseId = nil
                                    comments = [:]
                                }
                            } label: {
                                VStack(spacing: 4) {
                                    Text(term.name)
                                        .font(.subheadline.bold())
                                        .foregroundStyle(selectedTermId == term.id ? .white : Color(.label))
                                    Text(term.type.rawValue)
                                        .font(.caption2)
                                        .foregroundStyle(selectedTermId == term.id ? .white.opacity(0.8) : Color(.secondaryLabel))
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(selectedTermId == term.id ? Color.indigo : Color(.secondarySystemGroupedBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .strokeBorder(selectedTermId == term.id ? Color.clear : Color(.systemGray4), lineWidth: 0.5)
                                )
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(term.name), \(term.type.rawValue)")
                            .accessibilityAddTraits(selectedTermId == term.id ? .isSelected : [])
                        }
                    }
                    .padding(.horizontal, 2)
                }
            }
        }
    }

    // MARK: - Course Selection

    private var courseSelectionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Select Course", systemImage: "book.fill")
                .font(.headline)

            if teacherCourses.isEmpty && viewModel.courses.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "info.circle")
                        .foregroundStyle(.blue)
                    Text("No courses found.")
                        .font(.subheadline)
                        .foregroundStyle(Color(.secondaryLabel))
                }
                .padding(14)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                let coursesToShow = teacherCourses.isEmpty ? viewModel.courses : teacherCourses
                ForEach(coursesToShow) { course in
                    Button {
                        hapticTrigger.toggle()
                        withAnimation {
                            selectedCourseId = course.id
                            loadExistingComments(courseId: course.id)
                        }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: selectedCourseId == course.id ? "checkmark.circle.fill" : "circle")
                                .font(.title3)
                                .foregroundStyle(selectedCourseId == course.id ? Theme.courseColor(course.colorName) : Color(.tertiaryLabel))

                            Image(systemName: course.iconSystemName)
                                .font(.title3)
                                .foregroundStyle(Theme.courseColor(course.colorName))
                                .frame(width: 28)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(course.title)
                                    .font(.subheadline.bold())
                                    .foregroundStyle(Color(.label))
                                Text("\(course.enrolledStudentCount) students")
                                    .font(.caption)
                                    .foregroundStyle(Color(.secondaryLabel))
                            }

                            Spacer()
                        }
                        .padding(12)
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(selectedCourseId == course.id ? Theme.courseColor(course.colorName).opacity(0.4) : Color.clear, lineWidth: 1.5)
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(course.title), \(course.enrolledStudentCount) students")
                    .accessibilityAddTraits(selectedCourseId == course.id ? .isSelected : [])
                }
            }
        }
    }

    // MARK: - Student Comments

    private var studentCommentsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Student Comments", systemImage: "text.bubble.fill")
                    .font(.headline)
                Spacer()
                if showSavedConfirmation {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("Saved \(savedCount)")
                            .font(.caption.bold())
                            .foregroundStyle(.green)
                    }
                    .transition(.opacity)
                }
            }

            Text("Add comments for each student's report card. Max \(commentCharLimit) characters per comment.")
                .font(.caption)
                .foregroundStyle(Color(.secondaryLabel))

            // In demo mode, show a sample student entry
            let students = demoStudentList
            if students.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "person.3")
                        .foregroundStyle(Color(.secondaryLabel))
                    Text("No students found for this course")
                        .font(.subheadline)
                        .foregroundStyle(Color(.secondaryLabel))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                ForEach(students, id: \.id) { student in
                    studentCommentCard(studentId: student.id, studentName: student.name, grade: student.grade)
                }
            }
        }
    }

    private func studentCommentCard(studentId: UUID, studentName: String, grade: Double?) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "person.crop.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.indigo)

                VStack(alignment: .leading, spacing: 2) {
                    Text(studentName)
                        .font(.subheadline.bold())
                        .foregroundStyle(Color(.label))
                    if let g = grade {
                        Text("Grade: \(String(format: "%.1f%%", g))")
                            .font(.caption)
                            .foregroundStyle(Theme.gradeColor(g))
                    }
                }

                Spacer()

                Button {
                    hapticTrigger.toggle()
                    templateTargetStudentId = studentId
                    showTemplates = true
                } label: {
                    Label("Templates", systemImage: "doc.on.clipboard")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.indigo.opacity(0.12))
                        .clipShape(Capsule())
                        .foregroundStyle(.indigo)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Insert comment template for \(studentName)")
            }

            let binding = Binding<String>(
                get: { comments[studentId] ?? "" },
                set: { newValue in
                    comments[studentId] = String(newValue.prefix(commentCharLimit))
                }
            )

            TextField("Add comment for report card...", text: binding, axis: .vertical)
                .font(.subheadline)
                .lineLimit(3...6)
                .textFieldStyle(.plain)
                .padding(10)
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(Color(.systemGray4), lineWidth: 0.5)
                )
                .accessibilityLabel("Comment for \(studentName)")

            HStack {
                let charCount = comments[studentId]?.count ?? 0
                Text("\(charCount)/\(commentCharLimit)")
                    .font(.caption2)
                    .foregroundStyle(charCount > commentCharLimit - 50 ? .orange : Color(.tertiaryLabel))
                Spacer()
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Save Button

    private var saveButton: some View {
        Button {
            hapticTrigger.toggle()
            saveComments()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                Text("Save All Comments")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
        }
        .buttonStyle(.borderedProminent)
        .tint(.indigo)
        .disabled(comments.values.allSatisfy { $0.trimmingCharacters(in: .whitespaces).isEmpty })
        .accessibilityLabel("Save all report card comments")
    }

    // MARK: - Helpers

    private struct DemoStudent: Identifiable {
        let id: UUID
        let name: String
        let grade: Double?
    }

    private var demoStudentList: [DemoStudent] {
        guard let courseId = selectedCourseId else { return [] }

        // Try to get students from grades
        let courseGrades = viewModel.grades.filter { $0.courseId == courseId }
        if !courseGrades.isEmpty {
            return courseGrades.map { grade in
                DemoStudent(id: grade.id, name: grade.courseName, grade: grade.numericGrade)
            }
        }

        // Fallback: use allUsers who are students
        let students = viewModel.allUsers.filter { $0.role.lowercased() == "student" }
        if !students.isEmpty {
            return students.map { profile in
                let name = profile.fullName ?? "\(profile.firstName ?? "") \(profile.lastName ?? "")"
                return DemoStudent(id: profile.id, name: name, grade: nil)
            }
        }

        // Demo fallback: generate sample students
        return [
            DemoStudent(id: UUID(), name: "Alex Rivera", grade: 92.5),
            DemoStudent(id: UUID(), name: "Jordan Chen", grade: 87.3),
            DemoStudent(id: UUID(), name: "Sam Patel", grade: 78.1),
            DemoStudent(id: UUID(), name: "Taylor Kim", grade: 95.0),
            DemoStudent(id: UUID(), name: "Casey Nguyen", grade: 84.7),
        ]
    }

    private func loadExistingComments(courseId: UUID) {
        guard let termId = selectedTermId else { return }
        comments = [:]
        for student in demoStudentList {
            if let existing = viewModel.reportCardComment(studentId: student.id, courseId: courseId, termId: termId) {
                comments[student.id] = existing.comment
            }
        }
    }

    private func saveComments() {
        guard let termId = selectedTermId,
              let courseId = selectedCourseId,
              let teacherId = viewModel.currentUser?.id else { return }

        var count = 0
        for (studentId, comment) in comments {
            let trimmed = comment.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            let reportComment = ReportCardComment(
                studentId: studentId,
                courseId: courseId,
                termId: termId,
                teacherId: teacherId,
                comment: trimmed
            )
            viewModel.addReportCardComment(reportComment)
            count += 1
        }
        savedCount = count
        withAnimation {
            showSavedConfirmation = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                showSavedConfirmation = false
            }
        }
    }
}

// MARK: - Comment Templates Sheet

struct CommentTemplatesSheet: View {
    let onSelect: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var selectedCategory: CommentCategory? = nil
    @State private var hapticTrigger = false

    private var filteredTemplates: [CommentTemplate] {
        if let category = selectedCategory {
            return AppViewModel.commentTemplates.filter { $0.category == category }
        }
        return AppViewModel.commentTemplates
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            categoryChip(nil, label: "All")
                            ForEach(CommentCategory.allCases) { category in
                                categoryChip(category, label: category.rawValue)
                            }
                        }
                        .padding(.horizontal, 2)
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                }

                Section("Select a Template") {
                    ForEach(filteredTemplates) { template in
                        Button {
                            hapticTrigger.toggle()
                            onSelect(template.text)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: template.category.iconName)
                                    .font(.subheadline)
                                    .foregroundStyle(templateCategoryColor(template.category))
                                    .frame(width: 24)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(template.text)
                                        .font(.subheadline)
                                        .foregroundStyle(Color(.label))
                                        .multilineTextAlignment(.leading)
                                    Text(template.category.rawValue)
                                        .font(.caption2)
                                        .foregroundStyle(Color(.secondaryLabel))
                                }
                            }
                        }
                        .accessibilityLabel("\(template.category.rawValue): \(template.text)")
                        .accessibilityHint("Double tap to insert this template")
                    }
                }
            }
            .navigationTitle("Comment Templates")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sensoryFeedback(.selection, trigger: hapticTrigger)
        }
    }

    private func categoryChip(_ category: CommentCategory?, label: String) -> some View {
        Button {
            hapticTrigger.toggle()
            withAnimation { selectedCategory = category }
        } label: {
            Text(label)
                .font(.caption.bold())
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(selectedCategory == category ? Color.indigo : Color(.secondarySystemGroupedBackground))
                .foregroundStyle(selectedCategory == category ? .white : Color(.label))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(label) category")
        .accessibilityAddTraits(selectedCategory == category ? .isSelected : [])
    }

    private func templateCategoryColor(_ category: CommentCategory) -> Color {
        switch category {
        case .positive: .green
        case .improvement: .orange
        case .general: .blue
        }
    }
}
