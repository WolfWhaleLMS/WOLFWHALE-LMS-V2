import SwiftUI

struct AssignmentsView: View {
    @Bindable var viewModel: AppViewModel
    @State private var selectedFilter = 0
    @State private var showSubmitSheet = false
    @State private var selectedAssignment: Assignment?
    @State private var submissionText = ""

    private var filtered: [Assignment] {
        switch selectedFilter {
        case 1: return viewModel.assignments.filter { !$0.isSubmitted && !$0.isOverdue }
        case 2: return viewModel.assignments.filter { $0.isSubmitted }
        case 3: return viewModel.assignments.filter { $0.isOverdue }
        default: return viewModel.assignments
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    filterBar
                    ForEach(filtered) { assignment in
                        assignmentRow(assignment)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Assignments")
            .sheet(item: $selectedAssignment) { assignment in
                submitSheet(assignment)
            }
        }
    }

    private var filterBar: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(Array(["All", "Pending", "Submitted", "Overdue"].enumerated()), id: \.offset) { index, label in
                    Button(label) {
                        withAnimation(.snappy) { selectedFilter = index }
                    }
                    .font(.subheadline.bold())
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(selectedFilter == index ? .purple.opacity(0.2) : Color(.tertiarySystemFill), in: Capsule())
                    .foregroundStyle(selectedFilter == index ? .purple : .secondary)
                    .accessibilityLabel("\(label) filter")
                    .accessibilityAddTraits(selectedFilter == index ? .isSelected : [])
                }
            }
        }
        .contentMargins(.horizontal, 0)
        .scrollIndicators(.hidden)
    }

    private func assignmentRow(_ assignment: Assignment) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(assignment.title)
                        .font(.headline)
                    Text(assignment.courseName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                statusBadge(assignment)
            }

            HStack(spacing: 16) {
                Label(assignment.dueDate.formatted(.dateTime.month(.abbreviated).day()), systemImage: "calendar")
                Label("\(assignment.points) pts", systemImage: "star.fill")
                Label("+\(assignment.xpReward) XP", systemImage: "bolt.fill")
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            if !assignment.isSubmitted && !assignment.isOverdue {
                Button {
                    selectedAssignment = assignment
                } label: {
                    Text("Submit")
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                }
                .buttonStyle(.borderedProminent)
                .tint(.purple)
            }

            if let feedback = assignment.feedback {
                HStack(spacing: 8) {
                    Image(systemName: "text.bubble.fill")
                        .foregroundStyle(.blue)
                    Text(feedback)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(10)
                .background(.blue.opacity(0.08), in: .rect(cornerRadius: 8))
            }
        }
        .padding(14)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(assignment.title) for \(assignment.courseName), due \(assignment.dueDate.formatted(.dateTime.month(.abbreviated).day())), \(assignment.points) points, status: \(assignment.statusText)")
        .accessibilityHint((!assignment.isSubmitted && !assignment.isOverdue) ? "Contains submit button" : "")
    }

    private func statusBadge(_ assignment: Assignment) -> some View {
        Text(assignment.statusText)
            .font(.caption.bold())
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(statusColor(assignment).opacity(0.15), in: Capsule())
            .foregroundStyle(statusColor(assignment))
    }

    private func statusColor(_ assignment: Assignment) -> Color {
        if assignment.grade != nil { return .green }
        if assignment.isSubmitted { return .blue }
        if assignment.isOverdue { return .red }
        return .orange
    }

    private func submitSheet(_ assignment: Assignment) -> some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text(assignment.title)
                    .font(.headline)
                Text(assignment.instructions)
                    .font(.body)
                    .foregroundStyle(.secondary)

                TextEditor(text: $submissionText)
                    .frame(minHeight: 150)
                    .padding(8)
                    .background(Color(.tertiarySystemFill), in: .rect(cornerRadius: 10))

                Spacer()
            }
            .padding()
            .navigationTitle("Submit Assignment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        selectedAssignment = nil
                        submissionText = ""
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Submit") {
                        viewModel.submitAssignment(assignment, text: submissionText)
                        selectedAssignment = nil
                        submissionText = ""
                    }
                    .disabled(submissionText.isEmpty)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}
