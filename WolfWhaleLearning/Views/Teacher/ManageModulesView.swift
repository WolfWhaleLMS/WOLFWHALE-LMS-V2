import SwiftUI
import Supabase

struct ManageModulesView: View {
    let course: Course
    @Bindable var viewModel: AppViewModel

    @State private var expandedModuleId: UUID?
    @State private var editingModuleId: UUID?
    @State private var editingModuleTitle = ""
    @State private var editingLessonId: UUID?
    @State private var editingLessonTitle = ""
    @State private var showAddModule = false
    @State private var newModuleTitle = ""
    @State private var isLoading = false
    @State private var showSuccess = false
    @State private var successMessage = ""
    @State private var errorMessage: String?
    @State private var deleteModuleTarget: Module?
    @State private var deleteLessonTarget: (moduleId: UUID, lessonId: UUID)?
    @State private var hapticTrigger = false

    @Environment(\.dismiss) private var dismiss

    private var currentCourse: Course {
        viewModel.courses.first(where: { $0.id == course.id }) ?? course
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                courseHeader
                modulesListSection
                addModuleSection
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Manage Modules")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Delete Module", isPresented: Binding(
            get: { deleteModuleTarget != nil },
            set: { if !$0 { deleteModuleTarget = nil } }
        )) {
            Button("Delete", role: .destructive) {
                if let target = deleteModuleTarget {
                    deleteModule(target)
                }
            }
            Button("Cancel", role: .cancel) {
                deleteModuleTarget = nil
            }
        } message: {
            if let target = deleteModuleTarget {
                Text("Are you sure you want to delete \"\(target.title)\"? All lessons in this module will also be deleted.")
            }
        }
        .alert("Delete Lesson", isPresented: Binding(
            get: { deleteLessonTarget != nil },
            set: { if !$0 { deleteLessonTarget = nil } }
        )) {
            Button("Delete", role: .destructive) {
                if let target = deleteLessonTarget {
                    deleteLesson(moduleId: target.moduleId, lessonId: target.lessonId)
                }
            }
            Button("Cancel", role: .cancel) {
                deleteLessonTarget = nil
            }
        } message: {
            Text("Are you sure you want to delete this lesson? This action cannot be undone.")
        }
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
                .fill(Theme.courseColor(currentCourse.colorName).gradient)
                .frame(width: 44, height: 44)
                .overlay {
                    Image(systemName: currentCourse.iconSystemName)
                        .font(.title3)
                        .foregroundStyle(.white)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(currentCourse.title)
                    .font(.headline)
                Text("\(currentCourse.modules.count) module\(currentCourse.modules.count == 1 ? "" : "s") \u{2022} \(currentCourse.totalLessons) lesson\(currentCourse.totalLessons == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(14)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

    // MARK: - Modules List

    private var modulesListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Modules")
                    .font(.headline)
                Spacer()
                Text("\(currentCourse.modules.count) total")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if currentCourse.modules.isEmpty {
                emptyModulesState
            } else {
                ForEach(currentCourse.modules.sorted(by: { $0.orderIndex < $1.orderIndex })) { module in
                    moduleCard(module)
                }
            }
        }
    }

