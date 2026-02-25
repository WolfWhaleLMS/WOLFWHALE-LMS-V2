import SwiftUI

// MARK: - Data Models

struct FrenchWord: Identifiable, Equatable {
    let id = UUID()
    let french: String
    let english: String
    let phonetic: String
    var mastered: Bool = false
    var wrongCount: Int = 0
    var lastSeen: Date?
}

struct VocabCategory: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    let color1: Color
    let color2: Color
    var words: [FrenchWord]
}

enum VocabMode {
    case flashcard
    case quiz
}

enum QuizDirection {
    case frenchToEnglish
    case englishToFrench
}

// MARK: - Main View

struct FrenchVocabView: View {
    @State private var categories: [VocabCategory] = FrenchVocabData.allCategories
    @State private var selectedCategory: VocabCategory?
    @State private var mode: VocabMode = .flashcard
    @State private var showingCategoryDetail = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                heroSection
                statsOverview
                categoriesGrid
            }
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("French Vocabulary")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedCategory) { category in
            NavigationStack {
                CategoryDetailView(
                    category: binding(for: category),
                    allCategories: $categories
                )
            }
        }
    }

    // MARK: - Hero

    private var heroSection: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24)
                .fill(
                    LinearGradient(
                        colors: [.blue, .indigo, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(height: 150)

            VStack(spacing: 8) {
                Image(systemName: "textbook.fill")
                    .font(.system(size: 36, weight: .medium))
                    .foregroundStyle(.white)
                    .symbolEffect(.pulse, options: .repeating)

                Text("Vocabulaire Francais")
                    .font(.title2.bold())
                    .foregroundStyle(.white)

                Text("Canadian French Immersion Curriculum")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.85))
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Stats Overview

    private var statsOverview: some View {
        HStack(spacing: 12) {
            statCard(
                title: "Total Words",
                value: "\(totalWords)",
                icon: "character.book.closed.fill",
                color: .blue
            )
            statCard(
                title: "Mastered",
                value: "\(masteredWords)",
                icon: "checkmark.seal.fill",
                color: .green
            )
            statCard(
                title: "Practicing",
                value: "\(totalWords - masteredWords)",
                icon: "arrow.triangle.2.circlepath",
                color: .orange
            )
        }
        .padding(.horizontal)
    }

    private var totalWords: Int {
        categories.reduce(0) { $0 + $1.words.count }
    }

    private var masteredWords: Int {
        categories.reduce(0) { sum, cat in
            sum + cat.words.filter { $0.mastered }.count
        }
    }

    private func statCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
            Text(value)
                .font(.title2.bold().monospacedDigit())
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

    // MARK: - Categories Grid

    private var categoriesGrid: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "rectangle.grid.2x2.fill")
                    .font(.headline)
                    .foregroundStyle(.indigo)
                Text("Categories")
                    .font(.title3.bold())
            }
            .padding(.horizontal)

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 14),
                GridItem(.flexible(), spacing: 14)
            ], spacing: 14) {
                ForEach(Array(categories.enumerated()), id: \.element.id) { index, category in
                    categoryCard(category: category, index: index)
                        .onTapGesture {
                            selectedCategory = categories[index]
                        }
                }
            }
            .padding(.horizontal)
        }
    }

    private func categoryCard(category: VocabCategory, index: Int) -> some View {
        let mastered = category.words.filter { $0.mastered }.count
        let total = category.words.count
        let progress = total > 0 ? Double(mastered) / Double(total) : 0

        return VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [category.color1, category.color2],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 52, height: 52)

                Image(systemName: category.icon)
                    .font(.title2)
                    .foregroundStyle(.white)
            }

            Text(category.name)
                .font(.subheadline.bold())
                .lineLimit(1)

            Text("\(mastered)/\(total) mastered")
                .font(.caption)
                .foregroundStyle(.secondary)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.quaternary).frame(height: 6)
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [category.color1, category.color2],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * progress, height: 6)
                }
            }
            .frame(height: 6)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .padding(.horizontal, 12)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

    private func binding(for category: VocabCategory) -> Binding<VocabCategory> {
        guard let index = categories.firstIndex(where: { $0.id == category.id }) else {
            return .constant(category)
        }
        return $categories[index]
    }
}

#Preview {
    NavigationStack {
        FrenchVocabView()
    }
}
