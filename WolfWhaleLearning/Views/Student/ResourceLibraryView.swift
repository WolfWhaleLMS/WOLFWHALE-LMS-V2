import SwiftUI

struct ResourceLibraryView: View {
    @Bindable var viewModel: AppViewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    heroSection
                    arExperiencesSection
                    educationalGamesSection
                    interactiveDiagramsSection
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

    // MARK: - Educational Games Section

    private var educationalGamesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(title: "Educational Games", icon: "gamecontroller.fill", color: .orange)

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 14),
                GridItem(.flexible(), spacing: 14)
            ], spacing: 14) {
                NavigationLink {
                    ChessGameView()
                } label: {
                    gameCard(
                        title: "Chess",
                        description: "Strategic thinking & planning",
                        icon: "crown.fill",
                        color1: .purple,
                        color2: .indigo
                    )
                }
                .buttonStyle(.plain)

                gamePlaceholderCard(
                    title: "Math Quiz",
                    description: "Coming soon",
                    icon: "function",
                    color: .green
                )

                gamePlaceholderCard(
                    title: "Word Builder",
                    description: "Coming soon",
                    icon: "textformat.abc",
                    color: .cyan
                )

                gamePlaceholderCard(
                    title: "Science Trivia",
                    description: "Coming soon",
                    icon: "atom",
                    color: .orange
                )
            }
            .padding(.horizontal)
        }
    }

    private func gameCard(title: String, description: String, icon: String, color1: Color, color2: Color) -> some View {
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

    private func gamePlaceholderCard(title: String, description: String, icon: String, color: Color) -> some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.2))
                    .frame(width: 56, height: 56)

                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color.opacity(0.5))
            }

            VStack(spacing: 4) {
                Text(title)
                    .font(.subheadline.bold())
                    .foregroundStyle(.secondary)

                Text(description)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .padding(.horizontal, 12)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
        .opacity(0.6)
    }

    // MARK: - Interactive Diagrams Section

    private var interactiveDiagramsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(title: "Interactive Diagrams", icon: "chart.line.uptrend.xyaxis", color: .teal)

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 14),
                GridItem(.flexible(), spacing: 14)
            ], spacing: 14) {
                NavigationLink {
                    CanadianHistoryTimelineView()
                } label: {
                    diagramCard(
                        title: "Canadian History",
                        description: "Explore key events on an interactive timeline",
                        icon: "clock.arrow.circlepath",
                        color1: .red,
                        color2: .orange
                    )
                }
                .buttonStyle(.plain)

                diagramPlaceholderCard(
                    title: "Human Anatomy",
                    description: "Coming soon",
                    icon: "figure.stand",
                    color: .pink
                )

                diagramPlaceholderCard(
                    title: "Periodic Table",
                    description: "Coming soon",
                    icon: "tablecells.fill",
                    color: .indigo
                )

                diagramPlaceholderCard(
                    title: "World Geography",
                    description: "Coming soon",
                    icon: "map.fill",
                    color: .green
                )
            }
            .padding(.horizontal)
        }
    }

    private func diagramCard(title: String, description: String, icon: String, color1: Color, color2: Color) -> some View {
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

    private func diagramPlaceholderCard(title: String, description: String, icon: String, color: Color) -> some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.2))
                    .frame(width: 56, height: 56)

                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color.opacity(0.5))
            }

            VStack(spacing: 4) {
                Text(title)
                    .font(.subheadline.bold())
                    .foregroundStyle(.secondary)

                Text(description)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .padding(.horizontal, 12)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
        .opacity(0.6)
    }

    // MARK: - Helpers

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
