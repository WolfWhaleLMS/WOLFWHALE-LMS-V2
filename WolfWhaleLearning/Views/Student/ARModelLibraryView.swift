import SwiftUI
import RealityKit
import ARKit

struct ARModelLibraryView: View {
    @State private var selectedCategory: ModelCategory = .all
    @State private var selectedModel: ARModel?
    @State private var showARView = false
    @State private var searchText = ""

    // MARK: - Model Category

    enum ModelCategory: String, CaseIterable, Identifiable {
        case all = "All"
        case anatomy = "Anatomy"
        case chemistry = "Chemistry"
        case physics = "Physics"
        case biology = "Biology"
        case geography = "Geography"
        case astronomy = "Astronomy"
        case engineering = "Engineering"

        var id: String { rawValue }

        var iconName: String {
            switch self {
            case .all: return "square.grid.2x2.fill"
            case .anatomy: return "figure.stand"
            case .chemistry: return "flask.fill"
            case .physics: return "atom"
            case .biology: return "leaf.fill"
            case .geography: return "globe.americas.fill"
            case .astronomy: return "moon.stars.fill"
            case .engineering: return "gearshape.2.fill"
            }
        }

        var color: Color {
            switch self {
            case .all: return .purple
            case .anatomy: return .red
            case .chemistry: return .blue
            case .physics: return .orange
            case .biology: return .green
            case .geography: return .teal
            case .astronomy: return .indigo
            case .engineering: return .gray
            }
        }
    }

    // MARK: - AR Model

    struct ARModel: Identifiable, Hashable {
        let id: UUID
        let name: String
        let description: String
        let category: ModelCategory
        let iconName: String
        let difficulty: String
        let fileSize: String
        let isDownloaded: Bool

        static let sampleModels: [ARModel] = [
            ARModel(id: UUID(), name: "Human Heart", description: "Interactive 3D model of the human heart showing all four chambers, valves, and major blood vessels. Rotate to explore the cardiac cycle.", category: .anatomy, iconName: "heart.fill", difficulty: "Intermediate", fileSize: "12 MB", isDownloaded: false),
            ARModel(id: UUID(), name: "DNA Double Helix", description: "Explore the structure of DNA with labeled nucleotides, hydrogen bonds, and sugar-phosphate backbone.", category: .biology, iconName: "circle.hexagongrid.fill", difficulty: "Advanced", fileSize: "8 MB", isDownloaded: false),
            ARModel(id: UUID(), name: "Water Molecule", description: "H2O molecular structure with electron clouds, bond angles, and polarity visualization.", category: .chemistry, iconName: "drop.fill", difficulty: "Basic", fileSize: "3 MB", isDownloaded: false),
            ARModel(id: UUID(), name: "Solar System", description: "Scale model of our solar system with orbital paths, relative planet sizes, and key facts.", category: .astronomy, iconName: "sun.max.fill", difficulty: "Intermediate", fileSize: "25 MB", isDownloaded: false),
            ARModel(id: UUID(), name: "Volcano Cross-Section", description: "See inside an active volcano with magma chamber, conduit, and layer identification.", category: .geography, iconName: "mountain.2.fill", difficulty: "Basic", fileSize: "15 MB", isDownloaded: false),
            ARModel(id: UUID(), name: "Newton's Cradle", description: "Interactive physics simulation demonstrating conservation of momentum and energy.", category: .physics, iconName: "circle.grid.3x3.fill", difficulty: "Basic", fileSize: "5 MB", isDownloaded: false),
            ARModel(id: UUID(), name: "Human Skeleton", description: "Full skeletal system with 206 labeled bones. Tap any bone for details.", category: .anatomy, iconName: "figure.stand", difficulty: "Advanced", fileSize: "30 MB", isDownloaded: false),
            ARModel(id: UUID(), name: "Periodic Table Element", description: "3D atomic structure viewer for any element showing electron shells and nucleus.", category: .chemistry, iconName: "atom", difficulty: "Intermediate", fileSize: "4 MB", isDownloaded: false),
            ARModel(id: UUID(), name: "Simple Motor", description: "Electric motor with labeled components: rotor, stator, commutator, and brushes.", category: .engineering, iconName: "bolt.fill", difficulty: "Intermediate", fileSize: "10 MB", isDownloaded: false),
            ARModel(id: UUID(), name: "Plant Cell", description: "Detailed plant cell with organelles including chloroplasts, vacuole, and cell wall.", category: .biology, iconName: "leaf.fill", difficulty: "Basic", fileSize: "7 MB", isDownloaded: false),
        ]
    }

    // MARK: - Computed Properties

    private var filteredModels: [ARModel] {
        var models = ARModel.sampleModels

        if selectedCategory != .all {
            models = models.filter { $0.category == selectedCategory }
        }

        if !searchText.isEmpty {
            models = models.filter {
                $0.name.localizedStandardContains(searchText) ||
                $0.description.localizedStandardContains(searchText) ||
                $0.category.rawValue.localizedStandardContains(searchText)
            }
        }

        return models
    }

