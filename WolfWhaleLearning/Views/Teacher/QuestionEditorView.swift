import SwiftUI

struct QuestionEditorView: View {
    @Binding var question: QuestionDraft
    @Environment(\.dismiss) private var dismiss

    @State private var hapticTrigger = false
    @State private var allowMultipleCorrect = false
    @State private var newAnswer = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                typeSelector
                questionTextSection
                pointsSection

                switch question.type {
                case .multipleChoice:
                    multipleChoiceSection
                case .trueFalse:
                    trueFalseSection
                case .shortAnswer:
                    shortAnswerSection
                case .fillInBlank:
                    fillInBlankSection
                }

                explanationSection
            }
            .padding(.horizontal)
            .padding(.bottom, 30)
        }
        #if canImport(UIKit)
        .background(Color(UIColor.systemGroupedBackground))
        #endif
        .navigationTitle("Edit Question")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    hapticTrigger.toggle()
                    dismiss()
                }
                .fontWeight(.semibold)
                .foregroundStyle(.indigo)
                .sensoryFeedback(.impact(weight: .medium), trigger: hapticTrigger)
            }
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    hapticTrigger.toggle()
                    dismiss()
                }
                .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
            }
        }
        .onAppear {
            // Check if multiple correct answers are already set
            allowMultipleCorrect = question.options.filter(\.isCorrect).count > 1
        }
    }

    // MARK: - Type Selector

    private var typeSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Question Type")
                .font(.caption)
                .foregroundStyle(.secondary)

            Picker("Type", selection: $question.type) {
                ForEach(QuestionType.allCases, id: \.self) { type in
                    Label(type.displayName, systemImage: type.iconName)
                        .tag(type)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: question.type) { _, newType in
                hapticTrigger.toggle()
                resetOptionsForType(newType)
            }
        }
        .padding(14)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

    // MARK: - Question Text

    private var questionTextSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Question Text", systemImage: "text.alignleft")
                .font(.headline)
                .foregroundStyle(.indigo)

            if question.type == .fillInBlank {
                Text("Use ___ (three underscores) to mark blanks")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            TextEditor(text: $question.text)
                .frame(minHeight: 80)
                .padding(8)
                #if canImport(UIKit)
                .background(Color(UIColor.systemBackground))
                #endif
                .clipShape(.rect(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                )

            if question.type == .fillInBlank {
                fillInBlankPreview
            }
        }
        .padding(14)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

    private var fillInBlankPreview: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Preview")
                .font(.caption)
                .foregroundStyle(.secondary)

            let parts = question.text.components(separatedBy: "___")
            HStack(spacing: 0) {
                ForEach(Array(parts.enumerated()), id: \.offset) { index, part in
                    Text(part)
                        .font(.subheadline)
                    if index < parts.count - 1 {
                        Text(" _______ ")
                            .font(.subheadline)
                            .foregroundStyle(.indigo)
                            .underline()
                    }
                }
            }
            .padding(8)
            #if canImport(UIKit)
            .background(Color(UIColor.systemBackground).opacity(0.5), in: .rect(cornerRadius: 8))
            #endif
        }
    }

    // MARK: - Points

    private var pointsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Points", systemImage: "star.fill")
                .font(.headline)
                .foregroundStyle(.indigo)

            Stepper("\(question.points) points", value: $question.points, in: 1...100)
                .font(.subheadline)
        }
        .padding(14)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

    // MARK: - Multiple Choice

    private var multipleChoiceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Answer Options", systemImage: "list.bullet.circle.fill")
                    .font(.headline)
                    .foregroundStyle(.indigo)
                Spacer()
                Toggle("Multiple Correct", isOn: $allowMultipleCorrect)
                    .font(.caption)
                    .toggleStyle(.switch)
                    .tint(.indigo)
                    .fixedSize()
                    .onChange(of: allowMultipleCorrect) { _, newValue in
                        if !newValue {
                            // Keep only the first correct answer
                            var foundFirst = false
                            for i in question.options.indices {
                                if question.options[i].isCorrect {
                                    if foundFirst {
                                        question.options[i].isCorrect = false
                                    }
                                    foundFirst = true
                                }
                            }
                        }
                    }
            }

            ForEach(Array(question.options.enumerated()), id: \.element.id) { index, option in
                HStack(spacing: 10) {
                    // Correct answer toggle
                    Button {
                        hapticTrigger.toggle()
                        toggleCorrectOption(at: index)
                    } label: {
                        Image(systemName: question.options[index].isCorrect
                              ? "checkmark.circle.fill" : "circle")
                            .font(.title3)
                            .foregroundStyle(question.options[index].isCorrect ? .green : .secondary)
                    }
                    .buttonStyle(.plain)
                    .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)

                    TextField("Option \(index + 1)", text: $question.options[index].text)
                        .textFieldStyle(.roundedBorder)
                        .font(.subheadline)

                    // Delete option (only if more than 2)
                    if question.options.count > 2 {
                        Button {
                            hapticTrigger.toggle()
                            withAnimation(.snappy) {
                                _ = question.options.remove(at: index)
                            }
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .font(.body)
                                .foregroundStyle(.red.opacity(0.7))
                        }
                        .buttonStyle(.plain)
                        .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
                    }
                }
            }

            if question.options.count < 6 {
                Button {
                    hapticTrigger.toggle()
                    withAnimation(.snappy) {
                        question.options.append(OptionDraft())
                    }
                } label: {
                    Label("Add Option", systemImage: "plus.circle")
                        .font(.subheadline)
                        .foregroundStyle(.indigo)
                }
                .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
            }

            Text("Tap the circle to mark the correct answer\(allowMultipleCorrect ? "s" : "")")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

    private func toggleCorrectOption(at index: Int) {
        if allowMultipleCorrect {
            question.options[index].isCorrect.toggle()
        } else {
            for i in question.options.indices {
                question.options[i].isCorrect = (i == index)
            }
        }
    }

    // MARK: - True / False

    private var trueFalseSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Correct Answer", systemImage: "checkmark.circle.fill")
                .font(.headline)
                .foregroundStyle(.indigo)

            ForEach(Array(question.options.enumerated()), id: \.element.id) { index, option in
                Button {
                    hapticTrigger.toggle()
                    for i in question.options.indices {
                        question.options[i].isCorrect = (i == index)
                    }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: question.options[index].isCorrect
                              ? "checkmark.circle.fill" : "circle")
                            .font(.title3)
                            .foregroundStyle(question.options[index].isCorrect ? .green : .secondary)

                        Text(option.text)
                            .font(.body)
                            .foregroundStyle(.primary)

                        Spacer()
                    }
                    .padding(12)
                    #if canImport(UIKit)
                    .background(
                        question.options[index].isCorrect
                            ? Color.green.opacity(0.08)
                            : Color(UIColor.systemBackground),
                        in: .rect(cornerRadius: 10)
                    )
                    #endif
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(
                                question.options[index].isCorrect
                                    ? Color.green.opacity(0.3)
                                    : Color.secondary.opacity(0.2),
                                lineWidth: 1
                            )
                    )
                }
                .buttonStyle(.plain)
                .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
            }
        }
        .padding(14)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

    // MARK: - Short Answer

    private var shortAnswerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Acceptable Answers", systemImage: "text.bubble.fill")
                .font(.headline)
                .foregroundStyle(.indigo)

            Text("Add all acceptable answers. Students must match one of these.")
                .font(.caption)
                .foregroundStyle(.secondary)

            ForEach(Array(question.correctAnswers.enumerated()), id: \.offset) { index, _ in
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.diamond.fill")
                        .font(.caption)
                        .foregroundStyle(.green)

                    TextField("Answer \(index + 1)", text: $question.correctAnswers[index])
                        .textFieldStyle(.roundedBorder)
                        .font(.subheadline)

                    if question.correctAnswers.count > 1 {
                        Button {
                            hapticTrigger.toggle()
                            withAnimation(.snappy) {
                                _ = question.correctAnswers.remove(at: index)
                            }
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .font(.body)
                                .foregroundStyle(.red.opacity(0.7))
                        }
                        .buttonStyle(.plain)
                        .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
                    }
                }
            }

            Button {
                hapticTrigger.toggle()
                withAnimation(.snappy) {
                    question.correctAnswers.append("")
                }
            } label: {
                Label("Add Acceptable Answer", systemImage: "plus.circle")
                    .font(.subheadline)
                    .foregroundStyle(.indigo)
            }
            .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)

            Divider()

            Toggle(isOn: $question.caseInsensitive) {
                Label("Case Insensitive", systemImage: "textformat.abc")
                    .font(.subheadline)
            }
            .tint(.indigo)

            Toggle(isOn: $question.allowPartialMatch) {
                Label("Allow Partial Match", systemImage: "text.magnifyingglass")
                    .font(.subheadline)
            }
            .tint(.indigo)
        }
        .padding(14)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

    // MARK: - Fill in the Blank

    private var fillInBlankSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Blank Answers", systemImage: "rectangle.and.pencil.and.ellipsis")
                .font(.headline)
                .foregroundStyle(.indigo)

            let blankCount = question.text.components(separatedBy: "___").count - 1
            if blankCount > 0 {
                Text("\(blankCount) blank\(blankCount == 1 ? "" : "s") detected in question text")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("Add ___ in your question text to create blanks")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            ForEach(Array(question.correctAnswers.enumerated()), id: \.offset) { index, _ in
                HStack(spacing: 10) {
                    Text("Blank \(index + 1)")
                        .font(.caption.bold())
                        .foregroundStyle(.indigo)
                        .frame(width: 60, alignment: .leading)

                    TextField("Answer for blank \(index + 1)", text: $question.correctAnswers[index])
                        .textFieldStyle(.roundedBorder)
                        .font(.subheadline)

                    if question.correctAnswers.count > 1 {
                        Button {
                            hapticTrigger.toggle()
                            withAnimation(.snappy) {
                                _ = question.correctAnswers.remove(at: index)
                            }
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .font(.body)
                                .foregroundStyle(.red.opacity(0.7))
                        }
                        .buttonStyle(.plain)
                        .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
                    }
                }
            }

            Button {
                hapticTrigger.toggle()
                withAnimation(.snappy) {
                    question.correctAnswers.append("")
                }
            } label: {
                Label("Add Blank Answer", systemImage: "plus.circle")
                    .font(.subheadline)
                    .foregroundStyle(.indigo)
            }
            .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)

            Divider()

            Toggle(isOn: $question.caseInsensitive) {
                Label("Case Insensitive", systemImage: "textformat.abc")
                    .font(.subheadline)
            }
            .tint(.indigo)
        }
        .padding(14)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

    // MARK: - Explanation

    private var explanationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Explanation (optional)", systemImage: "lightbulb.fill")
                .font(.headline)
                .foregroundStyle(.indigo)

            Text("Shown to students after they answer this question")
                .font(.caption)
                .foregroundStyle(.secondary)

            TextEditor(text: $question.explanation)
                .frame(minHeight: 60)
                .padding(8)
                #if canImport(UIKit)
                .background(Color(UIColor.systemBackground))
                #endif
                .clipShape(.rect(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                )
        }
        .padding(14)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

    // MARK: - Helpers

    private func resetOptionsForType(_ type: QuestionType) {
        switch type {
        case .multipleChoice:
            if question.options.count < 2 {
                question.options = [
                    OptionDraft(text: "", isCorrect: false),
                    OptionDraft(text: "", isCorrect: false),
                    OptionDraft(text: "", isCorrect: false),
                    OptionDraft(text: "", isCorrect: false)
                ]
            }
            question.correctAnswers = []
        case .trueFalse:
            question.options = [
                OptionDraft(text: "True", isCorrect: true),
                OptionDraft(text: "False", isCorrect: false)
            ]
            question.correctAnswers = []
        case .shortAnswer:
            question.options = []
            if question.correctAnswers.isEmpty {
                question.correctAnswers = [""]
            }
        case .fillInBlank:
            question.options = []
            if question.correctAnswers.isEmpty {
                question.correctAnswers = [""]
            }
        }
    }
}
