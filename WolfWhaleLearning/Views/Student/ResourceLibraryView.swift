import SwiftUI

// MARK: - Resource Category

enum ResourceCategory: String, CaseIterable, Identifiable {
    case tools = "Study Tools"
    case mathematics = "Mathematics"
    case science = "Science"
    case english = "English"
    case french = "French"
    case canadianStudies = "Canadian Studies"
    case geography = "Geography"
    case ar = "AR Experiences"
    case games = "Games"

    var id: String { rawValue }

    var iconName: String {
        switch self {
        case .tools: "wrench.and.screwdriver.fill"
        case .mathematics: "function"
        case .science: "atom"
        case .english: "textformat.abc"
        case .french: "globe.europe.africa.fill"
        case .canadianStudies: "mappin.and.ellipse"
        case .geography: "globe.americas.fill"
        case .ar: "arkit"
        case .games: "gamecontroller.fill"
        }
    }

    var color: Color {
        switch self {
        case .tools: .gray
        case .mathematics: .green
        case .science: .orange
        case .english: .cyan
        case .french: .blue
        case .canadianStudies: .red
        case .geography: .teal
        case .ar: .indigo
        case .games: .purple
        }
    }
}

// MARK: - Resource Item

struct ResourceItem: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let icon: String
    let color1: Color
    let color2: Color
    let category: ResourceCategory

    static let allResources: [ResourceItem] = [
        // Study Tools
        ResourceItem(title: "Flashcard Creator", description: "Create & study flashcards", icon: "rectangle.on.rectangle.angled", color1: .yellow, color2: .orange, category: .tools),
        ResourceItem(title: "Unit Converter", description: "Convert between units", icon: "arrow.left.arrow.right", color1: .mint, color2: .teal, category: .tools),
        ResourceItem(title: "Typing Tutor", description: "Improve your typing speed", icon: "keyboard.fill", color1: .gray, color2: .blue, category: .tools),
        ResourceItem(title: "AI Study Assistant", description: "Ask questions & get help", icon: "sparkles", color1: .purple, color2: .indigo, category: .tools),

        // Mathematics
        ResourceItem(title: "Math Quiz", description: "Test your math skills", icon: "function", color1: .green, color2: .mint, category: .mathematics),
        ResourceItem(title: "Fraction Builder", description: "Master fractions visually", icon: "circle.lefthalf.filled", color1: .teal, color2: .green, category: .mathematics),
        ResourceItem(title: "Geometry Explorer", description: "Shapes, angles & more", icon: "triangle.fill", color1: .blue, color2: .cyan, category: .mathematics),

        // Science
        ResourceItem(title: "Periodic Table", description: "Explore all elements", icon: "tablecells.fill", color1: .indigo, color2: .purple, category: .science),
        ResourceItem(title: "Human Body", description: "Interactive anatomy guide", icon: "figure.stand", color1: .pink, color2: .red, category: .science),

        // English
        ResourceItem(title: "Word Builder", description: "Build words from letters", icon: "textformat.abc", color1: .cyan, color2: .blue, category: .english),
        ResourceItem(title: "Spelling Bee", description: "Practice your spelling", icon: "textformat", color1: .yellow, color2: .orange, category: .english),
        ResourceItem(title: "Grammar Quest", description: "Master grammar rules", icon: "text.book.closed.fill", color1: .purple, color2: .pink, category: .english),

        // French
        ResourceItem(title: "French Vocab", description: "Learn French vocabulary", icon: "character.book.closed.fill", color1: .blue, color2: .indigo, category: .french),
        ResourceItem(title: "French Verbs", description: "Conjugation practice", icon: "text.word.spacing", color1: .red, color2: .blue, category: .french),

        // Canadian Studies
        ResourceItem(title: "Canadian History", description: "Interactive timeline of key events", icon: "clock.arrow.circlepath", color1: .red, color2: .orange, category: .canadianStudies),
        ResourceItem(title: "Canadian Geography", description: "Provinces, capitals & more", icon: "map.fill", color1: .green, color2: .teal, category: .canadianStudies),
        ResourceItem(title: "Indigenous Peoples", description: "History, culture & contributions", icon: "leaf.fill", color1: .orange, color2: .brown, category: .canadianStudies),

        // Geography
        ResourceItem(title: "World Map Quiz", description: "Test your geography knowledge", icon: "globe.desk.fill", color1: .teal, color2: .green, category: .geography),

        // Games
        ResourceItem(title: "Chess", description: "Strategic thinking & planning", icon: "crown.fill", color1: .purple, color2: .indigo, category: .games),
    ]
}

