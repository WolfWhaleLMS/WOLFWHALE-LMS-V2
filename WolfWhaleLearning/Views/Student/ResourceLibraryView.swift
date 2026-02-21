import SwiftUI

struct ResourceLibraryView: View {
    @Bindable var viewModel: AppViewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    heroSection
                    arExperiencesSection
                    mathematicsSection
                    scienceSection
                    englishSection
                    frenchSection
                    canadianStudiesSection
                    geographySection
                    gamesSection
                    toolsSection
                }
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Resource Library")
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
                Image(systemName: "square.grid.2x2.fill")
                    .font(.system(size: 36, weight: .medium))
                    .foregroundStyle(.white)
                    .symbolEffect(.pulse, options: .repeating)

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

    // MARK: - AR Experiences Section

    private var arExperiencesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(title: "AR Experiences", icon: "arkit", color: .indigo)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    NavigationLink {
                        ARLibraryView(viewModel: viewModel)
                    } label: {
                        arCard(
                            title: "Human Cell",
                            description: "Explore cell biology in 3D",
                            icon: "circle.hexagongrid.fill",
                            color: .purple
                        )
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        ARLibraryView(viewModel: viewModel)
                    } label: {
                        arCard(
                            title: "Solar System",
                            description: "Journey through the planets",
                            icon: "globe.americas.fill",
                            color: .blue
                        )
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        ARLibraryView(viewModel: viewModel)
                    } label: {
                        arCard(
                            title: "Chemistry Lab",
                            description: "Visualize molecular structures",
                            icon: "flask.fill",
                            color: .teal
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .contentMargins(.horizontal, 16)
        }
    }

    // MARK: - Mathematics Section

    private var mathematicsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(title: "Mathematics", icon: "function", color: .green)

            LazyVGrid(columns: gridColumns, spacing: 14) {
                NavigationLink {
                    MathQuizView()
                } label: {
                    resourceCard(
                        title: "Math Quiz",
                        description: "Test your math skills",
                        icon: "function",
                        color1: .green,
                        color2: .mint
                    )
                }
                .buttonStyle(.plain)

                NavigationLink {
                    FractionBuilderView()
                } label: {
                    resourceCard(
                        title: "Fraction Builder",
                        description: "Master fractions visually",
                        icon: "circle.lefthalf.filled",
                        color1: .teal,
                        color2: .green
                    )
                }
                .buttonStyle(.plain)

                NavigationLink {
                    GeometryExplorerView()
                } label: {
                    resourceCard(
                        title: "Geometry Explorer",
                        description: "Shapes, angles & more",
                        icon: "triangle.fill",
                        color1: .blue,
                        color2: .cyan
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Science Section

    private var scienceSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(title: "Science", icon: "atom", color: .orange)

            LazyVGrid(columns: gridColumns, spacing: 14) {
                NavigationLink {
                    PeriodicTableView()
                } label: {
                    resourceCard(
                        title: "Periodic Table",
                        description: "Explore all elements",
                        icon: "tablecells.fill",
                        color1: .indigo,
                        color2: .purple
                    )
                }
                .buttonStyle(.plain)

                NavigationLink {
                    HumanBodyView()
                } label: {
                    resourceCard(
                        title: "Human Body",
                        description: "Interactive anatomy guide",
                        icon: "figure.stand",
                        color1: .pink,
                        color2: .red
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal)
        }
    }

    // MARK: - English Section

    private var englishSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(title: "English", icon: "textformat.abc", color: .cyan)

            LazyVGrid(columns: gridColumns, spacing: 14) {
                NavigationLink {
                    WordBuilderView()
                } label: {
                    resourceCard(
                        title: "Word Builder",
                        description: "Build words from letters",
                        icon: "textformat.abc",
                        color1: .cyan,
                        color2: .blue
                    )
                }
                .buttonStyle(.plain)

                NavigationLink {
                    SpellingBeeView()
                } label: {
                    resourceCard(
                        title: "Spelling Bee",
                        description: "Practice your spelling",
                        icon: "textformat",
                        color1: .yellow,
                        color2: .orange
                    )
                }
                .buttonStyle(.plain)

                NavigationLink {
                    GrammarQuestView()
                } label: {
                    resourceCard(
                        title: "Grammar Quest",
                        description: "Master grammar rules",
                        icon: "text.book.closed.fill",
                        color1: .purple,
                        color2: .pink
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal)
        }
    }

    // MARK: - French Section

    private var frenchSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(title: "French", icon: "globe.europe.africa.fill", color: .blue)

            LazyVGrid(columns: gridColumns, spacing: 14) {
                NavigationLink {
                    FrenchVocabView()
                } label: {
                    resourceCard(
                        title: "French Vocab",
                        description: "Learn French vocabulary",
                        icon: "character.book.closed.fill",
                        color1: .blue,
                        color2: .indigo
                    )
                }
                .buttonStyle(.plain)

                NavigationLink {
                    FrenchVerbView()
                } label: {
                    resourceCard(
                        title: "French Verbs",
                        description: "Conjugation practice",
                        icon: "text.word.spacing",
                        color1: .red,
                        color2: .blue
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Canadian Studies Section

    private var canadianStudiesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(title: "Canadian Studies", icon: "mappin.and.ellipse", color: .red)

            LazyVGrid(columns: gridColumns, spacing: 14) {
                NavigationLink {
                    CanadianHistoryTimelineView()
                } label: {
                    resourceCard(
                        title: "Canadian History",
                        description: "Interactive timeline of key events",
                        icon: "clock.arrow.circlepath",
                        color1: .red,
                        color2: .orange
                    )
                }
                .buttonStyle(.plain)

                NavigationLink {
                    CanadianGeographyView()
                } label: {
                    resourceCard(
                        title: "Canadian Geography",
                        description: "Provinces, capitals & more",
                        icon: "map.fill",
                        color1: .green,
                        color2: .teal
                    )
                }
                .buttonStyle(.plain)

                NavigationLink {
                    IndigenousPeoplesView()
                } label: {
                    resourceCard(
                        title: "Indigenous Peoples",
                        description: "History, culture & contributions",
                        icon: "leaf.fill",
                        color1: .orange,
                        color2: .brown
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Geography Section

    private var geographySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(title: "World Geography", icon: "globe.americas.fill", color: .teal)

            LazyVGrid(columns: gridColumns, spacing: 14) {
                NavigationLink {
                    WorldMapQuizView()
                } label: {
                    resourceCard(
                        title: "World Map Quiz",
                        description: "Test your geography knowledge",
                        icon: "globe.desk.fill",
                        color1: .teal,
                        color2: .green
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Games Section

    private var gamesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(title: "Games", icon: "gamecontroller.fill", color: .orange)

            LazyVGrid(columns: gridColumns, spacing: 14) {
                NavigationLink {
                    ChessGameView()
                } label: {
                    resourceCard(
                        title: "Chess",
                        description: "Strategic thinking & planning",
                        icon: "crown.fill",
                        color1: .purple,
                        color2: .indigo
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Tools Section

    private var toolsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(title: "Study Tools", icon: "wrench.and.screwdriver.fill", color: .gray)

            LazyVGrid(columns: gridColumns, spacing: 14) {
                NavigationLink {
                    FlashcardCreatorView()
                } label: {
                    resourceCard(
                        title: "Flashcard Creator",
                        description: "Create & study flashcards",
                        icon: "rectangle.on.rectangle.angled",
                        color1: .yellow,
                        color2: .orange
                    )
                }
                .buttonStyle(.plain)

                NavigationLink {
                    UnitConverterView()
                } label: {
                    resourceCard(
                        title: "Unit Converter",
                        description: "Convert between units",
                        icon: "arrow.left.arrow.right",
                        color1: .mint,
                        color2: .teal
                    )
                }
                .buttonStyle(.plain)

                NavigationLink {
                    TypingTutorView()
                } label: {
                    resourceCard(
                        title: "Typing Tutor",
                        description: "Improve your typing speed",
                        icon: "keyboard.fill",
                        color1: .gray,
                        color2: .blue
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Shared Components

    private var gridColumns: [GridItem] {
        [
            GridItem(.flexible(), spacing: 14),
            GridItem(.flexible(), spacing: 14)
        ]
    }

    private func resourceCard(title: String, description: String, icon: String, color1: Color, color2: Color) -> some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [color1, color2],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 56, height: 56)

                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(.white)
            }

            VStack(spacing: 4) {
                Text(title)
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)

                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .padding(.horizontal, 12)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

    private func arCard(title: String, description: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(color.gradient)
                    .frame(height: 100)

                VStack(spacing: 6) {
                    Image(systemName: icon)
                        .font(.system(size: 32, weight: .light))
                        .foregroundStyle(.white.opacity(0.9))

                    HStack(spacing: 4) {
                        Image(systemName: "arkit")
                            .font(.caption2)
                        Text("AR")
                            .font(.caption2.bold())
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.white.opacity(0.25), in: Capsule())
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)

                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            .padding(.horizontal, 4)
        }
        .frame(width: 170)
        .padding(10)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

    private func sectionHeader(title: String, icon: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundStyle(color)
            Text(title)
                .font(.title3.bold())
        }
        .padding(.horizontal)
    }
}
