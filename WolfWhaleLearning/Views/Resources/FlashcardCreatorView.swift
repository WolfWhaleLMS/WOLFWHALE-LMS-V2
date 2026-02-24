import SwiftUI

// MARK: - Models

enum CardMastery: String, Codable, CaseIterable {
    case new = "New"
    case learning = "Learning"
    case mastered = "Mastered"

    var color: Color {
        switch self {
        case .new: return .blue
        case .learning: return .orange
        case .mastered: return .green
        }
    }

    var icon: String {
        switch self {
        case .new: return "sparkle"
        case .learning: return "brain.head.profile"
        case .mastered: return "checkmark.seal.fill"
        }
    }
}

struct Flashcard: Codable, Identifiable, Equatable {
    let id: UUID
    var front: String
    var back: String
    var mastery: CardMastery
    var correctCount: Int
    var incorrectCount: Int
    var lastReviewed: Date?
    var nextReviewDate: Date

    init(id: UUID = UUID(), front: String, back: String) {
        self.id = id
        self.front = front
        self.back = back
        self.mastery = .new
        self.correctCount = 0
        self.incorrectCount = 0
        self.lastReviewed = nil
        self.nextReviewDate = Date()
    }

    static func == (lhs: Flashcard, rhs: Flashcard) -> Bool {
        lhs.id == rhs.id
    }
}

struct FlashcardDeck: Codable, Identifiable {
    let id: UUID
    var title: String
    var subject: String
    var cards: [Flashcard]
    let dateCreated: Date
    var dateModified: Date

    var masteryPercentage: Double {
        guard !cards.isEmpty else { return 0 }
        let masteredCount = cards.filter { $0.mastery == .mastered }.count
        return Double(masteredCount) / Double(cards.count) * 100
    }

    init(id: UUID = UUID(), title: String, subject: String, cards: [Flashcard] = []) {
        self.id = id
        self.title = title
        self.subject = subject
        self.cards = cards
        self.dateCreated = Date()
        self.dateModified = Date()
    }
}

enum FlashcardStudyMode: String, CaseIterable {
    case classic = "Classic Flip"
    case quiz = "Quiz Mode"
    case match = "Match Mode"

    var icon: String {
        switch self {
        case .classic: return "rectangle.on.rectangle.angled"
        case .quiz: return "pencil.and.list.clipboard"
        case .match: return "puzzlepiece.extension.fill"
        }
    }

    var color: Color {
        switch self {
        case .classic: return .blue
        case .quiz: return .purple
        case .match: return .orange
        }
    }
}

// MARK: - Sample Decks

struct SampleDecks {
    static let canadianProvincesCapitals = FlashcardDeck(
        title: "Canadian Provinces & Capitals",
        subject: "Geography",
        cards: [
            Flashcard(front: "Ontario", back: "Toronto"),
            Flashcard(front: "Quebec", back: "Quebec City"),
            Flashcard(front: "British Columbia", back: "Victoria"),
            Flashcard(front: "Alberta", back: "Edmonton"),
            Flashcard(front: "Manitoba", back: "Winnipeg"),
            Flashcard(front: "Saskatchewan", back: "Regina"),
            Flashcard(front: "Nova Scotia", back: "Halifax"),
            Flashcard(front: "New Brunswick", back: "Fredericton"),
            Flashcard(front: "Prince Edward Island", back: "Charlottetown"),
            Flashcard(front: "Newfoundland and Labrador", back: "St. John's"),
            Flashcard(front: "Northwest Territories", back: "Yellowknife"),
            Flashcard(front: "Yukon", back: "Whitehorse"),
            Flashcard(front: "Nunavut", back: "Iqaluit")
        ]
    )

