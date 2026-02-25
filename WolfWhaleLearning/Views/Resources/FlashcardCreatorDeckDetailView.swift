import SwiftUI

// MARK: - Deck Detail View

struct FlashcardCreatorDeckDetailView: View {
    @Binding var deck: FlashcardDeck
    let onSave: () -> Void
    let onDelete: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var showAddCard = false
    @State private var studyMode: FlashcardStudyMode?
    @State private var editingCard: Flashcard?
    @State private var showDeleteConfirm = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    deckHeader
                    studyModePicker
                    if deck.cards.isEmpty {
                        emptyCardsState
                    } else {
                        cardsList
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 30)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(deck.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            showAddCard = true
                        } label: {
                            Label("Add Card", systemImage: "plus.rectangle")
                        }
                        Button(role: .destructive) {
                            showDeleteConfirm = true
                        } label: {
                            Label("Delete Deck", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showAddCard) {
                FlashcardCreatorAddCardSheet(onSave: { card in
                    deck.cards.append(card)
                    deck.dateModified = Date()
                    onSave()
                })
            }
            .sheet(item: $editingCard) { card in
                if let idx = deck.cards.firstIndex(where: { $0.id == card.id }) {
                    FlashcardCreatorEditCardSheet(card: deck.cards[idx]) { updated in
                        deck.cards[idx] = updated
                        deck.dateModified = Date()
                        onSave()
                    }
                }
            }
            .fullScreenCover(item: $studyMode) { mode in
                studyView(for: mode)
            }
            .alert("Delete Deck?", isPresented: $showDeleteConfirm) {
                Button("Delete", role: .destructive) {
                    onDelete()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently delete \"\(deck.title)\" and all its cards.")
            }
        }
    }

    private var deckHeader: some View {
        HStack(spacing: 16) {
            VStack(spacing: 4) {
                Text("\(deck.cards.count)")
                    .font(.title2.bold())
                Text("Cards")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)

            Divider().frame(height: 40)

            VStack(spacing: 4) {
                Text(String(format: "%.0f%%", deck.masteryPercentage))
                    .font(.title2.bold())
                    .foregroundStyle(.green)
                Text("Mastered")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)

            Divider().frame(height: 40)

            VStack(spacing: 4) {
                Text("\(deck.cards.filter { $0.mastery == .learning }.count)")
                    .font(.title2.bold())
                    .foregroundStyle(.orange)
                Text("Learning")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
        }
        .padding()
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

    private var studyModePicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Study Modes")
                .font(.headline)

            HStack(spacing: 10) {
                ForEach(FlashcardStudyMode.allCases, id: \.self) { mode in
                    Button {
                        guard !deck.cards.isEmpty else { return }
                        studyMode = mode
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: mode.icon)
                                .font(.title3)
                            Text(mode.rawValue)
                                .font(.caption2.bold())
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(colors: [mode.color.opacity(0.2), mode.color.opacity(0.1)], startPoint: .top, endPoint: .bottom),
                            in: .rect(cornerRadius: 12)
                        )
                        .foregroundStyle(deck.cards.isEmpty ? .secondary : mode.color)
                    }
                    .buttonStyle(.plain)
                    .disabled(deck.cards.isEmpty)
                }
            }
        }
    }

    private var emptyCardsState: some View {
        VStack(spacing: 12) {
            Image(systemName: "rectangle.badge.plus")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("No cards yet")
                .font(.headline)
            Button {
                showAddCard = true
            } label: {
                Label("Add First Card", systemImage: "plus")
                    .font(.subheadline.bold())
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(.blue, in: .rect(cornerRadius: 10))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
        }
        .padding(40)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

    private var cardsList: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Cards")
                .font(.headline)

            ForEach(deck.cards) { card in
                HStack {
                    Image(systemName: card.mastery.icon)
                        .foregroundStyle(card.mastery.color)
                        .frame(width: 24)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(card.front)
                            .font(.subheadline.bold())
                            .lineLimit(1)
                        Text(card.back)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    Button {
                        editingCard = card
                    } label: {
                        Image(systemName: "pencil.circle")
                            .foregroundStyle(.blue)
                    }
                    .buttonStyle(.plain)

                    Button {
                        deck.cards.removeAll { $0.id == card.id }
                        onSave()
                    } label: {
                        Image(systemName: "trash.circle")
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                }
                .padding(12)
                .background(.ultraThinMaterial, in: .rect(cornerRadius: 10))
            }
        }
    }

    @ViewBuilder
    private func studyView(for mode: FlashcardStudyMode) -> some View {
        switch mode {
        case .classic:
            FlashcardCreatorClassicStudyView(deck: $deck, onSave: onSave, onDismiss: { studyMode = nil })
        case .quiz:
            FlashcardCreatorQuizStudyView(deck: $deck, onSave: onSave, onDismiss: { studyMode = nil })
        case .match:
            FlashcardCreatorMatchStudyView(deck: $deck, onSave: onSave, onDismiss: { studyMode = nil })
        }
    }
}
