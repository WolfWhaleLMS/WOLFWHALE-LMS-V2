import SwiftUI

struct CreateLessonView: View {
    @Bindable var viewModel: AppViewModel
    let course: Course
    let module: Module

    @State private var lessonTitle = ""
    @State private var content = ""
    @State private var duration = 15
    @State private var lessonType: LessonType = .reading
    @State private var isLoading = false
    @State private var showSuccess = false
    @State private var errorMessage: String?
    @State private var hapticTrigger = false
    @State private var attachedResources: [SlideResource] = []
    @State private var showResourcePicker = false

    @Environment(\.dismiss) private var dismiss

    private var isValid: Bool {
        !lessonTitle.trimmingCharacters(in: .whitespaces).isEmpty &&
        !content.trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// Number of slides based on current content (counting `---` separators + 1).
    private var slideCount: Int {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return 1 }

        let bySeparator = trimmed.components(separatedBy: "\n---\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        if bySeparator.count > 1 { return bySeparator.count }

        let byLoose = trimmed.components(separatedBy: "---")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        if byLoose.count > 1 { return byLoose.count }

        return 1
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                moduleHeader
                lessonDetailsSection
                contentSection
                slideResourcesSection
                createButton
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Create Lesson")
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if showSuccess {
                successOverlay
            }
        }
        .sheet(isPresented: $showResourcePicker) {
            SlideResourcePickerSheet(
                slideCount: slideCount,
                attachedResources: $attachedResources
            )
        }
    }

    // MARK: - Module Header