    static let frenchBasics = FlashcardDeck(
        title: "French Basics",
        subject: "French",
        cards: [
            Flashcard(front: "Hello", back: "Bonjour"),
            Flashcard(front: "Goodbye", back: "Au revoir"),
            Flashcard(front: "Thank you", back: "Merci"),
            Flashcard(front: "Please", back: "S'il vous plait"),
            Flashcard(front: "Yes", back: "Oui"),
            Flashcard(front: "No", back: "Non"),
            Flashcard(front: "Good morning", back: "Bon matin"),
            Flashcard(front: "Good night", back: "Bonne nuit"),
            Flashcard(front: "How are you?", back: "Comment allez-vous?"),
            Flashcard(front: "My name is...", back: "Je m'appelle...")
        ]
    )

    static let mathFormulas = FlashcardDeck(
        title: "Math Formulas",
        subject: "Math",
        cards: [
            Flashcard(front: "Area of a circle", back: "A = pi x r^2"),
            Flashcard(front: "Circumference of a circle", back: "C = 2 x pi x r"),
            Flashcard(front: "Pythagorean theorem", back: "a^2 + b^2 = c^2"),
            Flashcard(front: "Quadratic formula", back: "x = (-b +/- sqrt(b^2 - 4ac)) / 2a"),
            Flashcard(front: "Area of a triangle", back: "A = (1/2) x base x height"),
            Flashcard(front: "Slope formula", back: "m = (y2 - y1) / (x2 - x1)"),
            Flashcard(front: "Volume of a sphere", back: "V = (4/3) x pi x r^3"),
            Flashcard(front: "Distance formula", back: "d = sqrt((x2-x1)^2 + (y2-y1)^2)"),
            Flashcard(front: "Area of a rectangle", back: "A = length x width"),
            Flashcard(front: "Volume of a cylinder", back: "V = pi x r^2 x h")
        ]
    )

    static let all: [FlashcardDeck] = [canadianProvincesCapitals, frenchBasics, mathFormulas]
}

// MARK: - Main View

struct FlashcardCreatorView: View {
    @AppStorage("flashcardDecks") private var decksData: Data = Data()
    @State private var decks: [FlashcardDeck] = []
    @State private var showCreateDeck = false
    @State private var showAddSamples = false
    @State private var selectedDeck: FlashcardDeck?
    @State private var hapticTrigger = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    statsOverview