// MARK: - Resource Library View

struct ResourceLibraryView: View {
    @Bindable var viewModel: AppViewModel
    @State private var selectedCategory: ResourceCategory?
    @State private var searchText = ""

    private var filteredResources: [ResourceItem] {
        var items = ResourceItem.allResources
        if let category = selectedCategory {
            items = items.filter { $0.category == category }
        }
        if !searchText.isEmpty {
            items = items.filter {
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                $0.description.localizedCaseInsensitiveContains(searchText) ||
                $0.category.rawValue.localizedCaseInsensitiveContains(searchText)
            }
        }
        return items
    }

    private var gridColumns: [GridItem] {
        [
            GridItem(.flexible(), spacing: 14),
            GridItem(.flexible(), spacing: 14)
        ]
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    heroSection
                    categoryFilter
                    resourcesGrid
                }
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .background { HolographicBackground() }
            .navigationTitle("Resource Library")
            .searchable(text: $searchText, prompt: "Search tools, games, subjects...")
        }
    }

    // MARK: - Hero Section

    private var heroSection: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24)
                .fill(
                    MeshGradient(
                        width: 3, height: 3,
                        points: [
                            [0, 0], [0.5, 0], [1, 0],
                            [0, 0.5], [0.5, 0.5], [1, 0.5],
                            [0, 1], [0.5, 1], [1, 1]
                        ],
                        colors: [
                            .purple, .indigo, .blue,
                            .blue, .purple, .indigo,
                            .indigo, .blue, .purple
                        ]
                    )
                )
                .frame(height: 160)

            VStack(spacing: 8) {
                Image(systemName: "books.vertical.fill")
                    .font(.system(size: 36, weight: .medium))
                    .foregroundStyle(.white)
                    .symbolRenderingMode(.hierarchical)
                    .symbolEffect(.breathe, options: .repeat(.periodic(delay: 3)))

                Text("Resource Library")
                    .font(.title2.bold())
                    .foregroundStyle(.white)

                Text("Explore AR, games, and interactive learning tools")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.85))
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Category Filter

    private var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                categoryChip(
                    title: "All",
                    icon: "square.grid.2x2.fill",
                    color: .accentColor,
                    isSelected: selectedCategory == nil
                ) {
                    withAnimation(.spring(response: 0.3)) {
                        selectedCategory = nil
                    }
                }

                ForEach(ResourceCategory.allCases) { category in
                    categoryChip(
                        title: category.rawValue,
                        icon: category.iconName,
                        color: category.color,
                        isSelected: selectedCategory == category
                    ) {
                        withAnimation(.spring(response: 0.3)) {
                            selectedCategory = selectedCategory == category ? nil : category
                        }
                    }
                }
            }
        }
        .contentMargins(.horizontal, 16)
    }

    private func categoryChip(title: String, icon: String, color: Color, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(isSelected ? .white : color)
                Text(title)
                    .font(.subheadline.weight(.medium))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(isSelected ? color : Color(.tertiarySystemBackground), in: Capsule())
            .foregroundStyle(isSelected ? .white : .primary)
        }
        .hapticFeedback(.selection, trigger: isSelected)
        .accessibilityLabel(title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - Resources Grid

    private var resourcesGrid: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Section header with count
            HStack {
                Text(selectedCategory?.rawValue ?? "All Resources")
                    .font(.title3.bold())
                Spacer()
                Text("\(filteredResources.count) item\(filteredResources.count == 1 ? "" : "s")")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)

            // AR banner (show when AR category or All is selected)
            if selectedCategory == nil || selectedCategory == .ar {
                arBanner
            }

            if selectedCategory == .ar {
                // AR category just shows the banner above — no grid items needed
                EmptyView()
            } else if filteredResources.isEmpty {
                ContentUnavailableView(
                    "No Resources Found",
                    systemImage: "magnifyingglass",
                    description: Text(searchText.isEmpty ? "Select a category to explore" : "Try a different search term")
                )
                .padding(.top, 40)
            } else {
                LazyVGrid(columns: gridColumns, spacing: 14) {
                    ForEach(filteredResources) { item in
                        resourceNavigationLink(item)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    // MARK: - AR Banner

    private var arBanner: some View {
        NavigationLink {
            ARLibraryView(viewModel: viewModel)
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.indigo.gradient)
                        .frame(width: 60, height: 60)
                    Image(systemName: "arkit")
                        .font(.title2)
                        .foregroundStyle(.white)
                        .symbolEffect(.pulse, options: .repeating)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("AR Experiences")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text("Explore 3D models in augmented reality")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundStyle(.tertiary)
            }
            .padding(14)
            .glassCard(cornerRadius: 16)
        }
        .buttonStyle(.plain)
        .padding(.horizontal)
        .accessibilityLabel("AR Experiences")
        .accessibilityHint("Double tap to explore augmented reality models")
    }

    // MARK: - Resource Navigation

    @ViewBuilder
    private func resourceNavigationLink(_ item: ResourceItem) -> some View {
        NavigationLink {
            destinationView(for: item)
        } label: {
            resourceCard(item)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(item.title)
        .accessibilityHint("Double tap to open \(item.title)")
    }

    @ViewBuilder
    private func destinationView(for item: ResourceItem) -> some View {
        switch item.title {
        // Tools
        case "Flashcard Creator": FlashcardCreatorView()
        case "Unit Converter": UnitConverterView()
        case "Typing Tutor": TypingTutorView()
        case "AI Study Assistant": AIAssistantView()
        // Mathematics
        case "Math Quiz": MathQuizView()
        case "Fraction Builder": FractionBuilderView()
        case "Geometry Explorer": GeometryExplorerView()
        // Science
        case "Periodic Table": PeriodicTableView()
        case "Human Body": HumanBodyView()
        // English
        case "Word Builder": WordBuilderView()
        case "Spelling Bee": SpellingBeeView()
        case "Grammar Quest": GrammarQuestView()
        // French
        case "French Vocab": FrenchVocabView()
        case "French Verbs": FrenchVerbView()
        // Canadian Studies
        case "Canadian History": CanadianHistoryTimelineView()
        case "Canadian Geography": CanadianGeographyView()
        case "Indigenous Peoples": IndigenousPeoplesView()
        // Geography
        case "World Map Quiz": WorldMapQuizView()
        // Games
        case "Chess": ChessGameView()
        default: Text("Coming Soon")
        }
    }

    // MARK: - Resource Card

    private func resourceCard(_ item: ResourceItem) -> some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [item.color1, item.color2],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 56, height: 56)

                Image(systemName: item.icon)
                    .font(.title2)
                    .foregroundStyle(.white)
                    .symbolRenderingMode(.hierarchical)
                    .contentTransition(.symbolEffect(.replace))
            }

            VStack(spacing: 4) {
                Text(item.title)
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)

                Text(item.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }

            // Category badge
            Text(item.category.rawValue)
                .font(.caption2)
                .foregroundStyle(item.category.color)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(item.category.color.opacity(0.12), in: Capsule())
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .padding(.horizontal, 12)
        .glassCard(cornerRadius: 16)
    }
}
