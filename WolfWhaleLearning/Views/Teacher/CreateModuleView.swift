import SwiftUI

struct CreateModuleView: View {
    @Bindable var viewModel: AppViewModel
    let course: Course

    @State private var moduleTitle = ""
    @State private var isLoading = false
    @State private var showSuccess = false
    @State private var errorMessage: String?
    @State private var hapticTrigger = false

    @Environment(\.dismiss) private var dismiss

    private var isValid: Bool {
        !moduleTitle.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                courseHeader
                moduleFormSection
                createButton
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Create Module")
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if showSuccess {
                successOverlay
            }
        }
    }

    // MARK: - Course Header

    private var courseHeader: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 12)
                .fill(Theme.courseColor(course.colorName).gradient)
                .frame(width: 44, height: 44)
                .overlay {
                    Image(systemName: course.iconSystemName)
                        .font(.title3)
                        .foregroundStyle(.white)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(course.title)
                    .font(.headline)
                Text("\(course.modules.count) module\(course.modules.count == 1 ? "" : "s") currently")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(14)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

    // MARK: - Module Form

    private var moduleFormSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Module Details", systemImage: "folder.fill.badge.plus")
                .font(.headline)

            TextField("Module Title", text: $moduleTitle)
                .textFieldStyle(.roundedBorder)

            Text("Modules organize your course content into sections. After creating a module, you can add lessons and quizzes to it.")
                .font(.caption)
                .foregroundStyle(.secondary)
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
                createModule()
            } label: {
                Group {
                    if isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Label("Create Module", systemImage: "checkmark.circle.fill")
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
                Text("Module Created")
                    .font(.title3.bold())
                Text("\(moduleTitle) added to \(course.title)")
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

    private func createModule() {
        isLoading = true
        errorMessage = nil

        let trimmedTitle = moduleTitle.trimmingCharacters(in: .whitespaces)

        Task {
            do {
                try await viewModel.createModule(
                    courseId: course.id,
                    title: trimmedTitle
                )
                isLoading = false
                withAnimation(.snappy) {
                    showSuccess = true
                }
                try? await Task.sleep(for: .seconds(2))
                withAnimation { showSuccess = false }
                dismiss()
            } catch {
                errorMessage = "Failed to create module. Please try again."
                isLoading = false
            }
        }
    }
}
