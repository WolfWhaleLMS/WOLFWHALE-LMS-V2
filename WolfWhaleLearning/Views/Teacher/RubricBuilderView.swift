import SwiftUI

struct RubricBuilderView: View {
    @Bindable var viewModel: AppViewModel
    let courseId: UUID

    /// When editing an existing rubric, pass it in; otherwise starts blank.
    var existingRubric: Rubric?

    /// Called after a rubric is successfully created / saved.
    var onSave: ((Rubric) -> Void)?

    @State private var title = ""
    @State private var criteria: [DraftCriterion] = [DraftCriterion()]
    @State private var isLoading = false
    @State private var showSuccess = false
    @State private var errorMessage: String?
    @State private var hapticTrigger = false

    @Environment(\.dismiss) private var dismiss

    // MARK: - Draft Types

    struct DraftLevel: Identifiable {
        let id = UUID()
        var label: String = ""
        var description: String = ""
        var points: Int = 0
    }

    struct DraftCriterion: Identifiable {
        let id = UUID()
        var name: String = ""
        var description: String = ""
        var maxPoints: Int = 10
        var levels: [DraftLevel] = [
            DraftLevel(label: "Excellent", description: "", points: 10),
            DraftLevel(label: "Good", description: "", points: 7),
            DraftLevel(label: "Needs Work", description: "", points: 3)
        ]
    }

    // MARK: - Validation

    private var isValid: Bool {
        let titleOK = !title.trimmingCharacters(in: .whitespaces).isEmpty
        let criteriaOK = !criteria.isEmpty && criteria.allSatisfy { c in
            !c.name.trimmingCharacters(in: .whitespaces).isEmpty && c.maxPoints > 0
        }
        return titleOK && criteriaOK
    }

    // MARK: - Init

