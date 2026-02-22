import Foundation

// MARK: - Assignment Template

/// A saved assignment template that can be reused to create new assignments.
/// Templates are stored locally via UserDefaults (JSON-encoded).
nonisolated struct AssignmentTemplate: Identifiable, Hashable, Sendable, Codable {
    let id: UUID
    var name: String
    var title: String
    var instructions: String
    var points: Int
    var rubricId: UUID?
    var courseName: String?          // informational, from original course
    var createdDate: Date
    var peerReviewEnabled: Bool
    var peerReviewsPerSubmission: Int

    init(
        id: UUID = UUID(),
        name: String,
        title: String,
        instructions: String,
        points: Int,
        rubricId: UUID? = nil,
        courseName: String? = nil,
        createdDate: Date = Date(),
        peerReviewEnabled: Bool = false,
        peerReviewsPerSubmission: Int = 2
    ) {
        self.id = id
        self.name = name
        self.title = title
        self.instructions = instructions
        self.points = points
        self.rubricId = rubricId
        self.courseName = courseName
        self.createdDate = createdDate
        self.peerReviewEnabled = peerReviewEnabled
        self.peerReviewsPerSubmission = peerReviewsPerSubmission
    }
}

// MARK: - Template Storage

enum AssignmentTemplateStore {
    private static let storageKey = "com.wolfwhale.assignmentTemplates"

    static func loadTemplates() -> [AssignmentTemplate] {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return [] }
        do {
            return try JSONDecoder().decode([AssignmentTemplate].self, from: data)
        } catch {
            #if DEBUG
            print("[AssignmentTemplateStore] Failed to decode templates: \(error)")
            #endif
            return []
        }
    }

    static func saveTemplates(_ templates: [AssignmentTemplate]) {
        do {
            let data = try JSONEncoder().encode(templates)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            #if DEBUG
            print("[AssignmentTemplateStore] Failed to encode templates: \(error)")
            #endif
        }
    }

    static func addTemplate(_ template: AssignmentTemplate) {
        var templates = loadTemplates()
        templates.insert(template, at: 0)
        saveTemplates(templates)
    }

    static func removeTemplate(id: UUID) {
        var templates = loadTemplates()
        templates.removeAll { $0.id == id }
        saveTemplates(templates)
    }
}
