import SwiftUI

struct AssignmentTemplatesView: View {
    @Bindable var viewModel: AppViewModel
    let courseId: UUID

    @State private var templates: [AssignmentTemplate] = []
    @State private var selectedTemplate: AssignmentTemplate?
    @State private var showUseTemplateSheet = false
    @State private var dueDate = Date().addingTimeInterval(7 * 86400)
    @State private var isCreating = false
    @State private var showSuccess = false
    @State private var showDeleteConfirmation = false
    @State private var templateToDelete: AssignmentTemplate?
    @State private var hapticTrigger = false

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                headerSection
                templateListSection
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Assignment Templates")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { reloadTemplates() }
        .sheet(isPresented: $showUseTemplateSheet) {
            useTemplateSheet
        }
        .alert("Delete Template", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                if let template = templateToDelete {
                    deleteTemplate(template)
                }
            }
            Button("Cancel", role: .cancel) {
                templateToDelete = nil
            }
        } message: {
            Text("Are you sure you want to delete this template? This cannot be undone.")
        }
        .overlay {
            if showSuccess {
                successOverlay
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 12)
                .fill(.purple.gradient)
                .frame(width: 44, height: 44)
                .overlay {
                    Image(systemName: "doc.on.doc.fill")
                        .font(.title3)
                        .foregroundStyle(.white)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text("Templates")
                    .font(.headline)
                    .foregroundStyle(Color(.label))
                Text("\(templates.count) saved template\(templates.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Templates, \(templates.count) saved")
    }

    // MARK: - Template List

    private var templateListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if templates.isEmpty {
                emptyState
            } else {
                ForEach(templates) { template in
                    templateCard(template)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.on.doc")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("No Templates Yet")
                .font(.subheadline.bold())
                .foregroundStyle(Color(.label))
            Text("Save assignments as templates to reuse them across courses. Use the \"Save as Template\" option when editing an assignment.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .padding(.horizontal, 20)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("No templates saved yet")
    }

    private func templateCard(_ template: AssignmentTemplate) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack(spacing: 10) {
                Image(systemName: "doc.text.fill")
                    .font(.title3)
                    .foregroundStyle(.purple)

                VStack(alignment: .leading, spacing: 2) {
                    Text(template.name)
                        .font(.subheadline.bold())
                        .foregroundStyle(Color(.label))
                    if let courseName = template.courseName {
                        Text("From: \(courseName)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()

                Text("\(template.points) pts")
                    .font(.caption.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.purple.opacity(0.15), in: Capsule())
                    .foregroundStyle(.purple)
            }

            // Details
            VStack(alignment: .leading, spacing: 4) {
                Text(template.title)
                    .font(.caption)
                    .foregroundStyle(Color(.label))
                    .lineLimit(1)

                if !template.instructions.isEmpty {
                    Text(template.instructions)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            // Info badges
            HStack(spacing: 8) {
                Label("Created \(template.createdDate.formatted(.dateTime.month(.abbreviated).day()))", systemImage: "calendar")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                if template.rubricId != nil {
                    Label("Rubric", systemImage: "list.bullet.rectangle.portrait")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                if template.peerReviewEnabled {
                    Label("Peer Review", systemImage: "person.2.fill")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            // Action buttons
            HStack(spacing: 12) {
                Button {
                    hapticTrigger.toggle()
                    selectedTemplate = template
                    showUseTemplateSheet = true
                } label: {
                    Label("Use Template", systemImage: "plus.circle.fill")
                        .font(.caption.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .tint(.purple)
                .hapticFeedback(.impact(weight: .medium), trigger: hapticTrigger)
                .accessibilityLabel("Use template \(template.name)")
                .accessibilityHint("Creates a new assignment from this template")

                Button {
                    hapticTrigger.toggle()
                    templateToDelete = template
                    showDeleteConfirmation = true
                } label: {
                    Image(systemName: "trash")
                        .font(.caption)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                }
                .buttonStyle(.bordered)
                .tint(.red)
                .hapticFeedback(.impact(weight: .heavy), trigger: hapticTrigger)
                .accessibilityLabel("Delete template \(template.name)")
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(template.name), \(template.points) points, from \(template.courseName ?? "unknown course")")
    }

    // MARK: - Use Template Sheet

    private var useTemplateSheet: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if let template = selectedTemplate {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Creating from Template", systemImage: "doc.on.doc.fill")
                            .font(.headline)
                            .foregroundStyle(Color(.label))

                        VStack(alignment: .leading, spacing: 4) {
                            Text(template.title)
                                .font(.subheadline.bold())
                                .foregroundStyle(Color(.label))
                            Text("\(template.points) points")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(.horizontal)

                    VStack(alignment: .leading, spacing: 10) {
                        Label("Set Due Date", systemImage: "calendar")
                            .font(.headline)
                            .foregroundStyle(Color(.label))

                        DatePicker(
                            "Due Date",
                            selection: $dueDate,
                            in: Date()...,
                            displayedComponents: [.date, .hourAndMinute]
                        )
                        .datePickerStyle(.graphical)
                        .tint(.purple)
                    }
                    .padding(.horizontal)
                }

                Spacer()
            }
            .padding(.top, 16)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Use Template")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        hapticTrigger.toggle()
                        showUseTemplateSheet = false
                    }
                    .hapticFeedback(.impact(weight: .light), trigger: hapticTrigger)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        hapticTrigger.toggle()
                        createFromTemplate()
                    }
                    .fontWeight(.semibold)
                    .disabled(isCreating)
                    .hapticFeedback(.impact(weight: .medium), trigger: hapticTrigger)
                }
            }
            .overlay {
                if isCreating {
                    ZStack {
                        Color.black.opacity(0.3).ignoresSafeArea()
                        ProgressView("Creating assignment...")
                            .padding(24)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                    }
                }
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
                Text("Assignment Created")
                    .font(.title3.bold())
                    .foregroundStyle(Color(.label))
                Text("From template: \(selectedTemplate?.name ?? "")")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(32)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
        }
        .transition(.opacity)
        .onTapGesture {
            withAnimation { showSuccess = false }
        }
    }

    // MARK: - Actions

    private func reloadTemplates() {
        templates = AssignmentTemplateStore.loadTemplates()
    }

    private func createFromTemplate() {
        guard let template = selectedTemplate else { return }
        isCreating = true

        Task {
            do {
                try await viewModel.createAssignmentFromTemplate(template, courseId: courseId, dueDate: dueDate)
                isCreating = false
                showUseTemplateSheet = false
                withAnimation(.snappy) { showSuccess = true }
                try? await Task.sleep(for: .seconds(2))
                withAnimation { showSuccess = false }
            } catch {
                viewModel.dataError = "Failed to create assignment from template."
                isCreating = false
            }
        }
    }

    private func deleteTemplate(_ template: AssignmentTemplate) {
        withAnimation(.snappy) {
            viewModel.deleteAssignmentTemplate(id: template.id)
            reloadTemplates()
        }
        templateToDelete = nil
    }
}