                    if decks.isEmpty {
                        emptyState
                    } else {
                        decksList
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 30)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Flashcard Creator")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            showCreateDeck = true
                        } label: {
                            Label("New Deck", systemImage: "plus.rectangle.fill")
                        }
                        Button {
                            showAddSamples = true
                        } label: {
                            Label("Sample Decks", systemImage: "star.fill")
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                    }
                }
            }
            .sheet(isPresented: $showCreateDeck) {
                CreateDeckSheet(onSave: { deck in
                    decks.append(deck)
                    saveDecks()
                })
            }
            .sheet(isPresented: $showAddSamples) {
                sampleDecksSheet
            }
            .sheet(item: $selectedDeck) { deck in
                if let index = decks.firstIndex(where: { $0.id == deck.id }) {
                    DeckDetailView(deck: $decks[index], onSave: saveDecks, onDelete: {
                        decks.removeAll { $0.id == deck.id }
                        saveDecks()
                        selectedDeck = nil
                    })
                }
            }
            .onAppear { loadDecks() }
            .sensoryFeedback(.impact(flexibility: .soft), trigger: hapticTrigger)
        }
    }

    // MARK: - Stats Overview

    private var statsOverview: some View {
        HStack(spacing: 12) {
            statCard(icon: "rectangle.stack.fill", label: "Decks", value: "\(decks.count)", color: .blue)
            statCard(icon: "rectangle.fill", label: "Cards", value: "\(decks.reduce(0) { $0 + $1.cards.count })", color: .purple)
            statCard(icon: "checkmark.seal.fill", label: "Mastered", value: "\(decks.reduce(0) { $0 + $1.cards.filter { $0.mastery == .mastered }.count })", color: .green)
        }
    }

    private func statCard(icon: String, label: String, value: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
            Text(value)
                .font(.title3.bold().monospacedDigit())
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "rectangle.stack.badge.plus")
                .font(.system(size: 60))
                .foregroundStyle(
                    LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
                )

            Text("No Flashcard Decks Yet")
                .font(.title3.bold())

            Text("Create your own deck or start with pre-built sample decks.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 12) {
                Button {
                    showCreateDeck = true
                } label: {
                    Label("New Deck", systemImage: "plus")
                        .font(.subheadline.bold())
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(
                            LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing),
                            in: .rect(cornerRadius: 12)
                        )
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)

                Button {
                    showAddSamples = true
                } label: {
                    Label("Samples", systemImage: "star.fill")
                        .font(.subheadline.bold())
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(.ultraThinMaterial, in: .rect(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

    // MARK: - Decks List

    private var decksList: some View {
        VStack(spacing: 12) {
            ForEach(decks) { deck in
                Button {
                    selectedDeck = deck
                } label: {
                    deckRow(deck)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func deckRow(_ deck: FlashcardDeck) -> some View {
        HStack(spacing: 14) {
            VStack {
                Image(systemName: "rectangle.stack.fill")
                    .font(.title2)
                    .foregroundStyle(subjectColor(deck.subject))
            }
            .frame(width: 50, height: 50)
            .background(subjectColor(deck.subject).opacity(0.15), in: .rect(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 4) {
                Text(deck.title)
                    .font(.headline)

                HStack(spacing: 8) {
                    Text(deck.subject)
                        .font(.caption.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(subjectColor(deck.subject).opacity(0.15), in: Capsule())
                        .foregroundStyle(subjectColor(deck.subject))

                    Text("\(deck.cards.count) cards")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // Mastery progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color(.systemGray5))
                            .frame(height: 6)
                        Capsule()
                            .fill(
                                LinearGradient(colors: [.green, .green.opacity(0.7)], startPoint: .leading, endPoint: .trailing)
                            )
                            .frame(width: max(geo.size.width * (deck.masteryPercentage / 100), 0), height: 6)
                    }
                }
                .frame(height: 6)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(String(format: "%.0f%%", deck.masteryPercentage))
                    .font(.caption.bold().monospacedDigit())
                    .foregroundStyle(.green)
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

    // MARK: - Sample Decks Sheet

    private var sampleDecksSheet: some View {
        NavigationStack {
            List {
                ForEach(SampleDecks.all) { sample in
                    Button {
                        if !decks.contains(where: { $0.title == sample.title }) {
                            decks.append(sample)
                            saveDecks()
                            hapticTrigger.toggle()
                        }
                        showAddSamples = false
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(sample.title)
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                Text("\(sample.cards.count) cards - \(sample.subject)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if decks.contains(where: { $0.title == sample.title }) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            } else {
                                Image(systemName: "plus.circle")
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Sample Decks")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { showAddSamples = false }
                }
            }
        }
    }

    // MARK: - Persistence

    private func loadDecks() {
        if let decoded = try? JSONDecoder().decode([FlashcardDeck].self, from: decksData) {
            decks = decoded
        }
    }

    private func saveDecks() {
        if let data = try? JSONEncoder().encode(decks) {
            decksData = data
        }
    }

    private func subjectColor(_ subject: String) -> Color {
        switch subject.lowercased() {
        case "math": return .blue
        case "science": return .green
        case "english": return .orange
        case "french": return .purple
        case "geography": return .teal
        case "history": return .brown
        default: return .indigo
        }
    }
}

// MARK: - Create Deck Sheet

private struct CreateDeckSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var subject = "Math"
    let onSave: (FlashcardDeck) -> Void

    private let subjects = ["Math", "Science", "English", "French", "Geography", "History", "Art", "Music", "Other"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Deck Info") {
                    TextField("Deck Title", text: $title)

                    Picker("Subject", selection: $subject) {
                        ForEach(subjects, id: \.self) { s in
                            Text(s).tag(s)
                        }
                    }
                }
            }
            .navigationTitle("New Deck")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Create") {
                        let deck = FlashcardDeck(title: title, subject: subject)
                        onSave(deck)
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                    .bold()
                }
            }
        }
    }
}

// MARK: - Deck Detail View

private struct DeckDetailView: View {
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
                AddCardSheet(onSave: { card in
                    deck.cards.append(card)
                    deck.dateModified = Date()
                    onSave()
                })
            }
            .sheet(item: $editingCard) { card in
                if let idx = deck.cards.firstIndex(where: { $0.id == card.id }) {
                    EditCardSheet(card: deck.cards[idx]) { updated in
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
            ClassicStudyView(deck: $deck, onSave: onSave, onDismiss: { studyMode = nil })
        case .quiz:
            QuizStudyView(deck: $deck, onSave: onSave, onDismiss: { studyMode = nil })
        case .match:
            MatchStudyView(deck: $deck, onSave: onSave, onDismiss: { studyMode = nil })
        }
    }
}

extension FlashcardStudyMode: Identifiable {
    var id: String { rawValue }
}

// MARK: - Add Card Sheet

private struct AddCardSheet: View {
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

private struct EditCardSheet: View {
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

// MARK: - Classic Study View

private struct ClassicStudyView: View {
    @Binding var deck: FlashcardDeck
    let onSave: () -> Void
    let onDismiss: () -> Void
    @State private var currentIndex = 0
    @State private var isFlipped = false
    @State private var offset: CGFloat = 0
    @State private var correctCount = 0
    @State private var incorrectCount = 0
    @State private var isComplete = false
    @State private var hapticTrigger = false

    private var studyCards: [Flashcard] {
        // Spaced repetition: prioritise cards that are due and struggling
        deck.cards.sorted { a, b in
            if a.mastery != b.mastery {
                if a.mastery == .new { return true }
                if b.mastery == .new { return false }
                if a.mastery == .learning { return true }
                return false
            }
            return a.nextReviewDate < b.nextReviewDate
        }
    }

    private var currentCard: Flashcard? {
        guard currentIndex < studyCards.count else { return nil }
        return studyCards[currentIndex]
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(currentIndex + 1) / \(studyCards.count)")
                    .font(.subheadline.bold().monospacedDigit())
                Spacer()
                // Balance spacer
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .opacity(0)
            }
            .padding()

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color(.systemGray5)).frame(height: 6)
                    Capsule()
                        .fill(LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing))
                        .frame(width: studyCards.isEmpty ? 0 : geo.size.width * CGFloat(currentIndex) / CGFloat(studyCards.count), height: 6)
                }
            }
            .frame(height: 6)
            .padding(.horizontal)

            Spacer()

            if isComplete {
                completeView
            } else if let card = currentCard {
                // Card
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.ultraThinMaterial)
                        .shadow(color: .black.opacity(0.1), radius: 10, y: 5)

                    VStack(spacing: 16) {
                        Text(isFlipped ? "Answer" : "Question")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)

                        Text(isFlipped ? card.back : card.front)
                            .font(.title2.bold())
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)

                        if !isFlipped {
                            Text("Tap to reveal")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(30)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 300)
                .padding(.horizontal, 30)
                .offset(x: offset)
                .rotationEffect(.degrees(Double(offset / 30)))
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            offset = value.translation.width
                        }
                        .onEnded { value in
                            if value.translation.width > 100 {
                                markCorrect()
                            } else if value.translation.width < -100 {
                                markIncorrect()
                            } else {
                                withAnimation(.spring()) { offset = 0 }
                            }
                        }
                )
                .onTapGesture {
                    withAnimation(.spring(response: 0.4)) {
                        isFlipped.toggle()
                    }
                }

                Spacer()

                if isFlipped {
                    HStack(spacing: 40) {
                        Button {
                            markIncorrect()
                        } label: {
                            VStack(spacing: 6) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 44))
                                    .foregroundStyle(.red)
                                Text("Wrong")
                                    .font(.caption.bold())
                                    .foregroundStyle(.red)
                            }
                        }
                        .buttonStyle(.plain)

                        Button {
                            markCorrect()
                        } label: {
                            VStack(spacing: 6) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 44))
                                    .foregroundStyle(.green)
                                Text("Correct")
                                    .font(.caption.bold())
                                    .foregroundStyle(.green)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.bottom, 40)
                } else {
                    HStack(spacing: 20) {
                        Image(systemName: "arrow.left")
                            .foregroundStyle(.red.opacity(0.5))
                        Text("Swipe left = wrong, right = correct")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Image(systemName: "arrow.right")
                            .foregroundStyle(.green.opacity(0.5))
                    }
                    .padding(.bottom, 40)
                }
            }

            Spacer()
        }
        .background(Color(.systemGroupedBackground))
        .sensoryFeedback(.impact(flexibility: .soft), trigger: hapticTrigger)
    }

    private var completeView: some View {
        VStack(spacing: 20) {
            Image(systemName: "party.popper.fill")
                .font(.system(size: 60))
                .foregroundStyle(
                    LinearGradient(colors: [.orange, .red, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
                )

            Text("Session Complete!")
                .font(.title.bold())

            HStack(spacing: 30) {
                VStack {
                    Text("\(correctCount)")
                        .font(.title.bold())
                        .foregroundStyle(.green)
                    Text("Correct")
                        .font(.caption)
                }
                VStack {
                    Text("\(incorrectCount)")
                        .font(.title.bold())
                        .foregroundStyle(.red)
                    Text("Incorrect")
                        .font(.caption)
                }
            }

            Button {
                onDismiss()
            } label: {
                Text("Done")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing),
                        in: .rect(cornerRadius: 14)
                    )
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 40)
        }
    }

    private func markCorrect() {
        guard let card = currentCard,
              let idx = deck.cards.firstIndex(where: { $0.id == card.id }) else { return }
        correctCount += 1
        deck.cards[idx].correctCount += 1
        deck.cards[idx].lastReviewed = Date()

        if deck.cards[idx].correctCount >= 3 {
            deck.cards[idx].mastery = .mastered
            deck.cards[idx].nextReviewDate = Date().addingTimeInterval(7 * 86400)
        } else {
            deck.cards[idx].mastery = .learning
            deck.cards[idx].nextReviewDate = Date().addingTimeInterval(86400)
        }

        onSave()
        hapticTrigger.toggle()
        advance()
    }

    private func markIncorrect() {
        guard let card = currentCard,
              let idx = deck.cards.firstIndex(where: { $0.id == card.id }) else { return }
        incorrectCount += 1
        deck.cards[idx].incorrectCount += 1
        deck.cards[idx].lastReviewed = Date()
        deck.cards[idx].mastery = .learning
        deck.cards[idx].nextReviewDate = Date().addingTimeInterval(600)
        onSave()
        hapticTrigger.toggle()
        advance()
    }

    private func advance() {
        withAnimation(.spring()) {
            offset = 0
            isFlipped = false
        }
        if currentIndex + 1 >= studyCards.count {
            isComplete = true
        } else {
            currentIndex += 1
        }
    }
}

