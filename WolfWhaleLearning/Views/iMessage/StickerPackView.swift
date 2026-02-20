import SwiftUI

// MARK: - Sticker Pack View
// This view previews the WolfWhale sticker pack from within the main app.
// Students can browse available stickers here. The actual iMessage sticker pack
// requires a separate Sticker Pack Extension target in Xcode.

struct StickerPackView: View {
    @State private var selectedSticker: Sticker?
    @State private var appeared = false

    private let columns = [
        GridItem(.adaptive(minimum: 120, maximum: 140), spacing: 16)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    headerSection
                    instructionsBanner
                    stickerGrid
                }
                .padding(.horizontal)
                .padding(.bottom, 32)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Sticker Pack")
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 24)
                    .fill(
                        LinearGradient(
                            colors: [.purple, .blue, .indigo],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(height: 160)

                VStack(spacing: 8) {
                    HStack(spacing: 12) {
                        Image(systemName: "message.fill")
                            .font(.system(size: 32, weight: .medium))
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .bold))
                        Image(systemName: "face.smiling.fill")
                            .font(.system(size: 32, weight: .medium))
                    }
                    .foregroundStyle(.white)
                    .symbolEffect(.pulse, options: .repeating)

                    Text("WolfWhale Stickers")
                        .font(.title2.bold())
                        .foregroundStyle(.white)

                    Text("12 school-themed stickers for iMessage")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.85))
                }
            }
        }
        .padding(.top, 8)
    }

    // MARK: - Instructions Banner

    private var instructionsBanner: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "info.circle.fill")
                    .foregroundStyle(.blue)
                Text("How to Use")
                    .font(.headline)
            }

            Text("Share these stickers in iMessage! To add: Open Messages \u{203A} tap the **+** button \u{203A} select **WolfWhale stickers**.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 16) {
                stepBadge(number: 1, text: "Open Messages")
                stepBadge(number: 2, text: "Tap + button")
                stepBadge(number: 3, text: "Pick sticker")
            }
            .padding(.top, 4)
        }
        .padding(16)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

    private func stepBadge(number: Int, text: String) -> some View {
        VStack(spacing: 6) {
            Text("\(number)")
                .font(.caption.bold())
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(.purple, in: Circle())

            Text(text)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Sticker Grid

    private var stickerGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "square.grid.2x2.fill")
                    .foregroundStyle(.purple)
                Text("All Stickers")
                    .font(.headline)
                Spacer()
                Text("\(Sticker.allStickers.count) stickers")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(Array(Sticker.allStickers.enumerated()), id: \.element.id) { index, sticker in
                    stickerCell(sticker, index: index)
                }
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                appeared = true
            }
        }
    }

    // MARK: - Sticker Cell

    private func stickerCell(_ sticker: Sticker, index: Int) -> some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            colors: sticker.gradientColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)
                    .shadow(color: sticker.gradientColors.first?.opacity(0.35) ?? .clear, radius: 8, y: 4)

                Image(systemName: sticker.symbolName)
                    .font(.system(size: 44, weight: .medium))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.15), radius: 2, y: 1)
            }
            .scaleEffect(appeared ? 1.0 : 0.5)
            .opacity(appeared ? 1.0 : 0)
            .animation(
                .spring(response: 0.5, dampingFraction: 0.7).delay(Double(index) * 0.05),
                value: appeared
            )
            .onTapGesture {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    selectedSticker = sticker
                }
            }

            Text(sticker.name)
                .font(.caption.weight(.medium))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(sticker.name) sticker")
        .accessibilityHint("Tap to preview")
    }
}

// MARK: - Sticker Model

struct Sticker: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let symbolName: String
    let gradientColors: [Color]

    static let allStickers: [Sticker] = [
        Sticker(
            name: "Graduation Cap",
            symbolName: "graduationcap.fill",
            gradientColors: [.purple, .indigo]
        ),
        Sticker(
            name: "Study Time",
            symbolName: "book.fill",
            gradientColors: [.blue, .cyan]
        ),
        Sticker(
            name: "Gold Star",
            symbolName: "star.fill",
            gradientColors: [.yellow, Color(red: 0.85, green: 0.65, blue: 0.13)]
        ),
        Sticker(
            name: "A+ Grade",
            symbolName: "a.circle.fill",
            gradientColors: [.green, .mint]
        ),
        Sticker(
            name: "Brain Power",
            symbolName: "brain.head.profile",
            gradientColors: [.pink, .purple]
        ),
        Sticker(
            name: "Homework Time",
            symbolName: "pencil.and.ruler.fill",
            gradientColors: [.orange, Color(red: 0.95, green: 0.55, blue: 0.15)]
        ),
        Sticker(
            name: "Winner",
            symbolName: "trophy.fill",
            gradientColors: [Color(red: 0.85, green: 0.65, blue: 0.13), .yellow]
        ),
        Sticker(
            name: "On Fire",
            symbolName: "flame.fill",
            gradientColors: [.orange, .red]
        ),
        Sticker(
            name: "Love Learning",
            symbolName: "heart.fill",
            gradientColors: [.red, .pink]
        ),
        Sticker(
            name: "Great Idea",
            symbolName: "lightbulb.fill",
            gradientColors: [.yellow, .orange]
        ),
        Sticker(
            name: "Thumbs Up",
            symbolName: "hand.thumbsup.fill",
            gradientColors: [.blue, .indigo]
        ),
        Sticker(
            name: "Happy Student",
            symbolName: "face.smiling.fill",
            gradientColors: [.green, .teal]
        )
    ]
}

// MARK: - Preview

#Preview {
    StickerPackView()
}
