import SwiftUI

// MARK: - Add Card Sheet

struct FlashcardCreatorAddCardSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var front = ""
    @State private var back = ""
    let onSave: (Flashcard) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Front (Question)") {
                    TextField("Enter question or term", text: $front, axis: .vertical)
                        .lineLimit(3...6)
                }
                Section("Back (Answer)") {
                    TextField("Enter answer or definition", text: $back, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("Add Card")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add") {
                        let card = Flashcard(front: front.trimmingCharacters(in: .whitespaces), back: back.trimmingCharacters(in: .whitespaces))
                        onSave(card)
                        dismiss()
                    }
                    .disabled(front.trimmingCharacters(in: .whitespaces).isEmpty || back.trimmingCharacters(in: .whitespaces).isEmpty)
                    .bold()
                }
            }
        }
    }
}

// MARK: - Edit Card Sheet

struct FlashcardCreatorEditCardSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var front: String
    @State private var back: String
    let onSave: (Flashcard) -> Void
    private let originalCard: Flashcard

    init(card: Flashcard, onSave: @escaping (Flashcard) -> Void) {
        self.originalCard = card
        self._front = State(initialValue: card.front)
        self._back = State(initialValue: card.back)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Front (Question)") {
                    TextField("Question", text: $front, axis: .vertical)
                        .lineLimit(3...6)
                }
                Section("Back (Answer)") {
                    TextField("Answer", text: $back, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("Edit Card")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        var updated = originalCard
                        updated.front = front.trimmingCharacters(in: .whitespaces)
                        updated.back = back.trimmingCharacters(in: .whitespaces)
                        onSave(updated)
                        dismiss()
                    }
                    .disabled(front.trimmingCharacters(in: .whitespaces).isEmpty || back.trimmingCharacters(in: .whitespaces).isEmpty)
                    .bold()
                }
            }
        }
    }
}