// MARK: - Quiz Study View

private struct QuizStudyView: View {
    @Binding var deck: FlashcardDeck
    let onSave: () -> Void
    let onDismiss: () -> Void
    @State private var currentIndex = 0
    @State private var userAnswer = ""
    @State private var showResult = false
    @State private var isCorrectAnswer = false
    @State private var score = 0
    @State private var isComplete = false

    @State private var shuffledCards: [Flashcard] = []

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button { onDismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("Quiz Mode")
                    .font(.subheadline.bold())
                Spacer()
                Text("\(score)/\(shuffledCards.count)")
                    .font(.subheadline.bold().monospacedDigit())
                    .foregroundStyle(.purple)
            }
            .padding()

            if isComplete {
                quizCompleteView
            } else if currentIndex < shuffledCards.count {
                let card = shuffledCards[currentIndex]

                Spacer()

                VStack(spacing: 20) {
                    Text(card.front)
                        .font(.title2.bold())
                        .multilineTextAlignment(.center)
                        .padding()

                    TextField("Type your answer...", text: $userAnswer)
                        .textFieldStyle(.plain)
                        .font(.body)
                        .padding()
                        .background(.ultraThinMaterial, in: .rect(cornerRadius: 12))
                        .padding(.horizontal)
                        .disabled(showResult)

                    if showResult {
                        VStack(spacing: 8) {
                            Image(systemName: isCorrectAnswer ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .font(.system(size: 40))
                                .foregroundStyle(isCorrectAnswer ? .green : .red)

                            if !isCorrectAnswer {
                                Text("Correct answer: \(card.back)")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding()
                    }
                }

                Spacer()

                Button {
                    if showResult {
                        nextQuestion()
                    } else {
                        checkAnswer()
                    }
                } label: {
                    Text(showResult ? "Next" : "Check Answer")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(colors: [.purple, .blue], startPoint: .leading, endPoint: .trailing),
                            in: .rect(cornerRadius: 14)
                        )
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                .padding()
            }
        }
        .background(Color(.systemGroupedBackground))
        .onAppear {
            shuffledCards = deck.cards.shuffled()
        }
    }

    private var quizCompleteView: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "star.fill")
                .font(.system(size: 60))
                .foregroundStyle(.yellow)
            Text("Quiz Complete!")
                .font(.title.bold())
            Text("Score: \(score) / \(shuffledCards.count)")
                .font(.title2)
                .foregroundStyle(.purple)
            Text(String(format: "%.0f%%", shuffledCards.isEmpty ? 0 : Double(score) / Double(shuffledCards.count) * 100))
                .font(.largeTitle.bold())
            Spacer()
            Button {
                onDismiss()
            } label: {
                Text("Done")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(.purple, in: .rect(cornerRadius: 14))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .padding()
        }
    }

    private func checkAnswer() {
        let card = shuffledCards[currentIndex]
        isCorrectAnswer = userAnswer.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == card.back.lowercased()
        if isCorrectAnswer { score += 1 }

        if let idx = deck.cards.firstIndex(where: { $0.id == card.id }) {
            if isCorrectAnswer {
                deck.cards[idx].correctCount += 1
                if deck.cards[idx].correctCount >= 3 { deck.cards[idx].mastery = .mastered }
                else { deck.cards[idx].mastery = .learning }
            } else {
                deck.cards[idx].incorrectCount += 1
                deck.cards[idx].mastery = .learning
            }
            deck.cards[idx].lastReviewed = Date()
            onSave()
        }

        showResult = true
    }

    private func nextQuestion() {
        showResult = false
        isCorrectAnswer = false
        userAnswer = ""
        if currentIndex + 1 >= shuffledCards.count {
            isComplete = true
        } else {
            currentIndex += 1
        }
    }
}

