import SwiftUI

struct EditCourseView: View {
    let course: Course
    @Bindable var viewModel: AppViewModel

    @State private var title: String
    @State private var description: String
    @State private var selectedColor: String
    @State private var selectedIcon: String
    @State private var isLoading = false
    @State private var showSuccess = false
    @State private var showDeleteConfirmation = false
    @State private var isDeleting = false
    @State private var errorMessage: String?
    @State private var hapticTrigger = false

    @Environment(\.dismiss) private var dismiss

    private static let colorOptions = [
        "blue", "purple", "orange", "green", "pink",
        "red", "indigo", "teal", "mint", "cyan"
    ]

    private static let iconOptions = [
        "book.fill", "laptopcomputer", "paintbrush.fill", "function",
        "globe.americas.fill", "music.note", "atom", "heart.fill",
        "star.fill", "bolt.fill"
    ]

    init(course: Course, viewModel: AppViewModel) {
        self.course = course
        self.viewModel = viewModel
        _title = State(initialValue: course.title)
        _description = State(initialValue: course.description)
        _selectedColor = State(initialValue: course.colorName)
        _selectedIcon = State(initialValue: course.iconSystemName)
    }

    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var hasChanges: Bool {
        title != course.title ||
        description != course.description ||
        selectedColor != course.colorName ||
        selectedIcon != course.iconSystemName
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                coursePreview
                titleSection
                colorSection
                iconSection
                saveButton
                deleteSection
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Edit Course")
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
        .alert("Delete Course", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                deleteCourse()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to delete \"\(course.title)\"? This action cannot be undone. All modules, lessons, and assignments will be permanently removed.")
        }
        .overlay {
            if showSuccess {
                successOverlay
            }
        }
        .allowsHitTesting(!isDeleting)
    }

    // MARK: - Course Preview

    private var coursePreview: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Preview")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 14) {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Theme.courseColor(selectedColor).gradient)
                    .frame(width: 56, height: 56)
                    .overlay {
                        Image(systemName: selectedIcon)
                            .font(.title2)
                            .foregroundStyle(.white)
                    }

                VStack(alignment: .leading, spacing: 4) {
                    Text(title.isEmpty ? "Course Title" : title)
                        .font(.headline)
                        .foregroundStyle(title.isEmpty ? .secondary : .primary)
                    HStack(spacing: 8) {
                        Label("Code: \(course.classCode)", systemImage: "number")
                        Label("\(course.enrolledStudentCount) students", systemImage: "person.3.fill")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(14)
            .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
        }
    }

    // MARK: - Title & Description

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Course Details", systemImage: "pencil.line")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                Text("Title")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("Course Title", text: $title)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Description")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("Course description...", text: $description, axis: .vertical)
                    .lineLimit(3...)
                    .textFieldStyle(.roundedBorder)
            }
        }
        .padding(14)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

    // MARK: - Color Picker

    private var colorSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Course Color", systemImage: "paintpalette.fill")
                .font(.headline)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 5), spacing: 10) {
                ForEach(Self.colorOptions, id: \.self) { colorName in
                    let color = Theme.courseColor(colorName)
                    let isSelected = selectedColor == colorName

                    Button {
                        hapticTrigger.toggle()
                        withAnimation(.snappy(duration: 0.2)) {
                            selectedColor = colorName
                        }
                    } label: {
                        Circle()
                            .fill(color.gradient)
                            .frame(width: 44, height: 44)
                            .overlay {
                                if isSelected {
                                    Image(systemName: "checkmark")
                                        .font(.callout.bold())
                                        .foregroundStyle(.white)
                                }
                            }
                            .overlay {
                                Circle()
                                    .stroke(isSelected ? color : .clear, lineWidth: 3)
                                    .padding(-4)
                            }
                    }
                    .buttonStyle(.plain)
                    .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
                }
            }
        }
        .padding(14)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

    // MARK: - Icon Picker

    private var iconSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Course Icon", systemImage: "square.grid.2x2.fill")
                .font(.headline)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 5), spacing: 10) {
                ForEach(Self.iconOptions, id: \.self) { iconName in
                    let isSelected = selectedIcon == iconName

                    Button {
                        hapticTrigger.toggle()
                        withAnimation(.snappy(duration: 0.2)) {
                            selectedIcon = iconName
                        }
                    } label: {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(isSelected ? Theme.courseColor(selectedColor).opacity(0.2) : Color(.tertiarySystemFill))
                            .frame(width: 52, height: 52)
                            .overlay {
                                Image(systemName: iconName)
                                    .font(.title3)
                                    .foregroundStyle(isSelected ? Theme.courseColor(selectedColor) : .secondary)
                            }
                            .overlay {
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(isSelected ? Theme.courseColor(selectedColor).opacity(0.5) : .clear, lineWidth: 1.5)
                            }
                    }
                    .buttonStyle(.plain)
                    .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
                }
            }
        }
        .padding(14)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

    // MARK: - Save Button

    private var saveButton: some View {
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
                saveCourse()
            } label: {
                Group {
                    if isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Label("Save Changes", systemImage: "checkmark.circle.fill")
                            .fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
            }
            .buttonStyle(.borderedProminent)
            .tint(.pink)
            .disabled(isLoading || !isValid || !hasChanges)
            .sensoryFeedback(.impact(weight: .medium), trigger: hapticTrigger)
        }
        .padding(.top, 4)
    }

    // MARK: - Delete Section

    private var deleteSection: some View {
        VStack(spacing: 8) {
            Divider()
                .padding(.vertical, 4)

            Button {
                hapticTrigger.toggle()
                showDeleteConfirmation = true
            } label: {
                Group {
                    if isDeleting {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Label("Delete Course", systemImage: "trash.fill")
                            .fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .disabled(isDeleting)
            .sensoryFeedback(.impact(weight: .heavy), trigger: hapticTrigger)

            Text("This will permanently delete the course and all its content.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
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
                Text("Course Updated")
                    .font(.title3.bold())
                Text("\(title) has been saved")
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

    private func saveCourse() {
        isLoading = true
        errorMessage = nil

        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
        let trimmedDescription = description.trimmingCharacters(in: .whitespaces)

        Task {
            do {
                if !viewModel.isDemoMode {
                    try await DataService.shared.updateCourse(
                        courseId: course.id,
                        title: trimmedTitle,
                        description: trimmedDescription
                    )
                }

                // Update local state
                if let index = viewModel.courses.firstIndex(where: { $0.id == course.id }) {
                    viewModel.courses[index].title = trimmedTitle
                    viewModel.courses[index].description = trimmedDescription
                    viewModel.courses[index].colorName = selectedColor
                    viewModel.courses[index].iconSystemName = selectedIcon
                }

                isLoading = false
                withAnimation(.snappy) {
                    showSuccess = true
                }
                try? await Task.sleep(for: .seconds(2))
                withAnimation { showSuccess = false }
                dismiss()
            } catch {
                errorMessage = "Failed to update course. Please try again."
                isLoading = false
            }
        }
    }

    private func deleteCourse() {
        isDeleting = true
        errorMessage = nil

        Task {
            do {
                if !viewModel.isDemoMode {
                    try await DataService.shared.deleteCourse(courseId: course.id)
                }
                viewModel.courses.removeAll { $0.id == course.id }
                isDeleting = false
                dismiss()
            } catch {
                errorMessage = "Failed to delete course. Please try again."
                isDeleting = false
            }
        }
    }
}