    private var moduleHeader: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 12)
                .fill(Theme.courseColor(course.colorName).gradient)
                .frame(width: 44, height: 44)
                .overlay {
                    Image(systemName: "folder.fill")
                        .font(.title3)
                        .foregroundStyle(.white)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(module.title)
                    .font(.headline)
                Text(course.title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(14)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

    // MARK: - Lesson Details

    private var lessonDetailsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Lesson Details", systemImage: "doc.text.fill")
                .font(.headline)

            TextField("Lesson Title", text: $lessonTitle)
                .textFieldStyle(.roundedBorder)

            VStack(alignment: .leading, spacing: 4) {
                Text("Type")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    lessonTypeButton(.reading)
                    lessonTypeButton(.video)
                    lessonTypeButton(.activity)
                    lessonTypeButton(.quiz)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Duration")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Stepper("\(duration) min", value: $duration, in: 5...120, step: 5)
                    .font(.subheadline)
            }
        }
        .padding(14)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

    private func lessonTypeButton(_ type: LessonType) -> some View {
        let isSelected = lessonType == type
        let color: Color = .orange
        return Button {
            hapticTrigger.toggle()
            withAnimation(.snappy(duration: 0.2)) {
                lessonType = type
            }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: type.iconName)
                    .font(.callout)
                Text(type.rawValue)
                    .font(.system(size: 9, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                isSelected ? color.opacity(0.2) : Color(.tertiarySystemFill),
                in: .rect(cornerRadius: 10)
            )
            .foregroundStyle(isSelected ? color : .secondary)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? color.opacity(0.5) : .clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
    }

    // MARK: - Content Section

    private var contentSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Content", systemImage: "text.alignleft")
                .font(.headline)

            TextField("Write the lesson content here...", text: $content, axis: .vertical)
                .lineLimit(8...)
                .textFieldStyle(.roundedBorder)

            HStack(spacing: 6) {
                Image(systemName: "rectangle.split.3x1.fill")
                    .font(.caption2)
                    .foregroundStyle(.indigo)
                Text("Use **---** on a new line to create slide breaks. Students will click through each slide.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(10)
            .background(.indigo.opacity(0.08), in: .rect(cornerRadius: 10))
        }
        .padding(14)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

    // MARK: - Slide Resources Section

    private var slideResourcesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Slide Resources", systemImage: "book.and.wrench.fill")
                .font(.headline)

            if attachedResources.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "info.circle")
                        .font(.caption)
                        .foregroundStyle(.purple)
                    Text("Attach tools from the Resource Library to individual slides. Students will see them while viewing the lesson.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(10)
                .background(.purple.opacity(0.08), in: .rect(cornerRadius: 10))
            } else {
                ForEach(attachedResources) { resource in
                    HStack(spacing: 10) {
                        Image(systemName: resource.resourceIcon)
                            .font(.callout)
                            .foregroundStyle(.purple)
                            .frame(width: 28, height: 28)
                            .background(.purple.opacity(0.15), in: .rect(cornerRadius: 6))

                        VStack(alignment: .leading, spacing: 2) {
                            Text(resource.resourceTitle)
                                .font(.subheadline.bold())
                            Text("Slide \(resource.slideIndex + 1)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Button {
                            withAnimation(.snappy(duration: 0.2)) {
                                attachedResources.removeAll { $0.id == resource.id }
                            }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.body)
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Remove resource")
                    }
                    .padding(10)
                    .background(Color(.tertiarySystemFill), in: .rect(cornerRadius: 10))
                }
            }

            Button {
                hapticTrigger.toggle()
                showResourcePicker = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill")
                    Text("Attach Resource")
                        .fontWeight(.medium)
                }
                .font(.subheadline)
                .frame(maxWidth: .infinity)
                .frame(height: 40)
            }
            .buttonStyle(.bordered)
            .tint(.purple)
            .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
        }
        .padding(14)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
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
                hapticTrigger.toggle()
                createLesson()
            } label: {
                Group {
                    if isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Label("Create Lesson", systemImage: "checkmark.circle.fill")
                            .fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            .disabled(isLoading || !isValid)
            .sensoryFeedback(.impact(weight: .medium), trigger: hapticTrigger)
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
                Text("Lesson Created")
                    .font(.title3.bold())
                Text("\(lessonTitle) added to \(module.title)")
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

    private func createLesson() {
        isLoading = true
        errorMessage = nil

        let trimmedTitle = lessonTitle.trimmingCharacters(in: .whitespaces)
        let trimmedContent = content.trimmingCharacters(in: .whitespaces)

        Task {
            do {
                try await viewModel.createLesson(
                    courseId: course.id,
                    moduleId: module.id,
                    title: trimmedTitle,
                    content: trimmedContent,
                    duration: duration,
                    type: lessonType,
                    xpReward: 0,
                    slideResources: attachedResources
                )
                isLoading = false
                withAnimation(.snappy) {
                    showSuccess = true
                }
                try? await Task.sleep(for: .seconds(2))
                withAnimation { showSuccess = false }
                dismiss()
            } catch {
                errorMessage = "Failed to create lesson. Please try again."
                isLoading = false
            }
        }
    }
}

// MARK: - Slide Resource Picker Sheet

struct SlideResourcePickerSheet: View {
    let slideCount: Int
    @Binding var attachedResources: [SlideResource]

    @State private var selectedSlideIndex = 0
    @State private var hapticTrigger = false
    @Environment(\.dismiss) private var dismiss

    /// Categories in display order.
    private var categories: [String] {
        var seen = Set<String>()
        var result: [String] = []
        for resource in AttachableResource.allCases {
            if seen.insert(resource.category).inserted {
                result.append(resource.category)
            }
        }
        return result
    }

    private func resources(for category: String) -> [AttachableResource] {
        AttachableResource.allCases.filter { $0.category == category }
    }

    var body: some View {
        NavigationStack {
            List {
                slidePickerSection
                ForEach(categories, id: \.self) { category in
                    Section(category) {
                        ForEach(resources(for: category)) { resource in
                            resourceRow(resource)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Attach Resource")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private var slidePickerSection: some View {
        Section {
            Picker("Slide", selection: $selectedSlideIndex) {
                ForEach(0..<slideCount, id: \.self) { index in
                    Text("Slide \(index + 1)").tag(index)
                }
            }
            .pickerStyle(.menu)
        } header: {
            Text("Select Slide")
        } footer: {
            Text("The resource will appear on this slide for students.")
        }
    }

    private func isAlreadyAttached(_ resource: AttachableResource) -> Bool {
        attachedResources.contains {
            $0.slideIndex == selectedSlideIndex && $0.resourceTitle == resource.rawValue
        }
    }

    @ViewBuilder
    private func resourceRow(_ resource: AttachableResource) -> some View {
        let attached = isAlreadyAttached(resource)
        Button {
            guard !attached else { return }
            hapticTrigger.toggle()
            let newResource = SlideResource(
                slideIndex: selectedSlideIndex,
                resourceTitle: resource.rawValue,
                resourceIcon: resource.iconName,
                colorName: "purple"
            )
            withAnimation(.snappy(duration: 0.2)) {
                attachedResources.append(newResource)
            }
            dismiss()
        } label: {
            resourceRowLabel(resource, attached: attached)
        }
        .disabled(attached)
        .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
    }

    private func resourceRowLabel(_ resource: AttachableResource, attached: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: resource.iconName)
                .font(.title3)
                .foregroundStyle(attached ? Color.secondary : Color.purple)
                .frame(width: 32, height: 32)

            Text(resource.rawValue)
                .font(.body)
                .foregroundStyle(attached ? .secondary : .primary)

            Spacer()

            if attached {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else {
                Image(systemName: "plus.circle")
                    .foregroundStyle(.purple)
            }
        }
    }
}
