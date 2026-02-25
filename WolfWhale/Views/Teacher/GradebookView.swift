import SwiftUI

struct GradebookView: View {
    let course: Course
    @Bindable var viewModel: AppViewModel
    @State private var showAddAssignment = false
    @State private var showCreateModule = false
    @State private var showCreateQuiz = false
    @State private var selectedModuleForLesson: Module?
    @State private var newTitle = ""
    @State private var newInstructions = ""
    @State private var newDueDate = Date().addingTimeInterval(7 * 86400)
    @State private var newPoints: Int = 100
    @State private var isCreating = false
    @State private var createError: String?
    @State private var showEditCourse = false
    @State private var hapticTrigger = false

    // Student Notes
    @State private var selectedStudentForNotes: (id: UUID, name: String)?
    @State private var showStudentNotes = false

    // Standards
    @State private var newStandardIds: [UUID] = []
    @State private var showStandardsPicker = false

    // Late Policy state
    @State private var newLatePenaltyType: LatePenaltyType = .none
    @State private var newLatePenaltyPerDay: Double = 10
    @State private var newMaxLateDays: Int = 7

    // Resubmission state
    @State private var newAllowResubmission = false
    @State private var newMaxResubmissions: Int = 1
    @State private var newResubmissionDeadline: Date = Date().addingTimeInterval(14 * 86400)
    @State private var newHasResubmissionDeadline = false

    private var courseAssignments: [Assignment] {
        viewModel.assignments.filter { $0.courseName == course.title || $0.courseId == course.id }
    }

    private var submittedCount: Int {
        courseAssignments.filter(\.isSubmitted).count
    }