    private let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    categoryFilterRow
                    modelGrid
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("AR Model Library")
            .searchable(text: $searchText, prompt: "Search models")
            .overlay {
                if filteredModels.isEmpty && !searchText.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                } else if filteredModels.isEmpty {
                    ContentUnavailableView(
                        "No Models",
                        systemImage: "arkit",
                        description: Text("No models available in this category yet.")
                    )
                }
            }
            .sheet(item: $selectedModel) { model in
                ARModelDetailSheet(model: model, showARView: $showARView)
            }
            .fullScreenCover(isPresented: $showARView) {
                if let model = selectedModel {
                    ARModelViewer(model: model)
                }
            }
        }
    }

    // MARK: - Category Filter Row

    private var categoryFilterRow: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 10) {
                ForEach(ModelCategory.allCases) { category in
                    categoryPill(category)
                }
            }
            .padding(.vertical, 4)
        }
        .scrollIndicators(.hidden)
        .contentMargins(.horizontal, 0)
    }

    private func categoryPill(_ category: ModelCategory) -> some View {
        let isSelected = selectedCategory == category

        return Button {
            withAnimation(.snappy(duration: 0.25)) {
                selectedCategory = category
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: category.iconName)
                    .font(.caption)
                Text(category.rawValue)
                    .font(.subheadline.weight(.medium))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .foregroundStyle(isSelected ? .white : category.color)
            .background(
                isSelected ? AnyShapeStyle(category.color.gradient) : AnyShapeStyle(.ultraThinMaterial),
                in: Capsule()
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(category.rawValue) category")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityHint(isSelected ? "Currently selected" : "Double tap to filter by \(category.rawValue)")
    }

    // MARK: - Model Grid

    private var modelGrid: some View {
        LazyVGrid(columns: columns, spacing: 14) {
            ForEach(filteredModels) { model in
                modelCard(model)
            }
        }
    }

    private func modelCard(_ model: ARModel) -> some View {
        Button {
            selectedModel = model
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                // Icon area
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(model.category.color.opacity(0.12))
                        .frame(height: 90)

                    Image(systemName: model.iconName)
                        .font(.system(size: 32))
                        .foregroundStyle(model.category.color.gradient)
                }

                // Name
                Text(model.name)
                    .font(.subheadline.bold())
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .foregroundStyle(.primary)

                // Category badge
                Text(model.category.rawValue)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(model.category.color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(model.category.color.opacity(0.12), in: Capsule())

                // Bottom row: difficulty + download
                HStack {
                    difficultyLabel(model.difficulty)
                    Spacer()
                    downloadIndicator(model)
                }
            }
            .padding(12)
            .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(model.name), \(model.category.rawValue), \(model.difficulty) difficulty, \(model.fileSize)")
        .accessibilityHint("Double tap to view details")
    }

    private func difficultyLabel(_ difficulty: String) -> some View {
        let color: Color = switch difficulty {
        case "Basic": .green
        case "Intermediate": .orange
        case "Advanced": .red
        default: .secondary
        }

        return Text(difficulty)
            .font(.caption2.weight(.medium))
            .foregroundStyle(color)
    }

    private func downloadIndicator(_ model: ARModel) -> some View {
        Group {
            if model.isDownloaded {
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
            } else {
                HStack(spacing: 3) {
                    Image(systemName: "arrow.down.circle")
                        .font(.caption)
                    Text(model.fileSize)
                        .font(.caption2)
                }
                .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Detail Sheet

struct ARModelDetailSheet: View {
    let model: ARModelLibraryView.ARModel
    @Binding var showARView: Bool
    @Environment(\.dismiss) private var dismiss

    private var difficultyColor: Color {
        switch model.difficulty {
        case "Basic": return .green
        case "Intermediate": return .orange
        case "Advanced": return .red
        default: return .secondary
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Hero area
                    ZStack {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(
                                LinearGradient(
                                    colors: [model.category.color.opacity(0.2), model.category.color.opacity(0.05)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(height: 200)

                        Image(systemName: model.iconName)
                            .font(.system(size: 64))
                            .foregroundStyle(model.category.color.gradient)
                    }

                    // Info section
                    VStack(alignment: .leading, spacing: 16) {
                        // Title and category
                        VStack(alignment: .leading, spacing: 6) {
                            Text(model.name)
                                .font(.title2.bold())

                            HStack(spacing: 8) {
                                Label(model.category.rawValue, systemImage: model.category.iconName)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(model.category.color)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(model.category.color.opacity(0.12), in: Capsule())

                                Label(model.difficulty, systemImage: "gauge.with.dots.needle.33percent")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(difficultyColor)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(difficultyColor.opacity(0.12), in: Capsule())
                            }
                        }

                        Divider()

                        // Description
                        VStack(alignment: .leading, spacing: 6) {
                            Text("About this model")
                                .font(.headline)
                            Text(model.description)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Divider()

                        // Details grid
                        HStack(spacing: 0) {
                            detailItem(icon: "arrow.down.circle.fill", label: "Size", value: model.fileSize, color: .blue)
                            Spacer()
                            detailItem(icon: "cube.fill", label: "Type", value: "3D Model", color: .purple)
                            Spacer()
                            detailItem(icon: "hand.draw.fill", label: "Interactive", value: "Yes", color: .orange)
                        }
                    }
                    .padding(.horizontal)

                    // View in AR button
                    Button {
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                            showARView = true
                        }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "arkit")
                                .font(.title3)
                            Text("View in AR")
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.purple)
                    .padding(.horizontal)
                    .accessibilityHint("Double tap to open the AR camera and place this model")

                    // Download note
                    if !model.isDownloaded {
                        HStack(spacing: 6) {
                            Image(systemName: "info.circle")
                                .font(.caption)
                            Text("This model will be downloaded (\(model.fileSize)) before viewing.")
                                .font(.caption)
                        }
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(model.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.large])
    }

    private func detailItem(icon: String, label: String, value: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
            Text(value)
                .font(.caption.bold())
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }
}
