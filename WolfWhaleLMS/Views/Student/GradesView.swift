import SwiftUI

struct GradesView: View {
    let viewModel: AppViewModel

    private var gpa: Double {
        guard !viewModel.grades.isEmpty else { return 0 }
        return viewModel.grades.reduce(0) { $0 + $1.numericGrade } / Double(viewModel.grades.count)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                gpaCard
                gradesList
            }
            .padding(.horizontal)
            .padding(.top, 8)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Grades")
    }

    private var gpaCard: some View {
        HStack(spacing: 20) {
            ZStack {
                Circle()
                    .stroke(.quaternary, lineWidth: 8)
                Circle()
                    .trim(from: 0, to: gpa / 100)
                    .stroke(Theme.gradeColor(gpa), style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 2) {
                    Text(String(format: "%.1f", gpa))
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
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up.right")
                        .font(.caption)
                    Text("Trending up from last semester")
                        .font(.caption)
                }
                .foregroundStyle(.green)
            }
            Spacer()
        }
        .padding(16)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

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
        }
    }
}
