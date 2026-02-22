import SwiftUI

struct GradeExportView: View {
    @Bindable var viewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var selectedCourseId: UUID?
    @State private var useDateFilter = false
    @State private var startDate = Calendar.current.date(byAdding: .month, value: -3, to: Date()) ?? Date()
    @State private var endDate = Date()
    @State private var csvURL: URL?
    @State private var hapticTrigger = false
    @State private var showNoDataAlert = false

    /// Filtered assignments for the selected course.
    private var filteredAssignments: [Assignment] {
        guard let courseId = selectedCourseId else { return [] }
        let submitted = viewModel.assignments.filter { $0.courseId == courseId && $0.isSubmitted }
        if useDateFilter {
            return submitted.filter { $0.dueDate >= startDate && $0.dueDate <= endDate }
        }
        return submitted
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    coursePicker
                    if selectedCourseId != nil {
                        dateFilterSection
                        previewTable
                        exportButton
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Export Grades")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        hapticTrigger.toggle()
                        dismiss()
                    }
                    .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
                }
            }
            .alert("No Data", isPresented: $showNoDataAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("There are no submitted assignments for the selected course and date range.")
            }
        }
    }

    // MARK: - Course Picker

    private var coursePicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Select Course", systemImage: "book.fill")
                .font(.headline)

            if viewModel.courses.isEmpty {
                Text("No courses available")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(viewModel.courses) { course in
                            courseChip(course)
                        }
                    }
                }
            }
        }
        .padding(14)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

    private func courseChip(_ course: Course) -> some View {
        let isSelected = selectedCourseId == course.id
        let color = Theme.courseColor(course.colorName)

        return Button {
            hapticTrigger.toggle()
            withAnimation(.snappy) {
                selectedCourseId = course.id
                csvURL = nil
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: course.iconSystemName)
                    .font(.caption)
                Text(course.title)
                    .font(.caption.bold())
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .foregroundStyle(isSelected ? .white : color)
            .background(isSelected ? color : color.opacity(0.12))
            .clipShape(Capsule())
            .overlay(
                Capsule().strokeBorder(color.opacity(0.3), lineWidth: 1)
            )
        }
        .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
        .accessibilityLabel("\(course.title)\(isSelected ? ", selected" : "")")
    }

    // MARK: - Date Filter

    private var dateFilterSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle(isOn: $useDateFilter.animation(.snappy)) {
                Label("Filter by Date Range", systemImage: "calendar")
                    .font(.headline)
            }
            .tint(.pink)

            if useDateFilter {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("From")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        DatePicker("", selection: $startDate, displayedComponents: .date)
                            .labelsHidden()
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("To")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        DatePicker("", selection: $endDate, displayedComponents: .date)
                            .labelsHidden()
                    }
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .padding(14)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

    // MARK: - Preview Table

    private var previewTable: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Preview (\(filteredAssignments.count))", systemImage: "tablecells")
                    .font(.headline)
                Spacer()
                if !filteredAssignments.isEmpty {
                    Text("Scroll to see all")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            if filteredAssignments.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "tray")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    Text("No submissions found")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                // Column headers
                HStack(spacing: 0) {
                    Text("Student")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("Assignment")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("Grade")
                        .frame(width: 60, alignment: .trailing)
                    Text("Letter")
                        .frame(width: 50, alignment: .trailing)
                }
                .font(.caption2.bold())
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)

                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(filteredAssignments.prefix(50)) { assignment in
                            previewRow(assignment)
                        }
                    }
                }
                .frame(maxHeight: 300)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(14)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

    private func previewRow(_ assignment: Assignment) -> some View {
        let gradeStr: String
        let letterGrade: String
        let gradeColor: Color
        if let grade = assignment.grade {
            gradeStr = String(format: "%.0f%%", grade)
            letterGrade = viewModel.gradeService.letterGrade(from: grade)
            gradeColor = Theme.gradeColor(grade)
        } else {
            gradeStr = "--"
            letterGrade = "--"
            gradeColor = .secondary
        }

        return HStack(spacing: 0) {
            Text(assignment.studentName ?? "Unknown")
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(1)
            Text(assignment.title)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(1)
            Text(gradeStr)
                .foregroundStyle(gradeColor)
                .frame(width: 60, alignment: .trailing)
            Text(letterGrade)
                .fontWeight(.semibold)
                .foregroundStyle(gradeColor)
                .frame(width: 50, alignment: .trailing)
        }
        .font(.caption)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(assignment.studentName ?? "Unknown"), \(assignment.title), grade \(gradeStr), \(letterGrade)")
    }

    // MARK: - Export Button

    @ViewBuilder
    private var exportButton: some View {
        if let courseId = selectedCourseId {
            if let url = csvURL {
                ShareLink(item: url, subject: Text("Grade Export"), message: Text("Grades exported from WolfWhale Learning")) {
                    Label("Share CSV", systemImage: "square.and.arrow.up")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .padding(.top, 4)
            } else {
                Button {
                    hapticTrigger.toggle()
                    generateCSV(courseId: courseId)
                } label: {
                    Label("Export CSV", systemImage: "arrow.down.doc.fill")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                }
                .buttonStyle(.borderedProminent)
                .tint(.pink)
                .disabled(filteredAssignments.isEmpty)
                .sensoryFeedback(.impact(weight: .medium), trigger: hapticTrigger)
                .padding(.top, 4)
            }
        }
    }

    // MARK: - Helpers

    private func generateCSV(courseId: UUID) {
        let start: Date? = useDateFilter ? startDate : nil
        let end: Date? = useDateFilter ? endDate : nil

        if let url = viewModel.exportGradesToCSV(courseId: courseId, startDate: start, endDate: end) {
            withAnimation(.snappy) {
                csvURL = url
            }
        } else {
            showNoDataAlert = true
        }
    }
}
