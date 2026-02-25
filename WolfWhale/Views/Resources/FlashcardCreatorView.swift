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
                    FlashcardCreatorDeckDetailView(deck: $decks[index], onSave: saveDecks, onDelete: {
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

extension FlashcardStudyMode: Identifiable {
    var id: String { rawValue }
}

// MARK: - Preview

#Preview {
    FlashcardCreatorView()
}
