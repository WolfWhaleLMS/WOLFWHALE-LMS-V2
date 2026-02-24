import SwiftUI

struct StudentNotesView: View {
    @Bindable var viewModel: AppViewModel
    let studentId: UUID
    let studentName: String
    let courseId: UUID
    let courseName: String

    @State private var showAddNote = false
    @State private var newNoteContent = ""
    @State private var newNoteCategory: NoteCategory = .general
    @State private var newNoteIsPrivate = true
    @State private var editingNote: TeacherNote?
    @State private var editContent = ""
    @State private var editCategory: NoteCategory = .general
    @State private var editIsPrivate = true
    @State private var selectedCategoryFilter: NoteCategory?
    @State private var showDeleteConfirmation = false
    @State private var noteToDelete: TeacherNote?
    @State private var hapticTrigger = false

    @Environment(\.dismiss) private var dismiss

    private var filteredNotes: [TeacherNote] {
        let allNotes = viewModel.notes(forStudent: studentId, inCourse: courseId)
        if let filter = selectedCategoryFilter {
            return allNotes.filter { $0.category == filter }
        }
        return allNotes
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                headerSection
                categoryFilterSection
                if filteredNotes.isEmpty {
                    emptyState
                } else {
                    notesListSection
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Student Notes")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    hapticTrigger.toggle()
                    showAddNote = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .symbolRenderingMode(.hierarchical)
                }
                .hapticFeedback(.impact(weight: .light), trigger: hapticTrigger)
                .accessibilityLabel("Add Note")
                .accessibilityHint("Add a new note for this student")
            }
        }
        .sheet(isPresented: $showAddNote) {
            addNoteSheet
        }
        .sheet(item: $editingNote) { note in
            editNoteSheet(note)
        }
        .alert("Delete Note", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                if let note = noteToDelete {
                    hapticTrigger.toggle()
                    viewModel.deleteTeacherNote(noteId: note.id)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to delete this note? This cannot be undone.")
        }
        .onAppear {
            viewModel.loadTeacherNotes(studentId: studentId, courseId: courseId)
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 16)
                .fill(.pink.gradient)
                .frame(width: 56, height: 56)
                .overlay {
                    Image(systemName: "person.fill")
                        .font(.title2)
                        .foregroundStyle(.white)
                }
            VStack(alignment: .leading, spacing: 4) {
                Text(studentName)
                    .font(.headline)
                    .foregroundStyle(Color(.label))
                Text(courseName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                let count = viewModel.noteCount(forStudent: studentId, inCourse: courseId)
                Text("\(count) note\(count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Notes for \(studentName) in \(courseName)")
    }

    // MARK: - Category Filter

    private var categoryFilterSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterChip(label: "All", isSelected: selectedCategoryFilter == nil) {
                    selectedCategoryFilter = nil
                }
                ForEach(NoteCategory.allCases) { category in
                    filterChip(
                        label: category.rawValue,
                        icon: category.iconName,
                        isSelected: selectedCategoryFilter == category
                    ) {
                        selectedCategoryFilter = selectedCategoryFilter == category ? nil : category
                    }
                }
            }
            .padding(.horizontal, 2)
        }
    }

    private func filterChip(label: String, icon: String? = nil, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            hapticTrigger.toggle()
            action()
        } label: {
            HStack(spacing: 4) {
                if let icon {
                    Image(systemName: icon)
                        .font(.caption2)
                }
                Text(label)
                    .font(.caption.bold())
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                isSelected ? Color.accentColor : Color(.secondarySystemGroupedBackground),
                in: Capsule()
            )
            .foregroundStyle(isSelected ? .white : Color(.label))
        }
        .hapticFeedback(.impact(weight: .light), trigger: hapticTrigger)
        .accessibilityLabel("\(label) filter")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "note.text")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("No Notes Yet")
                .font(.headline)
                .foregroundStyle(Color(.label))
            Text("Tap the + button to add a private note about this student.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .padding(.horizontal)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .combine)
    }

    // MARK: - Notes List

    private var notesListSection: some View {
        VStack(spacing: 10) {
            ForEach(filteredNotes) { note in
                noteCard(note)
            }
        }
    }

    private func noteCard(_ note: TeacherNote) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // Category & timestamp header
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: note.category.iconName)
                        .font(.caption)
                        .foregroundStyle(categoryColor(note.category))
                    Text(note.category.rawValue)
                        .font(.caption.bold())
                        .foregroundStyle(categoryColor(note.category))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(categoryColor(note.category).opacity(0.12), in: Capsule())

                if note.isPrivate {
                    HStack(spacing: 3) {
                        Image(systemName: "lock.fill")
                            .font(.caption2)
                        Text("Private")
                            .font(.caption2)
                    }
                    .foregroundStyle(.secondary)
                }

                Spacer()

                Text(note.createdDate.formatted(.dateTime.month(.abbreviated).day().hour().minute()))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            // Note content
            Text(note.content)
                .font(.subheadline)
                .foregroundStyle(Color(.label))
                .fixedSize(horizontal: false, vertical: true)

            // Updated indicator
            if let updated = note.updatedDate {
                Text("Edited \(updated.formatted(.dateTime.month(.abbreviated).day()))")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .italic()
            }

            // Action buttons
            HStack(spacing: 16) {
                Spacer()
                Button {
                    hapticTrigger.toggle()
                    editContent = note.content
                    editCategory = note.category
                    editIsPrivate = note.isPrivate
                    editingNote = note
                } label: {
                    Label("Edit", systemImage: "pencil")
                        .font(.caption.bold())
                        .foregroundStyle(.blue)
                }
                .hapticFeedback(.impact(weight: .light), trigger: hapticTrigger)
                .accessibilityLabel("Edit note")

                Button {
                    hapticTrigger.toggle()
                    noteToDelete = note
                    showDeleteConfirmation = true
                } label: {
                    Label("Delete", systemImage: "trash")
                        .font(.caption.bold())
                        .foregroundStyle(.red)
                }
                .hapticFeedback(.impact(weight: .light), trigger: hapticTrigger)
                .accessibilityLabel("Delete note")
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(note.category.rawValue) note: \(note.content)")
    }

    // MARK: - Add Note Sheet

    private var addNoteSheet: some View {
        NavigationStack {
            Form {
                Section("Note Content") {
                    TextEditor(text: $newNoteContent)
                        .frame(minHeight: 100)
                        .accessibilityLabel("Note content")
                }
                Section("Category") {
                    Picker("Category", selection: $newNoteCategory) {
                        ForEach(NoteCategory.allCases) { cat in
                            Label(cat.rawValue, systemImage: cat.iconName)
                                .tag(cat)
                        }
                    }
                    .pickerStyle(.menu)
                    .accessibilityLabel("Note category")
                }
                Section("Visibility") {
                    Toggle(isOn: $newNoteIsPrivate) {
                        Label("Private Note", systemImage: "lock.fill")
                    }
                    if newNoteIsPrivate {
                        Text("Only you and admins can see this note.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Other teachers for this course can also see this note.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("New Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        hapticTrigger.toggle()
                        resetAddForm()
                        showAddNote = false
                    }
                    .hapticFeedback(.impact(weight: .light), trigger: hapticTrigger)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        hapticTrigger.toggle()
                        viewModel.addTeacherNote(
                            studentId: studentId,
                            courseId: courseId,
                            content: newNoteContent,
                            category: newNoteCategory,
                            isPrivate: newNoteIsPrivate
                        )
                        resetAddForm()
                        showAddNote = false
                    }
                    .fontWeight(.semibold)
                    .disabled(newNoteContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .hapticFeedback(.impact(weight: .medium), trigger: hapticTrigger)
                }
            }
        }
    }

    // MARK: - Edit Note Sheet

    private func editNoteSheet(_ note: TeacherNote) -> some View {
        NavigationStack {
            Form {
                Section("Note Content") {
                    TextEditor(text: $editContent)
                        .frame(minHeight: 100)
                        .accessibilityLabel("Edit note content")
                }
                Section("Category") {
                    Picker("Category", selection: $editCategory) {
                        ForEach(NoteCategory.allCases) { cat in
                            Label(cat.rawValue, systemImage: cat.iconName)
                                .tag(cat)
                        }
                    }
                    .pickerStyle(.menu)
                    .accessibilityLabel("Note category")
                }
                Section("Visibility") {
                    Toggle(isOn: $editIsPrivate) {
                        Label("Private Note", systemImage: "lock.fill")
                    }
                }
            }
            .navigationTitle("Edit Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        hapticTrigger.toggle()
                        editingNote = nil
                    }
                    .hapticFeedback(.impact(weight: .light), trigger: hapticTrigger)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        hapticTrigger.toggle()
                        viewModel.updateTeacherNote(
                            noteId: note.id,
                            content: editContent,
                            category: editCategory,
                            isPrivate: editIsPrivate
                        )
                        editingNote = nil
                    }
                    .fontWeight(.semibold)
                    .disabled(editContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .hapticFeedback(.impact(weight: .medium), trigger: hapticTrigger)
                }
            }
        }
    }

    // MARK: - Helpers

    private func categoryColor(_ category: NoteCategory) -> Color {
        switch category {
        case .academic:   .blue
        case .behavioral: .orange
        case .attendance: .purple
        case .parent:     .green
        case .general:    .gray
        }
    }

    private func resetAddForm() {
        newNoteContent = ""
        newNoteCategory = .general
        newNoteIsPrivate = true
    }
}
