import SwiftUI

struct AssignmentsView: View {
    @Bindable var viewModel: AppViewModel
    @State private var selectedFilter = 0
    @State private var showSubmitSheet = false
    @State private var selectedAssignment: Assignment?
    @State private var hapticTrigger = false

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
                LazyVStack(spacing: 14) {
                    filterBar
                    ForEach(filtered) { assignment in
                        assignmentRow(assignment)
                            .onAppear {
                                if assignment.id == filtered.last?.id {
                                    Task { await viewModel.loadMoreAssignments() }
                                }
                            }
                    }
                    if viewModel.assignmentPagination.isLoadingMore {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
            }
            .overlay {
                if viewModel.assignments.isEmpty {
                    ContentUnavailableView(
                        "No Assignments",
                        systemImage: "doc.text",
                        description: Text("Assignments from your courses will appear here")
                    )
                } else if filtered.isEmpty {
                    ContentUnavailableView(
                        "No Matching Assignments",
                        systemImage: "line.3.horizontal.decrease.circle",
                        description: Text("Try a different filter to see assignments")
                    )
                }
            }
            .refreshable {
                await viewModel.refreshAssignments()
            }
            .navigationTitle("Assignments")
            .task { await viewModel.loadAssignmentsIfNeeded() }
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
                        hapticTrigger.toggle()
                        withAnimation(.snappy) { selectedFilter = index }
                    }
                    .font(.subheadline.bold())
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(selectedFilter == index ? .purple.opacity(0.2) : Color(.tertiarySystemFill), in: Capsule())
                    .foregroundStyle(selectedFilter == index ? .purple : .secondary)
                    .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
                    .accessibilityLabel("\(label) filter")
                    .accessibilityAddTraits(selectedFilter == index ? .isSelected : [])
                }
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 6)
            .glassEffect(.regular, in: .capsule)
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
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            if !assignment.isSubmitted && !assignment.isOverdue {
                Button {
                    hapticTrigger.toggle()
                    selectedAssignment = assignment
                } label: {
                    Text("Submit")
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                }
                .buttonStyle(.borderedProminent)
                .tint(.purple)
                .sensoryFeedback(.impact(weight: .medium), trigger: hapticTrigger)
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
        SubmitAssignmentView(assignment: assignment, viewModel: viewModel)
    }
}
