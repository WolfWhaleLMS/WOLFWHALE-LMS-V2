import SwiftUI

struct GradesView: View {
    @Bindable var viewModel: AppViewModel

    /// Average percentage across all courses (0-100 scale)
    private var averagePercent: Double {
        guard !viewModel.grades.isEmpty else { return 0 }
        return viewModel.grades.reduce(0) { $0 + $1.numericGrade } / Double(viewModel.grades.count)
    }

    /// GPA on a 4.0 scale, derived from the percentage average
    private var gpa: Double {
        averagePercent / 100.0 * 4.0
    }

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilityLabel("Loading grades")
            } else {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        gpaCard
                        gradesList
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                }
                .overlay {
                    if viewModel.grades.isEmpty {
                        ContentUnavailableView("No Grades Yet", systemImage: "chart.bar", description: Text("Grades will appear here once assignments are graded"))
                    }
                }
            }
        }
        .navigationTitle("Grades")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    ReportCardView(viewModel: viewModel)
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .accessibilityLabel("Report Card")
                .accessibilityHint("Double tap to view your report card")
            }
        }
    }

    private var gpaCard: some View {
        HStack(spacing: 20) {
            ZStack {
                Circle()
                    .stroke(.quaternary, lineWidth: 8)
                Circle()
                    .trim(from: 0, to: min(gpa / 4.0, 1.0))
                    .stroke(Theme.gradeColor(averagePercent), style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 2) {
                    Text(String(format: "%.2f", gpa))
                        .font(.title2.bold())
                    Text("GPA")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 80, height: 80)

            VStack(alignment: .leading, spacing: 6) {
                Text("Overall Performance")
                    .font(.headline)
                Text("\(viewModel.grades.count) courses this semester")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(String(format: "%.1f%% average", averagePercent))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(16)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Overall Performance: GPA \(String(format: "%.2f", gpa)), \(String(format: "%.1f", averagePercent)) percent average, \(viewModel.grades.count) courses this semester")
    }

    @ViewBuilder
    private var gradesList: some View {
        ForEach(viewModel.grades) { grade in
            VStack(spacing: 0) {
                HStack(spacing: 14) {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Theme.courseColor(grade.courseColor).gradient)
                        .frame(width: 44, height: 44)
                        .overlay {
                            Image(systemName: grade.courseIcon)
                                .foregroundStyle(.white)
                        }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(grade.courseName)
                            .font(.headline)
                        Text("\(grade.assignmentGrades.count) graded items")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text(grade.letterGrade)
                            .font(.title3.bold())
                            .foregroundStyle(Theme.gradeColor(grade.numericGrade))
                        Text(String(format: "%.1f%%", grade.numericGrade))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(14)

                Divider().padding(.leading, 72)

                ForEach(grade.assignmentGrades) { ag in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(ag.title)
                                .font(.subheadline)
                            Text(ag.type)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("\(Int(ag.score))/\(Int(ag.maxScore))")
                            .font(.subheadline.bold())
                            .foregroundStyle(Theme.gradeColor(ag.score / ag.maxScore * 100))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                }
            }
            .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(grade.courseName): Grade \(grade.letterGrade), \(String(format: "%.1f", grade.numericGrade)) percent, \(grade.assignmentGrades.count) graded items")
            .onAppear {
                if grade.id == viewModel.grades.last?.id {
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
}
