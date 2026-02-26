import SwiftUI

// MARK: - Identifiable wrapper for sheet binding

private struct EditingIndex: Identifiable {
    let id = UUID()
    let value: Int
}

struct EnhancedQuizBuilderView: View {
    @Bindable var viewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss

    // MARK: - State

    @State private var draft = QuizDraft()
    @State private var showSettings = false
    @State private var showAddQuestionSheet = false
    @State private var editingIndex: EditingIndex?
    @State private var showPreview = false
    @State private var showPublishConfirmation = false
    @State private var deleteTargetIndex: Int?
    @State private var isLoading = false
    @State private var showSuccess = false
    @State private var errorMessage: String?
    @State private var hapticTrigger = false
    @State private var successMessage = ""

    private var isValid: Bool { draft.isValid }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    headerSection
                    settingsSection
                    questionsSection
                    addQuestionButton
                    bottomActions
                }
                .padding(.horizontal)
                .padding(.bottom, 30)
            }
            #if canImport(UIKit)
            .background(Color(UIColor.systemGroupedBackground))
            #endif
            .navigationTitle("Quiz Builder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        hapticTrigger.toggle()
                        dismiss()
                    }
                    .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
                }
            }
            .sheet(isPresented: $showAddQuestionSheet) {
                questionTypePicker
            }
            .sheet(item: $editingIndex) { wrapper in
                if draft.questions.indices.contains(wrapper.value) {
                    NavigationStack {
                        QuestionEditorView(question: $draft.questions[wrapper.value])
                    }
                }
            }
            .sheet(isPresented: $showPreview) {
                NavigationStack {
                    QuizPreviewView(draft: draft)
                }
            }
            .alert("Publish Quiz", isPresented: $showPublishConfirmation) {
                Button("Publish", role: .destructive) { publishQuiz() }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This will make the quiz available to students. Are you sure you want to publish \"\(draft.title)\"?")
            }
            .alert("Delete Question", isPresented: Binding(
                get: { deleteTargetIndex != nil },
                set: { if !$0 { deleteTargetIndex = nil } }
            )) {
                Button("Delete", role: .destructive) {
                    if let index = deleteTargetIndex, draft.questions.indices.contains(index) {
                        hapticTrigger.toggle()
                        withAnimation(.snappy) {
                            _ = draft.questions.remove(at: index)
                        }
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Are you sure you want to delete this question?")
            }
            .overlay {
                if isLoading {
                    ZStack {
                        Color.black.opacity(0.3).ignoresSafeArea()
                        ProgressView("Saving quiz...")
                            .padding(24)
                            .background(.regularMaterial, in: .rect(cornerRadius: 16))
                    }
                }
            }
            .overlay {
                if showSuccess {
                    successOverlay
                }
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Quiz Details", systemImage: "questionmark.circle.fill")
                .font(.headline)
                .foregroundStyle(.indigo)

            TextField("Quiz Title", text: $draft.title)
                .textFieldStyle(.roundedBorder)
                .font(.body)

            TextField("Description (optional)", text: $draft.description, axis: .vertical)
                .lineLimit(3...6)
                .textFieldStyle(.roundedBorder)
                .font(.subheadline)

            // Course Picker
            VStack(alignment: .leading, spacing: 4) {
                Text("Course")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Menu {
                    ForEach(viewModel.courses) { course in
                        Button {
                            hapticTrigger.toggle()
                            draft.courseId = course.id
                        } label: {
                            HStack {
                                Text(course.title)
                                if draft.courseId == course.id {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack {
                        Text(selectedCourseName)
                            .foregroundStyle(draft.courseId == nil ? .secondary : .primary)
                        Spacer()
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(10)
                    .background(.background, in: .rect(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                    )
                }
                .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
            }
        }
        .padding(14)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

    private var selectedCourseName: String {
        guard let courseId = draft.courseId,
              let course = viewModel.courses.first(where: { $0.id == courseId }) else {
            return "Select a course"
        }
        return course.title
    }

    // MARK: - Settings Section

    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                hapticTrigger.toggle()
                withAnimation(.snappy) {
                    showSettings.toggle()
                }
            } label: {
                HStack {
                    Label("Quiz Settings", systemImage: "gearshape.fill")
                        .font(.headline)
                        .foregroundStyle(.indigo)
                    Spacer()
                    Image(systemName: showSettings ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
            .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)

            if showSettings {
                VStack(spacing: 14) {
                    // Time Limit
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Time Limit")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Picker("Time Limit", selection: $draft.timeLimitMinutes) {
                            Text("No Limit").tag(Int?.none)
                            ForEach([15, 30, 45, 60, 90, 120], id: \.self) { minutes in
                                Text("\(minutes) min").tag(Int?.some(minutes))
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Divider()

                    // Points Per Question
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Default Points Per Question")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Stepper("\(draft.pointsPerQuestion) pts", value: $draft.pointsPerQuestion, in: 1...100)
                            .font(.subheadline)
                    }

                    Divider()

                    // Passing Score
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Passing Score")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(draft.passingScorePercent)%")
                                .font(.caption.bold())
                                .foregroundStyle(.indigo)
                        }
                        Slider(
                            value: Binding(
                                get: { Double(draft.passingScorePercent) },
                                set: { draft.passingScorePercent = Int($0) }
                            ),
                            in: 0...100,
                            step: 5
                        )
                        .tint(.indigo)
                    }

                    Divider()

                    // Allowed Attempts
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Allowed Attempts")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Picker("Attempts", selection: $draft.allowedAttempts) {
                            Text("1 Attempt").tag(1)
                            Text("2 Attempts").tag(2)
                            Text("3 Attempts").tag(3)
                            Text("Unlimited").tag(0)
                        }
                        .pickerStyle(.segmented)
                    }

                    Divider()

                    // Toggles
                    Toggle(isOn: $draft.shuffleQuestions) {
                        Label("Shuffle Questions", systemImage: "shuffle")
                            .font(.subheadline)
                    }
                    .tint(.indigo)

                    Toggle(isOn: $draft.shuffleOptions) {
                        Label("Shuffle Options", systemImage: "arrow.triangle.swap")
                            .font(.subheadline)
                    }
                    .tint(.indigo)

                    Toggle(isOn: $draft.showResultsImmediately) {
                        Label("Show Results Immediately", systemImage: "eye.fill")
                            .font(.subheadline)
                    }
                    .tint(.indigo)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(14)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

    // MARK: - Questions Section

    private var questionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Questions", systemImage: "list.number")
                    .font(.headline)
                    .foregroundStyle(.indigo)
                Spacer()
                if !draft.questions.isEmpty {
                    Text("\(draft.questions.count) question\(draft.questions.count == 1 ? "" : "s") \u{2022} \(draft.totalPoints) pts")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if draft.questions.isEmpty {
                emptyQuestionsPlaceholder
            } else {
                questionsList
            }
        }
        .padding(14)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

    private var emptyQuestionsPlaceholder: some View {
        VStack(spacing: 10) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.largeTitle)
                .foregroundStyle(.indigo.opacity(0.4))
            Text("No questions yet")
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)
            Text("Tap \"Add Question\" to get started")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    private var questionsList: some View {
        VStack(spacing: 10) {
            ForEach(Array(draft.questions.enumerated()), id: \.element.id) { index, question in
                questionCard(index: index, question: question)
            }
            .onMove { source, destination in
                hapticTrigger.toggle()
                draft.questions.move(fromOffsets: source, toOffset: destination)
            }
        }
    }

    private func questionCard(index: Int, question: QuestionDraft) -> some View {
        HStack(spacing: 10) {
            // Drag Handle
            Image(systemName: "line.3.horizontal")
                .font(.caption)
                .foregroundStyle(.tertiary)

            // Question Number Badge
            Text("\(index + 1)")
                .font(.caption2.bold())
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(.indigo, in: .circle)

            // Type Icon
            Image(systemName: question.type.iconName)
                .font(.caption)
                .foregroundStyle(.indigo)

            // Question Text
            VStack(alignment: .leading, spacing: 2) {
                Text(question.text.isEmpty ? "Untitled Question" : question.text)
                    .font(.subheadline)
                    .lineLimit(2)
                    .foregroundStyle(question.text.isEmpty ? .secondary : .primary)
                Text(question.type.displayName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Points Badge
            Text("\(question.points) pts")
                .font(.caption2.bold())
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.indigo.opacity(0.12), in: .capsule)
                .foregroundStyle(.indigo)

            // Action Buttons
            HStack(spacing: 4) {
                Button {
                    hapticTrigger.toggle()
                    duplicateQuestion(at: index)
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.caption)
                        .foregroundStyle(.indigo)
                }
                .buttonStyle(.plain)
                .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)

                Button {
                    hapticTrigger.toggle()
                    editingIndex = EditingIndex(value: index)
                } label: {
                    Image(systemName: "pencil.circle.fill")
                        .font(.body)
                        .foregroundStyle(.indigo)
                }
                .buttonStyle(.plain)
                .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)

                Button {
                    hapticTrigger.toggle()
                    deleteTargetIndex = index
                } label: {
                    Image(systemName: "trash")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
                .sensoryFeedback(.impact(weight: .heavy), trigger: hapticTrigger)
            }
        }
        .padding(12)
        #if canImport(UIKit)
        .background(Color(UIColor.systemBackground), in: .rect(cornerRadius: 12))
        #endif
    }

    // MARK: - Add Question Button

    private var addQuestionButton: some View {
        Button {
            hapticTrigger.toggle()
            showAddQuestionSheet = true
        } label: {
            Label("Add Question", systemImage: "plus.circle.fill")
                .font(.subheadline.bold())
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
        }
        .buttonStyle(.bordered)
        .tint(.indigo)
        .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
    }

    // MARK: - Question Type Picker Sheet

    private var questionTypePicker: some View {
        NavigationStack {
            List {
                ForEach(QuestionType.allCases, id: \.self) { type in
                    Button {
                        addQuestion(ofType: type)
                        showAddQuestionSheet = false
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: type.iconName)
                                .font(.title3)
                                .foregroundStyle(.indigo)
                                .frame(width: 36, height: 36)
                                .background(.indigo.opacity(0.12), in: .rect(cornerRadius: 10))

                            VStack(alignment: .leading, spacing: 2) {
                                Text(type.displayName)
                                    .font(.subheadline.bold())
                                    .foregroundStyle(.primary)
                                Text(typeDescription(type))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Question Type")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showAddQuestionSheet = false }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func typeDescription(_ type: QuestionType) -> String {
        switch type {
        case .multipleChoice: "Students select from 2-6 options"
        case .trueFalse: "Students choose True or False"
        case .shortAnswer: "Students type a short response"
        case .fillInBlank: "Students fill in missing words"
        case .matching: "Students match prompts to answers"
        case .essay: "Students write a long-form response"
        }
    }

    // MARK: - Bottom Actions

    private var bottomActions: some View {
        VStack(spacing: 8) {
            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(8)
                    .frame(maxWidth: .infinity)
                    .background(.red.opacity(0.1), in: .rect(cornerRadius: 8))
            }

            HStack(spacing: 12) {
                // Preview
                Button {
                    hapticTrigger.toggle()
                    showPreview = true
                } label: {
                    Label("Preview", systemImage: "eye.fill")
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                }
                .buttonStyle(.bordered)
                .tint(.purple)
                .disabled(draft.questions.isEmpty)
                .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)

                // Save Draft
                Button {
                    hapticTrigger.toggle()
                    saveDraft()
                } label: {
                    Label("Save Draft", systemImage: "square.and.arrow.down.fill")
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                }
                .buttonStyle(.bordered)
                .tint(.indigo)
                .disabled(draft.title.trimmingCharacters(in: .whitespaces).isEmpty)
                .sensoryFeedback(.impact(weight: .medium), trigger: hapticTrigger)
            }

            // Publish
            Button {
                hapticTrigger.toggle()
                showPublishConfirmation = true
            } label: {
                Label("Publish Quiz", systemImage: "paperplane.fill")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
            }
            .buttonStyle(.borderedProminent)
            .tint(.indigo)
            .disabled(isLoading || !isValid)
            .sensoryFeedback(.impact(weight: .heavy), trigger: hapticTrigger)
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
                Text(successMessage)
                    .font(.title3.bold())
                Text(draft.title)
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

    private func addQuestion(ofType type: QuestionType) {
        hapticTrigger.toggle()
        let question = QuestionDraft(type: type, points: draft.pointsPerQuestion)
        withAnimation(.snappy) {
            draft.questions.append(question)
        }
        // Open editor immediately for the new question
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            editingIndex = EditingIndex(value: draft.questions.count - 1)
        }
    }

    private func duplicateQuestion(at index: Int) {
        let duplicated = draft.questions[index].duplicate()
        withAnimation(.snappy) {
            draft.questions.insert(duplicated, at: index + 1)
        }
    }

    private func saveDraft() {
        hapticTrigger.toggle()
        successMessage = "Draft Saved"
        withAnimation(.snappy) {
            showSuccess = true
        }
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            withAnimation { showSuccess = false }
        }
    }

    private func publishQuiz() {
        isLoading = true
        errorMessage = nil

        let quizQuestions = draft.questions.map { q -> QuizQuestion in
            let trimmedText = q.text.trimmingCharacters(in: .whitespaces)
            switch q.type {
            case .multipleChoice:
                return QuizQuestion(
                    id: UUID(),
                    text: trimmedText,
                    questionType: .multipleChoice,
                    options: q.options.map(\.text),
                    correctIndex: q.options.firstIndex(where: \.isCorrect) ?? 0,
                    explanation: q.explanation
                )
            case .trueFalse:
                return QuizQuestion(
                    id: UUID(),
                    text: trimmedText,
                    questionType: .trueFalse,
                    options: q.options.map(\.text),
                    correctIndex: q.options.firstIndex(where: \.isCorrect) ?? 0,
                    explanation: q.explanation
                )
            case .shortAnswer, .fillInBlank:
                return QuizQuestion(
                    id: UUID(),
                    text: trimmedText,
                    questionType: .fillInBlank,
                    acceptedAnswers: q.correctAnswers,
                    explanation: q.explanation
                )
            case .matching:
                let pairs = q.matchingPairs.map {
                    MatchingPair(prompt: $0.prompt, answer: $0.answer)
                }
                return QuizQuestion(
                    id: UUID(),
                    text: trimmedText,
                    questionType: .matching,
                    matchingPairs: pairs,
                    needsManualReview: true,
                    explanation: q.explanation
                )
            case .essay:
                return QuizQuestion(
                    id: UUID(),
                    text: trimmedText,
                    questionType: .essay,
                    essayPrompt: q.essayPrompt,
                    essayMinWords: q.essayMinWords,
                    needsManualReview: true,
                    explanation: q.explanation
                )
            }
        }

        Task {
            do {
                try await viewModel.createQuiz(
                    courseId: draft.courseId ?? UUID(),
                    title: draft.title.trimmingCharacters(in: .whitespaces),
                    questions: quizQuestions,
                    timeLimit: draft.timeLimitMinutes ?? 0,
                    dueDate: Date().addingTimeInterval(7 * 86400),
                    xpReward: 0
                )
                isLoading = false
                successMessage = "Quiz Published"
                withAnimation(.snappy) {
                    showSuccess = true
                }
                try? await Task.sleep(for: .seconds(2))
                withAnimation { showSuccess = false }
                dismiss()
            } catch {
                errorMessage = UserFacingError.message(from: error)
                isLoading = false
            }
        }
    }
}