    private var pendingCount: Int {
        courseAssignments.filter { $0.isSubmitted && $0.grade == nil }.count
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                courseHeader
                statsSection
                studentSubmissionsSection
                standardsMasteryLink
                contentActionsSection
                teacherDiscussionLink
                templatesAndPeerReviewSection
                courseContentSection
                enrolledStudentsSection
                assignmentsSection
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
        .navigationTitle(course.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Edit", systemImage: "pencil") {
                    hapticTrigger.toggle()
                    showEditCourse = true
                }
                .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Add", systemImage: "plus") {
                    hapticTrigger.toggle()
                    showAddAssignment = true
                }
                .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
            }
        }
        .sheet(isPresented: $showAddAssignment) {
            addAssignmentSheet
        }
        .sheet(isPresented: $showCreateModule) {
            NavigationStack {
                CreateModuleView(viewModel: viewModel, course: course)
            }
        }
        .sheet(isPresented: $showCreateQuiz) {
            NavigationStack {
                CreateQuizView(viewModel: viewModel, course: course)
            }
        }
        .sheet(item: $selectedModuleForLesson) { module in
            NavigationStack {
                CreateLessonView(viewModel: viewModel, course: course, module: module)
            }
        }
        .sheet(isPresented: $showEditCourse) {
            NavigationStack {
                EditCourseView(course: course, viewModel: viewModel)
            }
        }
        .sheet(isPresented: $showStudentNotes) {
            if let student = selectedStudentForNotes {
                NavigationStack {
                    StudentNotesView(
                        viewModel: viewModel,
                        studentId: student.id,
                        studentName: student.name,
                        courseId: course.id,
                        courseName: course.title
                    )
                }
            }
        }
        .sheet(isPresented: $showStandardsPicker) {
            StandardsPickerView(viewModel: viewModel, selectedStandardIds: $newStandardIds)
        }
    }

    private var courseHeader: some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 16)
                .fill(Theme.courseColor(course.colorName).gradient)
                .frame(width: 56, height: 56)
                .overlay {
                    Image(systemName: course.iconSystemName)
                        .font(.title2)
                        .foregroundStyle(.white)
                }
            VStack(alignment: .leading, spacing: 4) {
                Text(course.title)
                    .font(.headline)
                HStack(spacing: 8) {
                    Label("Code: \(course.classCode)", systemImage: "number")
                    Label("\(course.enrolledStudentCount) students", systemImage: "person.3.fill")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(14)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

    private var statsSection: some View {
        HStack(spacing: 12) {
            statCard(label: "Assignments", value: "\(courseAssignments.count)", color: .blue)
            statCard(label: "Submitted", value: "\(submittedCount)", color: .green)
            statCard(label: "Pending", value: "\(pendingCount)", color: .orange)
        }
    }

    private func statCard(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.headline)
                .foregroundStyle(color)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 12))
    }

    // MARK: - Student Submissions

    private var studentSubmissionsSection: some View {
        NavigationLink {
            StudentSubmissionsView(viewModel: viewModel, course: course)
        } label: {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 10)
                    .fill(.orange.gradient)
                    .frame(width: 40, height: 40)
                    .overlay {
                        Image(systemName: "person.2.fill")
                            .font(.callout)
                            .foregroundStyle(.white)
                    }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Student Submissions")
                        .font(.subheadline.bold())
                        .foregroundStyle(.primary)
                    Text("View submissions grouped by student")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if pendingCount > 0 {
                    Text("\(pendingCount)")
                        .font(.caption2.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.orange, in: .capsule)
                        .foregroundStyle(.white)
                }
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(14)
            .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
        }
    }

    // MARK: - Standards Mastery Link

    private var standardsMasteryLink: some View {
        NavigationLink {
            StandardsMasteryView(viewModel: viewModel, course: course)
        } label: {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 10)
                    .fill(.green.gradient)
                    .frame(width: 40, height: 40)
                    .overlay {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.callout)
                            .foregroundStyle(.white)
                    }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Standards Mastery")
                        .font(.subheadline.bold())
                        .foregroundStyle(Color(.label))
                    Text("Track student progress by learning standard")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                let standardCount = viewModel.standardsUsedInCourse(course.id).count
                if standardCount > 0 {
                    Text("\(standardCount)")
                        .font(.caption2.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.green.opacity(0.15), in: .capsule)
                        .foregroundStyle(.green)
                }
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Standards Mastery")
        .accessibilityHint("Double tap to view standards alignment and mastery data")
    }

    // MARK: - Content Actions

    private var contentActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Course Content")
                .font(.headline)

            HStack(spacing: 10) {
                contentActionButton(icon: "folder.fill.badge.plus", label: "Add Module", color: .purple) {
                    showCreateModule = true
                }
                contentActionButton(icon: "questionmark.circle.fill", label: "Create Quiz", color: .orange) {
                    showCreateQuiz = true
                }
            }

            HStack(spacing: 10) {
                NavigationLink {
                    ManageModulesView(course: course, viewModel: viewModel)
                } label: {
                    VStack(spacing: 8) {
                        Image(systemName: "folder.fill")
                            .font(.title2)
                            .foregroundStyle(.indigo)
                        Text("Manage Modules")
                            .font(.caption2.bold())
                            .foregroundStyle(.primary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(.ultraThinMaterial, in: .rect(cornerRadius: 12))
                }
                NavigationLink {
                    ManageStudentsView(course: course, viewModel: viewModel)
                } label: {
                    VStack(spacing: 8) {
                        Image(systemName: "person.2.fill")
                            .font(.title2)
                            .foregroundStyle(.teal)
                        Text("Students")
                            .font(.caption2.bold())
                            .foregroundStyle(.primary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(.ultraThinMaterial, in: .rect(cornerRadius: 12))
                }
            }
        }
    }

    private func contentActionButton(icon: String, label: String, color: Color, action: @escaping () -> Void) -> some View {
        Button {
            hapticTrigger.toggle()
            action()
        } label: {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color)
                Text(label)
                    .font(.caption2.bold())
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(.ultraThinMaterial, in: .rect(cornerRadius: 12))
        }
        .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
    }

    // MARK: - Discussion Forum Link

    private var teacherDiscussionLink: some View {
        NavigationLink {
            DiscussionForumView(course: course, viewModel: viewModel)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.title3)
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 36, height: 36)
                    .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Discussion Forum")
                        .font(.subheadline.bold())
                        .foregroundStyle(Color(.label))
                    Text("View and manage course discussions")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                let threadCount = viewModel.discussionThreads.filter { $0.courseId == course.id }.count
                if threadCount > 0 {
                    Text("\(threadCount)")
                        .font(.caption2.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.accentColor.opacity(0.15), in: .capsule)
                        .foregroundStyle(Color.accentColor)
                }

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Discussion Forum")
        .accessibilityHint("Double tap to open course discussions")
    }

    // MARK: - Templates & Peer Review Links

    private var templatesAndPeerReviewSection: some View {
        HStack(spacing: 10) {
            NavigationLink {
                AssignmentTemplatesView(viewModel: viewModel, courseId: course.id)
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "doc.on.doc.fill")
                        .font(.title3)
                        .foregroundStyle(.purple)
                        .frame(width: 32, height: 32)
                        .background(.purple.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Templates")
                            .font(.caption.bold())
                            .foregroundStyle(Color(.label))
                        Text("Reuse assignments")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .padding(12)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Assignment Templates")
            .accessibilityHint("View and use saved assignment templates")

            if let firstAssignment = courseAssignments.first {
                NavigationLink {
                    PeerReviewSetupView(viewModel: viewModel, course: course, assignment: firstAssignment)
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "person.2.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.red)
                            .frame(width: 32, height: 32)
                            .background(.red.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Peer Review")
                                .font(.caption.bold())
                                .foregroundStyle(Color(.label))
                            Text("Setup reviews")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(12)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Peer Review Setup")
                .accessibilityHint("Configure peer review for assignments")
            }
        }
    }

    // MARK: - Course Content (Modules & Lessons)

    private var courseContentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Modules")
                    .font(.headline)
                Spacer()
                Text("\(course.modules.count) total")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if course.modules.isEmpty {
                HStack {
                    Image(systemName: "folder")
                        .foregroundStyle(.secondary)
                    Text("No modules yet. Add a module to start building content.")
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(.ultraThinMaterial, in: .rect(cornerRadius: 12))
            } else {
                ForEach(course.modules) { module in
                    moduleRow(module)
                }
            }
        }
    }

    private func moduleRow(_ module: Module) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "folder.fill")
                    .foregroundStyle(Theme.courseColor(course.colorName))
                Text(module.title)
                    .font(.subheadline.bold())
                Spacer()
                Text("\(module.lessons.count) lessons")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if !module.lessons.isEmpty {
                ForEach(module.lessons) { lesson in
                    HStack(spacing: 8) {
                        Image(systemName: lesson.type.iconName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(width: 20)
                        Text(lesson.title)
                            .font(.caption)
                            .lineLimit(1)
                        Spacer()
                        Text("\(lesson.duration) min")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.leading, 8)
                }
            }

            Button {
                hapticTrigger.toggle()
                selectedModuleForLesson = module
            } label: {
                Label("Add Lesson", systemImage: "plus.circle")
                    .font(.caption.bold())
            }
            .tint(.red)
            .padding(.top, 2)
            .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
        }
        .padding(12)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 12))
    }

    private var enrolledStudentsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Enrolled Students")
                    .font(.headline)
                Spacer()
                Text("\(course.enrolledStudentCount) total")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if course.enrolledStudentCount == 0 {
                HStack {
                    Image(systemName: "person.badge.plus")
                        .foregroundStyle(.secondary)
                    Text("No students enrolled yet")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                Text("Share class code **\(course.classCode)** with students to enroll them.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

    // MARK: - Assignments Section

    private var assignmentsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Assignments")
                .font(.headline)

            if courseAssignments.isEmpty {
                HStack {
                    Image(systemName: "doc.text")
                        .foregroundStyle(.secondary)
                    Text("No assignments yet")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(.ultraThinMaterial, in: .rect(cornerRadius: 12))
            } else {
                ForEach(courseAssignments) { assignment in
                    assignmentRow(assignment)
                }
            }
        }
    }

    private func assignmentRow(_ assignment: Assignment) -> some View {
        let assignmentStandards = viewModel.standards(forAssignment: assignment)

        return VStack(spacing: 0) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(assignment.title)
                        .font(.subheadline.bold())
                    if let studentName = assignment.studentName {
                        HStack(spacing: 4) {
                            Image(systemName: "person.fill")
                                .font(.caption2)
                                .foregroundStyle(.red)
                            Text(studentName)
                                .font(.caption)
                                .foregroundStyle(.red)

                            // Notes badge button
                            if let studentId = assignment.studentId {
                                let count = viewModel.noteCount(forStudent: studentId, inCourse: course.id)
                                Button {
                                    hapticTrigger.toggle()
                                    selectedStudentForNotes = (id: studentId, name: studentName)
                                    showStudentNotes = true
                                } label: {
                                    HStack(spacing: 3) {
                                        Image(systemName: "note.text")
                                            .font(.caption2)
                                        if count > 0 {
                                            Text("\(count)")
                                                .font(.caption2.bold())
                                        }
                                    }
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(.blue.opacity(0.12), in: Capsule())
                                    .foregroundStyle(.blue)
                                }
                                .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
                                .accessibilityLabel("\(count) note\(count == 1 ? "" : "s") for \(studentName)")
                                .accessibilityHint("Double tap to view and add notes")
                            }
                        }
                    }
                    Text("Due: \(assignment.dueDate.formatted(.dateTime.month(.abbreviated).day()))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(assignment.points) pts")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    if assignment.isSubmitted {
                        if let grade = assignment.grade {
                            Text("Graded: \(Int(grade))%")
                                .font(.caption2.bold())
                                .foregroundStyle(.green)
                        } else {
                            Text("Submitted")
                                .font(.caption2)
                                .foregroundStyle(.blue)
                        }
                    }
                }
            }

            // Standards tags
            if !assignmentStandards.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.seal")
                            .font(.caption2)
                            .foregroundStyle(.green)
                        ForEach(assignmentStandards) { std in
                            Text(std.code)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.green.opacity(0.1), in: Capsule())
                                .foregroundStyle(.green)
                        }
                    }
                }
                .padding(.top, 6)
                .accessibilityLabel("Standards: \(assignmentStandards.map(\.code).joined(separator: ", "))")
            }

            // Grade button for submitted but ungraded assignments
            if assignment.isSubmitted && assignment.grade == nil {
                Divider()
                    .padding(.vertical, 8)

                NavigationLink {
                    GradeSubmissionView(viewModel: viewModel, assignment: assignment)
                } label: {
                    Label("Grade Submission", systemImage: "pencil.and.list.clipboard")
                        .font(.caption.bold())
                        .foregroundStyle(.orange)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(.orange.opacity(0.1), in: .rect(cornerRadius: 8))
                }
            }

            // Quick action row: Edit, Duplicate, Peer Review
            Divider()
                .padding(.vertical, 4)

            HStack(spacing: 8) {
                NavigationLink {
                    EditAssignmentView(assignment: assignment, viewModel: viewModel)
                } label: {
                    Label("Edit", systemImage: "pencil")
                        .font(.caption2.bold())
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color(.tertiarySystemFill), in: Capsule())
                        .foregroundStyle(Color(.label))
                }
                .accessibilityLabel("Edit \(assignment.title)")

                NavigationLink {
                    PeerReviewSetupView(viewModel: viewModel, course: course, assignment: assignment)
                } label: {
                    Label("Peer Review", systemImage: "person.2.fill")
                        .font(.caption2.bold())
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.red.opacity(0.1), in: Capsule())
                        .foregroundStyle(.red)
                }
                .accessibilityLabel("Set up peer review for \(assignment.title)")

                Spacer()
            }
        }
        .padding(12)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 12))
    }

    // MARK: - Add Assignment Sheet

    private var addAssignmentDetailsSection: some View {
        Section("Assignment Details") {
            TextField("Title", text: $newTitle)
            TextField("Instructions", text: $newInstructions, axis: .vertical)
                .lineLimit(3...)
            DatePicker("Due Date", selection: $newDueDate, displayedComponents: .date)
            Stepper("Points: \(newPoints)", value: $newPoints, in: 10...500, step: 10)
        }
    }

    private var addAssignmentLatePolicySection: some View {
        Section {
            Picker("Penalty Type", selection: $newLatePenaltyType) {
                ForEach(LatePenaltyType.allCases, id: \.self) { type in
                    Label(type.displayName, systemImage: type.iconName)
                        .tag(type)
                }
            }
            if newLatePenaltyType != .none && newLatePenaltyType != .noCredit {
                HStack {
                    Text("Penalty per day").font(.subheadline)
                    Spacer()
                    TextField("10", value: $newLatePenaltyPerDay, format: .number)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 70)
                    Text(newLatePenaltyType == .percentPerDay ? "%" : "pts")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            if newLatePenaltyType != .none {
                Stepper("Max late days: \(newMaxLateDays)", value: $newMaxLateDays, in: 1...30)
                    .font(.subheadline)
            }
            if newLatePenaltyType != .none {
                latePolicyPreview
            }
        } header: {
            Label("Late Policy", systemImage: "clock.badge.exclamationmark")
        } footer: {
            Text("Set how late submissions are penalized. Students see the policy before submitting.")
        }
    }

    private var addAssignmentResubmissionSection: some View {
        Section {
            Toggle("Allow Resubmission", isOn: $newAllowResubmission)
            if newAllowResubmission {
                Stepper("Max resubmissions: \(newMaxResubmissions)", value: $newMaxResubmissions, in: 1...5)
                    .font(.subheadline)
                Toggle("Set resubmission deadline", isOn: $newHasResubmissionDeadline)
                if newHasResubmissionDeadline {
                    DatePicker("Deadline", selection: $newResubmissionDeadline, displayedComponents: [.date, .hourAndMinute])
                }
            }
        } header: {
            Label("Resubmission", systemImage: "arrow.counterclockwise.circle")
        } footer: {
            if newAllowResubmission {
                Text("Students can resubmit up to \(newMaxResubmissions) time\(newMaxResubmissions == 1 ? "" : "s") after being graded. Previous grades are preserved in history.")
            }
        }
    }

    private var addAssignmentStandardsSection: some View {
        Section {
            Button {
                hapticTrigger.toggle()
                showStandardsPicker = true
            } label: {
                HStack {
                    Label("Select Standards", systemImage: "checkmark.seal")
                        .foregroundStyle(Color(.label))
                    Spacer()
                    Text("\(newStandardIds.count) selected")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
            .accessibilityLabel("Select learning standards")
            .accessibilityValue("\(newStandardIds.count) standards selected")
            let selected = viewModel.storedLearningStandards.filter { newStandardIds.contains($0.id) }
            ForEach(selected) { std in
                HStack(spacing: 8) {
                    Text(std.code)
                        .font(.caption.bold())
                        .foregroundStyle(Color.accentColor)
                    Text(std.title)
                        .font(.caption)
                        .foregroundStyle(Color(.label))
                    Spacer()
                    Button {
                        hapticTrigger.toggle()
                        newStandardIds.removeAll { $0 == std.id }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
                    .accessibilityLabel("Remove \(std.code)")
                }
            }
        } header: {
            Label("Learning Standards", systemImage: "checkmark.seal.fill")
        } footer: {
            Text("Tag Common Core or other standards to track mastery across assignments.")
        }
    }

    private var addAssignmentSheet: some View {
        NavigationStack {
            Form {
                addAssignmentDetailsSection
                addAssignmentLatePolicySection
                addAssignmentResubmissionSection
                addAssignmentStandardsSection
            }
            .navigationTitle("New Assignment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        hapticTrigger.toggle()
                        resetAssignmentForm()
                        showAddAssignment = false
                    }
                    .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        hapticTrigger.toggle()
                        createAssignment()
                    }
                    .fontWeight(.semibold)
                    .disabled(newTitle.trimmingCharacters(in: .whitespaces).isEmpty || isCreating)
                    .sensoryFeedback(.impact(weight: .medium), trigger: hapticTrigger)
                }
            }
            .overlay {
                if isCreating {
                    ZStack {
                        Color.black.opacity(0.3).ignoresSafeArea()
                        ProgressView("Creating...")
                            .padding(24)
                            .background(.regularMaterial, in: .rect(cornerRadius: 16))
                    }
                }
            }
            .alert("Error", isPresented: Binding(
                get: { createError != nil },
                set: { if !$0 { createError = nil } }
            )) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(createError ?? "")
            }
        }
    }

    /// Preview of late penalty impact at various days late.
    private var latePolicyPreview: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Penalty Preview")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            let previewDays = [1, 3, 5, newMaxLateDays]
            ForEach(Array(Set(previewDays)).sorted(), id: \.self) { day in
                if day <= newMaxLateDays {
                    HStack {
                        Text("\(day) day\(day == 1 ? "" : "s") late:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        switch newLatePenaltyType {
                        case .percentPerDay:
                            Text("-\(Int(min(Double(day) * newLatePenaltyPerDay, 100)))%")
                                .font(.caption.bold())
                                .foregroundStyle(.red)
                        case .flatDeduction:
                            Text("-\(Int(Double(day) * newLatePenaltyPerDay)) pts")
                                .font(.caption.bold())
                                .foregroundStyle(.red)
                        case .noCredit:
                            Text("No Credit")
                                .font(.caption.bold())
                                .foregroundStyle(.red)
                        case .none:
                            EmptyView()
                        }
                    }
                }
            }

            if newMaxLateDays < 30 {
                HStack {
                    Text("After \(newMaxLateDays) days:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("Not Accepted")
                        .font(.caption.bold())
                        .foregroundStyle(.red)
                }
            }
        }
        .padding(10)
        .background(Color(.tertiarySystemFill), in: .rect(cornerRadius: 8))
    }

    private func createAssignment() {
        isCreating = true
        createError = nil
        let standardIdsToTag = newStandardIds
        let trimmedTitle = newTitle.trimmingCharacters(in: .whitespaces)
        Task {
            do {
                try await viewModel.createAssignmentWithPolicy(
                    courseId: course.id,
                    title: trimmedTitle,
                    instructions: newInstructions.trimmingCharacters(in: .whitespaces),
                    dueDate: newDueDate,
                    points: newPoints,
                    latePenaltyType: newLatePenaltyType,
                    latePenaltyPerDay: newLatePenaltyPerDay,
                    maxLateDays: newMaxLateDays,
                    allowResubmission: newAllowResubmission,
                    maxResubmissions: newMaxResubmissions,
                    resubmissionDeadline: newHasResubmissionDeadline ? newResubmissionDeadline : nil
                )
                // Tag standards on the newly created assignment
                if !standardIdsToTag.isEmpty {
                    if let created = viewModel.assignments.first(where: {
                        $0.courseId == course.id && $0.title == trimmedTitle
                    }) {
                        viewModel.updateAssignmentStandards(assignmentId: created.id, standardIds: standardIdsToTag)
                    }
                }
                resetAssignmentForm()
                showAddAssignment = false
            } catch {
                createError = "Failed to create assignment: \(error.localizedDescription)"
            }
            isCreating = false
        }
    }

    private func resetAssignmentForm() {
        newTitle = ""
        newInstructions = ""
        newDueDate = Date().addingTimeInterval(7 * 86400)
        newPoints = 100
        newLatePenaltyType = .none
        newLatePenaltyPerDay = 10
        newMaxLateDays = 7
        newAllowResubmission = false
        newMaxResubmissions = 1
        newHasResubmissionDeadline = false
        newResubmissionDeadline = Date().addingTimeInterval(14 * 86400)
        newStandardIds = []
    }
}