    init(viewModel: AppViewModel, courseId: UUID, existingRubric: Rubric? = nil, onSave: ((Rubric) -> Void)? = nil) {
        self.viewModel = viewModel
        self.courseId = courseId
        self.existingRubric = existingRubric
        self.onSave = onSave

        if let rubric = existingRubric {
            _title = State(initialValue: rubric.title)
            _criteria = State(initialValue: rubric.criteria.map { c in
                DraftCriterion(
                    name: c.name,
                    description: c.description,
                    maxPoints: c.maxPoints,
                    levels: c.levels.map { l in
                        DraftLevel(label: l.label, description: l.description, points: l.points)
                    }
                )
            })
        }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    rubricTitleSection
                    criteriaListSection
                    addCriterionButton
                    totalPointsCard
                    saveButton
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(existingRubric != nil ? "Edit Rubric" : "Create Rubric")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .overlay {
                if showSuccess {
                    successOverlay
                }
            }
        }
    }

    // MARK: - Title Section

    private var rubricTitleSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Rubric Title", systemImage: "text.badge.checkmark")
                .font(.headline)

            TextField("e.g. Essay Rubric", text: $title)
                .textFieldStyle(.roundedBorder)
        }
        .padding(14)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

    // MARK: - Criteria List

    private var criteriaListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Criteria", systemImage: "list.bullet.rectangle.portrait")
                    .font(.headline)
                Spacer()
                Text("\(criteria.count) criterion\(criteria.count == 1 ? "" : " rows")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ForEach(criteria.indices, id: \.self) { index in
                criterionCard(index: index)
            }
        }
    }

    // MARK: - Single Criterion Card

    private func criterionCard(index: Int) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header row
            HStack {
                Text("Criterion \(index + 1)")
                    .font(.subheadline.bold())
                    .foregroundStyle(.pink)
                Spacer()
                if criteria.count > 1 {
                    Button {
                        hapticTrigger.toggle()
                        withAnimation(.snappy) {
                            _ = criteria.remove(at: index)
                        }
                    } label: {
                        Image(systemName: "trash")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                    .sensoryFeedback(.impact(weight: .heavy), trigger: hapticTrigger)
                }
            }

            // Name
            TextField("Criterion name (e.g. Thesis Clarity)", text: $criteria[index].name)
                .textFieldStyle(.roundedBorder)

            // Description
            TextField("Description (optional)", text: $criteria[index].description, axis: .vertical)
                .lineLimit(2...)
                .textFieldStyle(.roundedBorder)

            // Max points
            HStack {
                Text("Max Points")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Stepper("\(criteria[index].maxPoints) pts", value: $criteria[index].maxPoints, in: 1...100)
                    .font(.subheadline)
            }

            // Levels
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Performance Levels")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button {
                        hapticTrigger.toggle()
                        withAnimation(.snappy) {
                            criteria[index].levels.append(DraftLevel())
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.pink)
                    }
                    .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
                }

                ForEach(criteria[index].levels.indices, id: \.self) { levelIdx in
                    levelRow(criterionIndex: index, levelIndex: levelIdx)
                }
            }
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 12))
    }

    // MARK: - Level Row

    private func levelRow(criterionIndex: Int, levelIndex: Int) -> some View {
        HStack(spacing: 8) {
            // Points badge
            VStack(spacing: 2) {
                Text("\(criteria[criterionIndex].levels[levelIndex].points)")
                    .font(.caption.bold())
                    .foregroundStyle(.pink)
                Text("pts")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 36)

            VStack(alignment: .leading, spacing: 4) {
                TextField("Level label", text: $criteria[criterionIndex].levels[levelIndex].label)
                    .font(.subheadline)
                    .textFieldStyle(.roundedBorder)

                TextField("Level description", text: $criteria[criterionIndex].levels[levelIndex].description)
                    .font(.caption)
                    .textFieldStyle(.roundedBorder)
            }

            // Points stepper (compact)
            Stepper("", value: $criteria[criterionIndex].levels[levelIndex].points, in: 0...criteria[criterionIndex].maxPoints)
                .labelsHidden()
                .frame(width: 80)

            // Delete level
            if criteria[criterionIndex].levels.count > 1 {
                Button {
                    hapticTrigger.toggle()
                    withAnimation(.snappy) {
                        _ = criteria[criterionIndex].levels.remove(at: levelIndex)
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
            }
        }
        .padding(8)
        .background(Color(.tertiarySystemFill), in: .rect(cornerRadius: 8))
    }

    // MARK: - Add Criterion

    private var addCriterionButton: some View {
        Button {
            hapticTrigger.toggle()
            withAnimation(.snappy) {
                criteria.append(DraftCriterion())
            }
        } label: {
            Label("Add Criterion", systemImage: "plus.circle.fill")
                .font(.subheadline.bold())
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
        }
        .buttonStyle(.bordered)
        .tint(.pink)
        .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
    }

    // MARK: - Total Points Card

    private var totalPointsCard: some View {
        HStack {
            Label("Total Rubric Points", systemImage: "sum")
                .font(.subheadline)
                .foregroundStyle(Color(.label))
            Spacer()
            Text("\(criteria.reduce(0) { $0 + $1.maxPoints })")
                .font(.title3.bold())
                .foregroundStyle(.pink)
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 12))
    }

    // MARK: - Save Button

    private var saveButton: some View {
        VStack(spacing: 8) {
            Button {
                hapticTrigger.toggle()
                saveRubric()
            } label: {
                Group {
                    if isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Label(existingRubric != nil ? "Update Rubric" : "Create Rubric",
                              systemImage: "checkmark.circle.fill")
                            .fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
            }
            .buttonStyle(.borderedProminent)
            .tint(.pink)
            .disabled(isLoading || !isValid)
            .sensoryFeedback(.impact(weight: .medium), trigger: hapticTrigger)
            .padding(.top, 4)

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

    // MARK: - Success Overlay

    private var successOverlay: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.green)
                Text("Rubric Saved")
                    .font(.title3.bold())
                Text(title)
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

    // MARK: - Save Logic

    private func saveRubric() {
        isLoading = true
        errorMessage = nil

        let builtCriteria: [RubricCriterion] = criteria.map { draft in
            RubricCriterion(
                id: UUID(),
                name: draft.name.trimmingCharacters(in: .whitespaces),
                description: draft.description.trimmingCharacters(in: .whitespaces),
                maxPoints: draft.maxPoints,
                levels: draft.levels.map { lvl in
                    RubricLevel(
                        id: UUID(),
                        label: lvl.label.trimmingCharacters(in: .whitespaces),
                        description: lvl.description.trimmingCharacters(in: .whitespaces),
                        points: lvl.points
                    )
                }
            )
        }

        Task {
            do {
                try await viewModel.createRubric(
                    title: title,
                    courseId: courseId,
                    criteria: builtCriteria
                )
                isLoading = false

                // Notify caller with the newly created rubric
                if let created = viewModel.rubrics.last {
                    onSave?(created)
                }

                withAnimation(.snappy) {
                    showSuccess = true
                }
                try? await Task.sleep(for: .seconds(2))
                withAnimation { showSuccess = false }
                dismiss()
            } catch {
                errorMessage = "Failed to save rubric: \(error.localizedDescription)"
                isLoading = false
            }
        }
    }
}
