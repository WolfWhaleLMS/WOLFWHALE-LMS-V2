import SwiftUI

/// A launchpad grid view that surfaces every interactive learning tool in the app.
/// Tools are grouped by category and can be filtered via the search bar.
struct LearningToolsView: View {
    let viewModel: AppViewModel
    @State private var searchText = ""
    @State private var hapticTrigger = false

    // MARK: - Tool Definition

    private struct ToolItem: Identifiable, Hashable {
        let id = UUID()
        let title: String
        let subtitle: String
        let icon: String
        let gradientColors: [Color]
        let category: ToolCategory

        nonisolated func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }

        nonisolated static func == (lhs: ToolItem, rhs: ToolItem) -> Bool {
            lhs.id == rhs.id
        }
    }

    private enum ToolCategory: String, CaseIterable, Identifiable {
        case language = "Language"
        case math = "Math"
        case science = "Science"
        case socialStudies = "Social Studies"
        case tools = "Tools"
        case games = "Games"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .language: return "textformat.abc"
            case .math: return "function"
            case .science: return "atom"
            case .socialStudies: return "globe.americas.fill"
            case .tools: return "wrench.and.screwdriver.fill"
            case .games: return "gamecontroller.fill"
            }
        }

        var color: Color {
            switch self {
            case .language: return .cyan
            case .math: return .green
            case .science: return .orange
            case .socialStudies: return .teal
            case .tools: return .indigo
            case .games: return .purple
            }
        }
    }

    // MARK: - All Tools

    private let allTools: [ToolItem] = [
        // Language
        ToolItem(title: "Spelling Bee", subtitle: "Practice your spelling", icon: "textformat", gradientColors: [.yellow, .orange], category: .language),
        ToolItem(title: "Grammar Quest", subtitle: "Master grammar rules", icon: "text.book.closed.fill", gradientColors: [.purple, .orange], category: .language),
        ToolItem(title: "French Vocab", subtitle: "Learn French vocabulary", icon: "character.book.closed.fill", gradientColors: [.blue, .indigo], category: .language),
        ToolItem(title: "Speech to Text", subtitle: "Dictate your notes", icon: "waveform", gradientColors: [.indigo, .purple], category: .language),

        // Math
        ToolItem(title: "Math Quiz", subtitle: "Test your math skills", icon: "function", gradientColors: [.green, .mint], category: .math),
        ToolItem(title: "Unit Converter", subtitle: "Convert between units", icon: "arrow.left.arrow.right", gradientColors: [.mint, .teal], category: .math),

        // Science
        ToolItem(title: "AR Library", subtitle: "3D science models in AR", icon: "arkit", gradientColors: [.indigo, .blue], category: .science),
        ToolItem(title: "Periodic Table", subtitle: "Explore all elements", icon: "tablecells.fill", gradientColors: [.indigo, .purple], category: .science),

        // Social Studies
        ToolItem(title: "World Map Quiz", subtitle: "Test geography knowledge", icon: "globe.desk.fill", gradientColors: [.teal, .green], category: .socialStudies),

        // Tools
        ToolItem(title: "Document Scanner", subtitle: "Scan & digitize documents", icon: "doc.viewfinder.fill", gradientColors: [.blue, .cyan], category: .tools),
        ToolItem(title: "Drawing Canvas", subtitle: "Sketch & annotate", icon: "pencil.tip.crop.circle", gradientColors: [.orange, .purple], category: .tools),
        ToolItem(title: "Flashcards", subtitle: "Create & study flashcards", icon: "rectangle.on.rectangle.angled", gradientColors: [.yellow, .orange], category: .tools),
        ToolItem(title: "Typing Tutor", subtitle: "Improve typing speed", icon: "keyboard.fill", gradientColors: [.gray, .blue], category: .tools),

        // Games
        ToolItem(title: "Chess", subtitle: "Strategic thinking & planning", icon: "crown.fill", gradientColors: [.purple, .indigo], category: .games),
    ]

    // MARK: - Filtering

    private var filteredTools: [ToolItem] {
        guard !searchText.isEmpty else { return allTools }
        let query = searchText.lowercased()
        return allTools.filter { tool in
            tool.title.lowercased().contains(query) ||
            tool.subtitle.lowercased().contains(query) ||
            tool.category.rawValue.lowercased().contains(query)
        }
    }

    private var groupedTools: [(category: ToolCategory, tools: [ToolItem])] {
        let tools = filteredTools
        return ToolCategory.allCases.compactMap { category in
            let matching = tools.filter { $0.category == category }
            return matching.isEmpty ? nil : (category: category, tools: matching)
        }
    }

    private let gridColumns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]

    // MARK: - Body

    var body: some View {
        ScrollView {
            if groupedTools.isEmpty {
                noResultsView
            } else {
                LazyVStack(spacing: 28) {
                    ForEach(groupedTools, id: \.category) { group in
                        toolSection(category: group.category, tools: group.tools)
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
        }
        .background(Color(UIColor.systemGroupedBackground))
        .searchable(text: $searchText, prompt: "Search tools...")
        .navigationTitle("Learning Tools")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
    }

    // MARK: - Sections

    private func toolSection(category: ToolCategory, tools: [ToolItem]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: category.icon)
                    .font(.headline)
                    .foregroundStyle(category.color)
                Text(category.rawValue)
                    .font(.title3.bold())
            }
            .padding(.horizontal)

            LazyVGrid(columns: gridColumns, spacing: 14) {
                ForEach(tools) { tool in
                    NavigationLink {
                        destinationView(for: tool)
                    } label: {
                        ToolCard(
                            title: tool.title,
                            subtitle: tool.subtitle,
                            icon: tool.icon,
                            gradientColors: tool.gradientColors
                        )
                    }
                    .buttonStyle(.plain)
                    .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
                }
            }
            .padding(.horizontal)
        }
    }

    // MARK: - No Results

    private var noResultsView: some View {
        ContentUnavailableView.search(text: searchText)
            .padding(.top, 60)
    }

    // MARK: - Standalone Placeholder Assignment

    /// A lightweight placeholder assignment used when launching the Document Scanner
    /// or Drawing Canvas from the Learning Tools grid (outside an assignment context).
    private var standaloneAssignment: Assignment {
        Assignment(
            id: UUID(),
            title: "Practice",
            courseId: UUID(),
            courseName: "Learning Tools",
            instructions: "Use this tool freely for practice.",
            dueDate: Date().addingTimeInterval(86400 * 30),
            points: 0,
            isSubmitted: false,
            submission: nil,
            grade: nil,
            feedback: nil,
            xpReward: 0
        )
    }

    // MARK: - Navigation Destinations

    @ViewBuilder
    private func destinationView(for tool: ToolItem) -> some View {
        switch tool.title {
        case "Document Scanner":
            DocumentScanView(assignment: standaloneAssignment, viewModel: viewModel)
        case "Drawing Canvas":
            DrawingCanvasView(assignment: standaloneAssignment, viewModel: viewModel)
        case "Speech to Text":
            SpeechToTextView(viewModel: viewModel)
        case "Flashcards":
            FlashcardCreatorView()
        case "AR Library":
            ARLibraryView(viewModel: viewModel)
        case "Spelling Bee":
            SpellingBeeView()
        case "Math Quiz":
            MathQuizView()
        case "Grammar Quest":
            GrammarQuestView()
        case "Typing Tutor":
            TypingTutorView()
        case "World Map Quiz":
            WorldMapQuizView()
        case "Periodic Table":
            PeriodicTableView()
        case "French Vocab":
            FrenchVocabView()
        case "Unit Converter":
            UnitConverterView()
        case "Chess":
            ChessGameView()
        default:
            Text("Coming Soon")
                .font(.title2)
                .foregroundStyle(.secondary)
        }
    }
}