    private var emptyModulesState: some View {
        VStack(spacing: 12) {
            Image(systemName: "folder.badge.plus")
                .font(.system(size: 32))
                .foregroundStyle(.secondary)
            Text("No modules yet")
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)
            Text("Add your first module to start organizing course content.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

    private func moduleCard(_ module: Module) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Module header row
            HStack(spacing: 10) {
                Image(systemName: "folder.fill")
                    .foregroundStyle(Theme.courseColor(currentCourse.colorName))

                if editingModuleId == module.id {
                    TextField("Module title", text: $editingModuleTitle)
                        .textFieldStyle(.roundedBorder)
                        .font(.subheadline)
                        .onSubmit {
                            saveModuleTitle(module)
                        }

                    Button {
                        hapticTrigger.toggle()
                        saveModuleTitle(module)
                    } label: {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                    .sensoryFeedback(.impact(weight: .medium), trigger: hapticTrigger)

                    Button {
                        hapticTrigger.toggle()
                        editingModuleId = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
                } else {
                    Text(module.title)
                        .font(.subheadline.bold())

                    Spacer()

                    Text("\(module.lessons.count) lesson\(module.lessons.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    // Expand/collapse
                    Button {
                        hapticTrigger.toggle()
                        withAnimation(.snappy(duration: 0.25)) {
                            expandedModuleId = expandedModuleId == module.id ? nil : module.id
                        }
                    } label: {
                        Image(systemName: expandedModuleId == module.id ? "chevron.up" : "chevron.down")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)

                    // Edit button
                    Button {
                        hapticTrigger.toggle()
                        editingModuleTitle = module.title
                        editingModuleId = module.id
                    } label: {
                        Image(systemName: "pencil")
                            .font(.caption)
                            .foregroundStyle(.pink)
                    }
                    .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)

                    // Delete button
                    Button {
                        hapticTrigger.toggle()
                        deleteModuleTarget = module
                    } label: {
                        Image(systemName: "trash")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                    .sensoryFeedback(.impact(weight: .heavy), trigger: hapticTrigger)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            // Expanded lessons
            if expandedModuleId == module.id {
                Divider()
                    .padding(.horizontal, 12)

                if module.lessons.isEmpty {
                    HStack {
                        Image(systemName: "doc.text")
                            .foregroundStyle(.secondary)
                        Text("No lessons in this module")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(12)
                } else {
                    VStack(spacing: 0) {
                        ForEach(module.lessons) { lesson in
                            lessonRow(lesson, in: module)

                            if lesson.id != module.lessons.last?.id {
                                Divider()
                                    .padding(.leading, 40)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 12))
    }

    private func lessonRow(_ lesson: Lesson, in module: Module) -> some View {
        HStack(spacing: 8) {
            Image(systemName: lesson.type.iconName)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 20)

            if editingLessonId == lesson.id {
                TextField("Lesson title", text: $editingLessonTitle)
                    .textFieldStyle(.roundedBorder)
                    .font(.caption)
                    .onSubmit {
                        saveLessonTitle(lesson, in: module)
                    }

                Button {
                    hapticTrigger.toggle()
                    saveLessonTitle(lesson, in: module)
                } label: {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
                .sensoryFeedback(.impact(weight: .medium), trigger: hapticTrigger)

                Button {
                    hapticTrigger.toggle()
                    editingLessonId = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
            } else {
                Text(lesson.title)
                    .font(.caption)
                    .lineLimit(1)

                Spacer()

                Text("\(lesson.duration) min")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Button {
                    hapticTrigger.toggle()
                    editingLessonTitle = lesson.title
                    editingLessonId = lesson.id
                } label: {
                    Image(systemName: "pencil")
                        .font(.caption2)
                        .foregroundStyle(.pink)
                }
                .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)

                Button {
                    hapticTrigger.toggle()
                    deleteLessonTarget = (moduleId: module.id, lessonId: lesson.id)
                } label: {
                    Image(systemName: "trash")
                        .font(.caption2)
                        .foregroundStyle(.red)
                }
                .sensoryFeedback(.impact(weight: .heavy), trigger: hapticTrigger)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Add Module Section

    private var addModuleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if showAddModule {
                VStack(alignment: .leading, spacing: 10) {
                    Label("New Module", systemImage: "folder.fill.badge.plus")
                        .font(.headline)

                    TextField("Module Title", text: $newModuleTitle)
                        .textFieldStyle(.roundedBorder)

                    HStack(spacing: 10) {
                        Button {
                            hapticTrigger.toggle()
                            addModule()
                        } label: {
                            Group {
                                if isLoading {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Label("Add Module", systemImage: "plus.circle.fill")
                                        .fontWeight(.semibold)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.pink)
                        .disabled(isLoading || newModuleTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                        .sensoryFeedback(.impact(weight: .medium), trigger: hapticTrigger)

                        Button {
                            hapticTrigger.toggle()
                            withAnimation(.snappy) {
                                showAddModule = false
                                newModuleTitle = ""
                            }
                        } label: {
                            Text("Cancel")
                                .fontWeight(.semibold)
                                .frame(height: 44)
                                .padding(.horizontal, 16)
                        }
                        .buttonStyle(.bordered)
                        .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
                    }
                }
                .padding(14)
                .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
            } else {
                Button {
                    hapticTrigger.toggle()
                    withAnimation(.snappy) {
                        showAddModule = true
                    }
                } label: {
                    Label("Add Module", systemImage: "plus.circle.fill")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                }
                .buttonStyle(.borderedProminent)
                .tint(.pink)
                .sensoryFeedback(.impact(weight: .medium), trigger: hapticTrigger)
            }

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
                Text(successMessage)
                    .font(.title3.bold())
            }
            .padding(32)
            .background(.regularMaterial, in: .rect(cornerRadius: 20))
        }
        .transition(.opacity)
        .onTapGesture {
            withAnimation { showSuccess = false }
        }
    }

    // MARK: - Actions

    private func addModule() {
        isLoading = true
        errorMessage = nil
        let trimmedTitle = newModuleTitle.trimmingCharacters(in: .whitespaces)

        Task {
            do {
                try await viewModel.createModule(courseId: course.id, title: trimmedTitle)
                isLoading = false
                newModuleTitle = ""
                showAddModule = false
                successMessage = "Module Added"
                withAnimation(.snappy) { showSuccess = true }
                try? await Task.sleep(for: .seconds(2))
                withAnimation { showSuccess = false }
            } catch {
                errorMessage = "Failed to add module. Please try again."
                isLoading = false
            }
        }
    }

    private func saveModuleTitle(_ module: Module) {
        let trimmed = editingModuleTitle.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        if let courseIndex = viewModel.courses.firstIndex(where: { $0.id == course.id }),
           let moduleIndex = viewModel.courses[courseIndex].modules.firstIndex(where: { $0.id == module.id }) {
            viewModel.courses[courseIndex].modules[moduleIndex].title = trimmed
        }
        editingModuleId = nil
    }

    private func saveLessonTitle(_ lesson: Lesson, in module: Module) {
        let trimmed = editingLessonTitle.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        if let courseIndex = viewModel.courses.firstIndex(where: { $0.id == course.id }),
           let moduleIndex = viewModel.courses[courseIndex].modules.firstIndex(where: { $0.id == module.id }),
           let lessonIndex = viewModel.courses[courseIndex].modules[moduleIndex].lessons.firstIndex(where: { $0.id == lesson.id }) {
            viewModel.courses[courseIndex].modules[moduleIndex].lessons[lessonIndex].title = trimmed
        }
        editingLessonId = nil
    }

    private func deleteModule(_ module: Module) {
        errorMessage = nil

        if let courseIndex = viewModel.courses.firstIndex(where: { $0.id == course.id }) {
            withAnimation(.snappy) {
                viewModel.courses[courseIndex].modules.removeAll { $0.id == module.id }
            }
        }

        if !viewModel.isDemoMode {
            Task {
                do {
                    try await supabaseClient
                        .from("modules")
                        .delete()
                        .eq("id", value: module.id.uuidString)
                        .execute()
                } catch {
                    errorMessage = "Failed to delete module from server."
                }
            }
        }
    }

    private func deleteLesson(moduleId: UUID, lessonId: UUID) {
        errorMessage = nil

        if let courseIndex = viewModel.courses.firstIndex(where: { $0.id == course.id }),
           let moduleIndex = viewModel.courses[courseIndex].modules.firstIndex(where: { $0.id == moduleId }) {
            withAnimation(.snappy) {
                viewModel.courses[courseIndex].modules[moduleIndex].lessons.removeAll { $0.id == lessonId }
            }
        }

        if !viewModel.isDemoMode {
            Task {
                do {
                    try await supabaseClient
                        .from("lessons")
                        .delete()
                        .eq("id", value: lessonId.uuidString)
                        .execute()
                } catch {
                    errorMessage = "Failed to delete lesson from server."
                }
            }
        }
    }
}