// MARK: - Match Study View

private struct MatchStudyView: View {
    @Binding var deck: FlashcardDeck
    let onSave: () -> Void
    let onDismiss: () -> Void

    @State private var fronts: [(id: UUID, text: String)] = []
    @State private var backs: [(id: UUID, text: String)] = []
    @State private var selectedFront: UUID?
    @State private var selectedBack: UUID?
    @State private var matchedPairs: Set<UUID> = []
    @State private var wrongPair = false
    @State private var isComplete = false
    @State private var attempts = 0

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button { onDismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("Match Mode")
                    .font(.subheadline.bold())
                Spacer()
                Text("Matched: \(matchedPairs.count)/\(fronts.count)")
                    .font(.caption.bold().monospacedDigit())
                    .foregroundStyle(.orange)
            }
            .padding()

            if isComplete {
                matchCompleteView
            } else {
                ScrollView {
                    HStack(alignment: .top, spacing: 12) {
                        // Fronts column
                        VStack(spacing: 8) {
                            Text("Terms")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                            ForEach(fronts, id: \.id) { item in
                                Button {
                                    selectedFront = item.id
                                    checkMatch()
                                } label: {
                                    Text(item.text)
                                        .font(.caption.bold())
                                        .lineLimit(3)
                                        .multilineTextAlignment(.center)
                                        .frame(maxWidth: .infinity)
                                        .padding(10)
                                        .background(
                                            matchedPairs.contains(item.id)
                                            ? AnyShapeStyle(Color.green.opacity(0.2))
                                            : selectedFront == item.id
                                            ? AnyShapeStyle(Color.blue.opacity(0.3))
                                            : AnyShapeStyle(.ultraThinMaterial)
                                        )
                                        .clipShape(.rect(cornerRadius: 10))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10)
                                                .strokeBorder(
                                                    selectedFront == item.id ? .blue : matchedPairs.contains(item.id) ? .green : .clear,
                                                    lineWidth: 2
                                                )
                                        )
                                }
                                .buttonStyle(.plain)
                                .disabled(matchedPairs.contains(item.id))
                            }
                        }

                        // Backs column
                        VStack(spacing: 8) {
                            Text("Definitions")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                            ForEach(backs, id: \.id) { item in
                                Button {
                                    selectedBack = item.id
                                    checkMatch()
                                } label: {
                                    Text(item.text)
                                        .font(.caption.bold())
                                        .lineLimit(3)
                                        .multilineTextAlignment(.center)
                                        .frame(maxWidth: .infinity)
                                        .padding(10)
                                        .background(
                                            matchedPairs.contains(item.id)
                                            ? AnyShapeStyle(Color.green.opacity(0.2))
                                            : selectedBack == item.id
                                            ? AnyShapeStyle(Color.orange.opacity(0.3))
                                            : AnyShapeStyle(.ultraThinMaterial)
                                        )
                                        .clipShape(.rect(cornerRadius: 10))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10)
                                                .strokeBorder(
                                                    selectedBack == item.id ? .orange : matchedPairs.contains(item.id) ? .green : .clear,
                                                    lineWidth: 2
                                                )
                                        )
                                }
                                .buttonStyle(.plain)
                                .disabled(matchedPairs.contains(item.id))
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        .background(Color(.systemGroupedBackground))
        .onAppear { setupMatch() }
    }

    private var matchCompleteView: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "puzzlepiece.extension.fill")
                .font(.system(size: 60))
                .foregroundStyle(.orange)
            Text("All Matched!")
                .font(.title.bold())
            Text("Attempts: \(attempts)")
                .font(.title3)
                .foregroundStyle(.secondary)
            Spacer()
            Button { onDismiss() } label: {
                Text("Done")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(.orange, in: .rect(cornerRadius: 14))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .padding()
        }
    }

    private func setupMatch() {
        let cards = Array(deck.cards.prefix(8).shuffled())
        fronts = cards.map { (id: $0.id, text: $0.front) }.shuffled()
        backs = cards.map { (id: $0.id, text: $0.back) }.shuffled()
    }

    private func checkMatch() {
        guard let fID = selectedFront, let bID = selectedBack else { return }
        attempts += 1

        if fID == bID {
            matchedPairs.insert(fID)
            selectedFront = nil
            selectedBack = nil

            if matchedPairs.count == fronts.count {
                isComplete = true
            }
        } else {
            wrongPair = true
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(500))
                selectedFront = nil
                selectedBack = nil
                wrongPair = false
            }
        }
    }
}

// MARK: - Preview

#Preview {
    FlashcardCreatorView()
}
