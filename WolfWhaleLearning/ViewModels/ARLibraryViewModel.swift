import SwiftUI

@Observable @MainActor
class ARLibraryViewModel {
    var resources: [ARResource] = []
    var searchText: String = ""
    var selectedCategory: ARResourceCategory?
    var selectedResource: ARResource?

    var filteredResources: [ARResource] {
        var result = resources
        if let category = selectedCategory {
            result = result.filter { $0.category == category }
        }
        if !searchText.isEmpty {
            result = result.filter {
                $0.title.localizedStandardContains(searchText) ||
                $0.subtitle.localizedStandardContains(searchText) ||
                $0.description.localizedStandardContains(searchText) ||
                $0.tags.contains(where: { $0.localizedStandardContains(searchText) }) ||
                $0.category.rawValue.localizedStandardContains(searchText)
            }
        }
        return result
    }

    var featuredResources: [ARResource] {
        Array(resources.prefix(3))
    }

    var categories: [ARResourceCategory] {
        let used = Set(resources.map(\.category))
        return ARResourceCategory.allCases.filter { used.contains($0) }
    }

    init() {
        loadBuiltInResources()
    }

    func resourcesMatching(keywords: [String]) -> [ARResource] {
        guard !keywords.isEmpty else { return [] }
        return resources.filter { resource in
            keywords.contains { keyword in
                resource.linkedLessonKeywords.contains(where: { $0.localizedStandardContains(keyword) }) ||
                resource.tags.contains(where: { $0.localizedStandardContains(keyword) }) ||
                resource.title.localizedStandardContains(keyword)
            }
        }
    }

    private func loadBuiltInResources() {
        resources = [
            ARResource(
                id: UUID(uuidString: "A1B2C3D4-E5F6-7890-ABCD-EF1234567890")!,
                title: "Human Cell",
                subtitle: "Interactive Animal Cell",
                description: "Explore a fully labeled 3D animal cell. Pinch to zoom, rotate to examine from any angle, and tap organelles to learn about the nucleus, mitochondria, endoplasmic reticulum, Golgi apparatus, and more. Each organelle includes detailed descriptions and fun facts.",
                category: .biology,
                subject: .science,
                iconSystemName: "circle.hexagongrid.fill",
                colorName: "green",
                experienceType: .humanCell,
                tags: ["cell", "biology", "organelle", "nucleus", "mitochondria", "anatomy", "microscope"],
                gradeLevel: "6-12",
                estimatedDuration: 10,
                linkedLessonKeywords: ["cell", "biology", "organelle", "nucleus", "mitochondria", "cytoplasm", "membrane"]
            )
        ]
    }
}
