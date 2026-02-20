import SwiftUI

// MARK: - Game Info Model

struct GameInfo: Identifiable {
    let id = UUID()
    let name: String
    let description: String
    let icon: String
    let gradientColors: [Color]
    let highScoreKey: String
    let highScoreLabel: String
    let destination: GameDestination
}

enum GameDestination {
    case mathBlaster
    case wordScramble
    case typingSpeed
    case chess
}

// MARK: - Game Center View

struct GameCenterView: View {
    @State private var hapticTrigger = false
    @State private var appeared = false

    @AppStorage("mathBlasterHighScore") private var mathHighScore: Int = 0
    @AppStorage("wordScrambleHighScore") private var wordHighScore: Int = 0
    @AppStorage("typingSpeedHighWPM") private var typingHighWPM: Int = 0

    private var games: [GameInfo] {
        [
            GameInfo(
                name: "Math Blaster",
                description: "Solve falling math problems before they hit the ground! Test your arithmetic with addition, subtraction, and multiplication.",
                icon: "function",
                gradientColors: [.blue, .purple],
                highScoreKey: "mathBlasterHighScore",
                highScoreLabel: "\(mathHighScore) pts",
                destination: .mathBlaster
            ),
            GameInfo(
                name: "Word Scramble",
                description: "Unscramble letters to form words from Science, History, Math, and English. Race against the clock with streak bonuses!",
                icon: "textformat.abc",
                gradientColors: [.purple, .pink],
                highScoreKey: "wordScrambleHighScore",
                highScoreLabel: "\(wordHighScore) pts",
                destination: .wordScramble
            ),
            GameInfo(
                name: "Typing Speed",
                description: "Test your typing speed with educational passages. Track your WPM and accuracy across different subjects.",
                icon: "keyboard.fill",
                gradientColors: [.green, .blue],
                highScoreKey: "typingSpeedHighWPM",
                highScoreLabel: "\(typingHighWPM) WPM",
                destination: .typingSpeed
            ),
            GameInfo(
                name: "Chess",
                description: "Play a full game of chess against an AI opponent. Choose from Easy, Medium, or Hard difficulty.",
                icon: "crown.fill",
                gradientColors: [.orange, .red],
                highScoreKey: "",
                highScoreLabel: "Strategic",
                destination: .chess
            ),
        ]
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                headerSection

                // Games grid
                LazyVStack(spacing: 16) {
                    ForEach(Array(games.enumerated()), id: \.element.id) { index, game in
                        NavigationLink {
                            destinationView(for: game.destination)
                        } label: {
                            GameCardView(game: game, hasHighScore: hasHighScore(game))
                        }
                        .buttonStyle(.plain)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 20)
                        .animation(.easeOut(duration: 0.4).delay(Double(index) * 0.1), value: appeared)
                    }
                }
                .padding(.horizontal)
            }
            .padding(.bottom, 30)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Game Center")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            withAnimation {
                appeared = true
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.orange, .red],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)

                Image(systemName: "gamecontroller.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(.white)
            }
            .padding(.top, 10)

            Text("Educational Games")
                .font(.title2.bold())

            Text("Learn while you play! Track your high scores\nand challenge yourself.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func destinationView(for destination: GameDestination) -> some View {
        switch destination {
        case .mathBlaster:
            MathBlasterGame()
        case .wordScramble:
            WordScrambleGame()
        case .typingSpeed:
            TypingSpeedGame()
        case .chess:
            ChessGameView()
        }
    }

    private func hasHighScore(_ game: GameInfo) -> Bool {
        switch game.destination {
        case .mathBlaster: return mathHighScore > 0
        case .wordScramble: return wordHighScore > 0
        case .typingSpeed: return typingHighWPM > 0
        case .chess: return false
        }
    }
}

// MARK: - Game Card View

struct GameCardView: View {
    let game: GameInfo
    let hasHighScore: Bool

    var body: some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: game.gradientColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 64, height: 64)

                Image(systemName: game.icon)
                    .font(.title2)
                    .foregroundStyle(.white)
            }

            // Info
            VStack(alignment: .leading, spacing: 6) {
                Text(game.name)
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text(game.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                // High score
                HStack(spacing: 6) {
                    if hasHighScore {
                        Image(systemName: "trophy.fill")
                            .font(.caption2)
                            .foregroundStyle(.yellow)
                        Text("Best: \(game.highScoreLabel)")
                            .font(.caption2.bold())
                            .foregroundStyle(.secondary)
                    } else {
                        Image(systemName: "play.circle.fill")
                            .font(.caption2)
                            .foregroundStyle(game.gradientColors.first ?? .blue)
                        Text(game.highScoreLabel)
                            .font(.caption2.bold())
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(16)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }
}

#Preview {
    NavigationStack {
        GameCenterView()
    }
}
