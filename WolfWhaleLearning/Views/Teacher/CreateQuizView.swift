import SwiftUI

struct CreateQuizView: View {
    @Bindable var viewModel: AppViewModel
    let course: Course

    @State private var quizTitle = ""
    @State private var timeLimit = 15
    @State private var dueDate = Date().addingTimeInterval(7 * 86400)
    @State private var xpReward = 50
    @State private var questions: [DraftQuestion] = [DraftQuestion()]
    @State private var isLoading = false
    @State private var showSuccess = false
    @State private var errorMessage: String?

    @Environment(\.dismiss) private var dismiss

    private var isValid: Bool {
        let titleOK = !quizTitle.trimmingCharacters(in: .whitespaces).isEmpty
        let questionsOK = questions.allSatisfy { q in
            !q.text.trimmingCharacters(in: .whitespaces).isEmpty &&
            q.options.allSatisfy { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        }
        return titleOK && questionsOK && !questions.isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                quizDetailsSection
                questionsSection
                addQuestionButton
                createButton
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Create Quiz")
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if showSuccess {
                successOverlay
            }
        }
    }

    // MARK: - Quiz Details

    private var quizDetailsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Quiz Details", systemImage: "questionmark.circle.fill")
                .font(.headline)

            TextField("Quiz Title", text: $quizTitle)
                .textFieldStyle(.roundedBorder)

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Time Limit")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Stepper("\(timeLimit) min", value: $timeLimit, in: 5...120, step: 5)
                        .font(.subheadline)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("XP Reward")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Stepper("\(xpReward) XP", value: $xpReward, in: 10...500, step: 10)
                        .font(.subheadline)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Due Date")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                DatePicker(
                    "Due Date",
                    selection: $dueDate,
                    displayedComponents: .date
                )
                .datePickerStyle(.compact)
                .labelsHidden()
            }
        }
        .padding(14)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

    // MARK: - Questions

    private var questionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Questions", systemImage: "list.number")
                    .font(.headline)
                Spacer()
                Text("\(questions.count) question\(questions.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ForEach(questions.indices, id: \.self) { index in
                questionCard(index: index)
            }
        }
    }

    private func questionCard(index: Int) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Question \(index + 1)")
                    .font(.subheadline.bold())
                    .foregroundStyle(.pink)
                Spacer()
                if questions.count > 1 {
                    Button {
                        withAnimation(.snappy) {
                            _ = questions.remove(at: index)
                        }
                    } label: {
                        Image(systemName: "trash")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }

            TextField("Question text", text: $questions[index].text, axis: .vertical)
                .lineLimit(2...)
                .textFieldStyle(.roundedBorder)

            VStack(spacing: 8) {
                ForEach(0..<4, id: \.self) { optionIndex in
                    HStack(spacing: 8) {
                        Button {
                            questions[index].correctIndex = optionIndex
                        } label: {
                            Image(systemName: questions[index].correctIndex == optionIndex
                                  ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(questions[index].correctIndex == optionIndex
                                                 ? .green : .secondary)
                                .font(.title3)
                        }
                        .buttonStyle(.plain)

                        TextField("Option \(optionIndex + 1)", text: $questions[index].options[optionIndex])
                            .textFieldStyle(.roundedBorder)
                            .font(.subheadline)
                    }
                }
            }

            Text("Tap the circle to mark the correct answer")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 12))
    }

    // MARK: - Add Question

    private var addQuestionButton: some View {
        Button {
            withAnimation(.snappy) {
                questions.append(DraftQuestion())
            }
        } label: {
            Label("Add Question", systemImage: "plus.circle.fill")
                .font(.subheadline.bold())
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
        }
        .buttonStyle(.bordered)
        .tint(.pink)
    }

    // MARK: - Create Button

    private var createButton: some View {
        VStack(spacing: 8) {
            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(8)
                    .frame(maxWidth: .infinity)
                    .background(.red.opacity(0.1), in: .rect(cornerRadius: 8))
            }

            Button {
                createQuiz()
            } label: {
                Group {
                    if isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Label("Create Quiz", systemImage: "checkmark.circle.fill")
                            .fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
            }
            .buttonStyle(.borderedProminent)
            .tint(.pink)
            .disabled(isLoading || !isValid)
        }
        .padding(.top, 4)
    }

    // MARK: - Success Overlay

    private var successOverlay: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.green)
                Text("Quiz Created")
                    .font(.title3.bold())
                Text("\(quizTitle) with \(questions.count) questions")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(32)
            .background(.regularMaterial, in: .rect(cornerRadius: 20))
        }
        .transition(.opacity)
        .onTapGesture {
            withAnimation { showSuccess = false }
            dismiss()
        }
    }

    // MARK: - Actions

    private func createQuiz() {
        isLoading = true
        errorMessage = nil

        let trimmedTitle = quizTitle.trimmingCharacters(in: .whitespaces)
        let quizQuestions = questions.map { draft in
            QuizQuestion(
                id: UUID(),
                text: draft.text.trimmingCharacters(in: .whitespaces),
                options: draft.options.map { $0.trimmingCharacters(in: .whitespaces) },
                correctIndex: draft.correctIndex
            )
        }

        Task {
            do {
                try await viewModel.createQuiz(
                    courseId: course.id,
                    title: trimmedTitle,
                    questions: quizQuestions,
                    timeLimit: timeLimit,
                    dueDate: dueDate,
                    xpReward: xpReward
                )
                isLoading = false
                withAnimation(.snappy) {
                    showSuccess = true
                }
                try? await Task.sleep(for: .seconds(2))
                withAnimation { showSuccess = false }
                dismiss()
            } catch {
                errorMessage = "Failed to create quiz. Please try again."
                isLoading = false
            }
        }
    }
}

// MARK: - Draft Question Model

private struct DraftQuestion {
    var text = ""
    var options = ["", "", "", ""]
    var correctIndex = 0
}
