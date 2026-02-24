import SwiftUI
import Supabase

struct ManageStudentsView: View {
    let course: Course
    @Bindable var viewModel: AppViewModel

    @State private var students: [User] = []
    @State private var isLoadingStudents = true
    @State private var copiedCode = false
    @State private var errorMessage: String?
    @State private var unenrollTarget: User?
    @State private var isUnenrolling = false
    @State private var hapticTrigger = false

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                classCodeSection
                statsSection
                studentsListSection
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Manage Students")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadStudents()
        }
        .alert("Unenroll Student", isPresented: Binding(
            get: { unenrollTarget != nil },
            set: { if !$0 { unenrollTarget = nil } }
        )) {
            Button("Unenroll", role: .destructive) {
                if let target = unenrollTarget {
                    unenrollStudent(target)
                }
            }
            Button("Cancel", role: .cancel) {
                unenrollTarget = nil
            }
        } message: {
            if let target = unenrollTarget {
                Text("Are you sure you want to unenroll \(target.fullName) from \(course.title)? They will lose access to course content.")
            }
        }
    }

    // MARK: - Class Code Section

    private var classCodeSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Theme.courseColor(course.colorName).gradient)
                    .frame(width: 44, height: 44)
                    .overlay {
                        Image(systemName: "number")
                            .font(.title3)
                            .foregroundStyle(.white)
                    }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Class Code")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(course.classCode)
                        .font(.title2.bold().monospaced())
                        .foregroundStyle(Theme.courseColor(course.colorName))
                }

                Spacer()

                Button {
                    hapticTrigger.toggle()
                    UIPasteboard.general.string = course.classCode
                    withAnimation(.snappy) {
                        copiedCode = true
                    }
                    Task {
                        try? await Task.sleep(for: .seconds(2))
                        withAnimation { copiedCode = false }
                    }
                } label: {
                    Label(
                        copiedCode ? "Copied!" : "Copy",
                        systemImage: copiedCode ? "checkmark" : "doc.on.doc"
                    )
                    .font(.caption.bold())
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .tint(copiedCode ? .green : .pink)
                .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
            }

            Text("Share this code with students so they can enroll in the course.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Share button
            if let url = URL(string: "wolfwhalelms://enroll?code=\(course.classCode)") {
                ShareLink(item: url, subject: Text("Join \(course.title)"), message: Text("Use class code \(course.classCode) to enroll in \(course.title) on WolfWhale LMS.")) {
                    Label("Share Class Code", systemImage: "square.and.arrow.up")
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                }
                .buttonStyle(.bordered)
                .tint(.pink)
            }
        }
        .padding(14)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

    // MARK: - Stats Section

    private var statsSection: some View {
        HStack(spacing: 12) {
            statCard(label: "Enrolled", value: "\(students.count)", color: Theme.courseColor(course.colorName))
            statCard(label: "Modules", value: "\(course.modules.count)", color: .purple)
            statCard(label: "Lessons", value: "\(course.totalLessons)", color: .orange)
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

    // MARK: - Students List

    private var studentsListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Enrolled Students")
                    .font(.headline)
                Spacer()
                Text("\(students.count) total")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if isLoadingStudents {
                HStack {
                    Spacer()
                    ProgressView()
                        .tint(.pink)
                    Spacer()
                }
                .padding(.vertical, 24)
                .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
            } else if students.isEmpty {
                emptyStudentsState
            } else {
                ForEach(students) { student in
                    studentRow(student)
                }
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(8)
                    .frame(maxWidth: .infinity)
                    .background(.red.opacity(0.1), in: .rect(cornerRadius: 8))
            }
        }
    }

    private var emptyStudentsState: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.badge.plus")
                .font(.system(size: 32))
                .foregroundStyle(.secondary)
            Text("No students enrolled")
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)
            Text("Share the class code \"\(course.classCode)\" with your students so they can join this course.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

    private func studentRow(_ student: User) -> some View {
        HStack(spacing: 12) {
            // Avatar
            Circle()
                .fill(Theme.courseColor(course.colorName).opacity(0.15))
                .frame(width: 40, height: 40)
                .overlay {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.title2)
                        .foregroundStyle(Theme.courseColor(course.colorName))
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(student.fullName)
                    .font(.subheadline.bold())
                Text(student.email)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            // Unenroll button
            Button {
                hapticTrigger.toggle()
                unenrollTarget = student
            } label: {
                Image(systemName: "person.fill.xmark")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(8)
                    .background(.red.opacity(0.1), in: .rect(cornerRadius: 8))
            }
            .buttonStyle(.plain)
            .sensoryFeedback(.impact(weight: .heavy), trigger: hapticTrigger)
        }
        .padding(12)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 12))
    }

    // MARK: - Actions

    private func loadStudents() async {
        isLoadingStudents = true
        students = await viewModel.fetchStudentsInCourse(course.id)
        isLoadingStudents = false
    }

    private func unenrollStudent(_ student: User) {
        isUnenrolling = true
        errorMessage = nil

        Task {
            do {
                if !viewModel.isDemoMode {
                    try await supabaseClient
                        .from("course_enrollments")
                        .delete()
                        .eq("student_id", value: student.id.uuidString)
                        .eq("course_id", value: course.id.uuidString)
                        .execute()
                }

                withAnimation(.snappy) {
                    students.removeAll { $0.id == student.id }
                }

                // Update enrolled count in local state
                if let courseIndex = viewModel.courses.firstIndex(where: { $0.id == course.id }) {
                    viewModel.courses[courseIndex].enrolledStudentCount = max(0, viewModel.courses[courseIndex].enrolledStudentCount - 1)
                }

                isUnenrolling = false
            } catch {
                errorMessage = "Failed to unenroll student. Please try again."
                isUnenrolling = false
            }
        }
    }
}
