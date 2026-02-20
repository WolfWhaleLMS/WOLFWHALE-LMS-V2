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

    @Environment(\.dismiss) private var dismiss

    private var isValid: Bool {
        !lessonTitle.trimmingCharacters(in: .whitespaces).isEmpty &&
        !content.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                moduleHeader
                lessonDetailsSection
                contentSection
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
        let color: Color = .pink
        return Button {
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
    }

    // MARK: - Content Section

    private var contentSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Content", systemImage: "text.alignleft")
                .font(.headline)

            TextField("Write the lesson content here...", text: $content, axis: .vertical)
                .lineLimit(8...)
                .textFieldStyle(.roundedBorder)
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
                    xpReward: 0
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
