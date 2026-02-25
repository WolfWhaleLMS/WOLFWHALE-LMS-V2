import CoreSpotlight
import UniformTypeIdentifiers
import Observation

#if canImport(UIKit)
import UIKit
#endif

// MARK: - SpotlightDeepLink

/// Represents a deep-link target resolved from a Spotlight search result.
nonisolated enum SpotlightDeepLink: Sendable {
    case course(UUID)
    case assignment(UUID)
    case quiz(UUID)
}

// MARK: - SpotlightService

@MainActor
@Observable
final class SpotlightService {

    // MARK: Public state

    var isIndexing = false
    var indexedItemCount = 0
    var error: String?

    // MARK: Private constants

    private static let domainCourse = "com.wolfwhale.lms.course"
    private static let domainAssignment = "com.wolfwhale.lms.assignment"
    private static let domainQuiz = "com.wolfwhale.lms.quiz"

    // MARK: - Initializer

    init() {
        indexedItemCount = UserDefaults.standard.integer(forKey: UserDefaultsKeys.spotlightIndexedCount)
    }

    // MARK: - Bulk Index All Content

    /// Indexes all courses, assignments, and quizzes in a single batch operation.
    /// Call this after login or whenever the full data set is loaded.
    func indexAllContent(courses: [Course], assignments: [Assignment], quizzes: [Quiz]) async {
        #if os(iOS)
        guard !isIndexing else { return }
        isIndexing = true
        error = nil

        var items: [CSSearchableItem] = []

        for course in courses {
            items.append(makeSearchableItem(for: course))
        }
        for assignment in assignments {
            items.append(makeSearchableItem(for: assignment))
        }
        for quiz in quizzes {
            items.append(makeSearchableItem(for: quiz))
        }

        do {
            try await CSSearchableIndex.default().indexSearchableItems(items)
            indexedItemCount = items.count
            persistIndexedCount()
            #if DEBUG
            print("[SpotlightService] Indexed \(items.count) items")
            #endif
        } catch {
            self.error = error.localizedDescription
            #if DEBUG
            print("[SpotlightService] Bulk index failed: \(error)")
            #endif
        }

        isIndexing = false
        #endif
    }

    // MARK: - Index Single Items

    /// Index a single course when it is created or updated.
    func indexCourse(_ course: Course) async {
        #if os(iOS)
        let item = makeSearchableItem(for: course)
        await indexSingleItem(item)
        #endif
    }

    /// Index a single assignment when it is created or updated.
    func indexAssignment(_ assignment: Assignment) async {
        #if os(iOS)
        let item = makeSearchableItem(for: assignment)
        await indexSingleItem(item)
        #endif
    }

    /// Index a single quiz when it is created or updated.
    func indexQuiz(_ quiz: Quiz) async {
        #if os(iOS)
        let item = makeSearchableItem(for: quiz)
        await indexSingleItem(item)
        #endif
    }

    // MARK: - Deindex

    /// Remove a single item from the Spotlight index by its unique identifier.
    /// Identifiers follow the format: "course:{uuid}", "assignment:{uuid}", "quiz:{uuid}".
    func deindexItem(identifier: String) async {
        #if os(iOS)
        do {
            try await CSSearchableIndex.default().deleteSearchableItems(withIdentifiers: [identifier])
            indexedItemCount = max(0, indexedItemCount - 1)
            persistIndexedCount()
            #if DEBUG
            print("[SpotlightService] Deindexed item: \(identifier)")
            #endif
        } catch {
            self.error = error.localizedDescription
            #if DEBUG
            print("[SpotlightService] Deindex failed for \(identifier): \(error)")
            #endif
        }
        #endif
    }

    /// Remove all items belonging to a specific domain (e.g. all courses).
    func deindexDomain(_ domain: String) async {
        #if os(iOS)
        do {
            try await CSSearchableIndex.default().deleteSearchableItems(withDomainIdentifiers: [domain])
            #if DEBUG
            print("[SpotlightService] Deindexed domain: \(domain)")
            #endif
        } catch {
            self.error = error.localizedDescription
            #if DEBUG
            print("[SpotlightService] Deindex domain failed for \(domain): \(error)")
            #endif
        }
        #endif
    }

    /// Remove all WolfWhale content from the Spotlight index.
    /// Call this on logout to clear user-specific data.
    func deindexAllContent() async {
        #if os(iOS)
        do {
            try await CSSearchableIndex.default().deleteSearchableItems(withDomainIdentifiers: [
                Self.domainCourse,
                Self.domainAssignment,
                Self.domainQuiz
            ])
            indexedItemCount = 0
            persistIndexedCount()
            error = nil
            #if DEBUG
            print("[SpotlightService] Deindexed all content")
            #endif
        } catch {
            self.error = error.localizedDescription
            #if DEBUG
            print("[SpotlightService] Deindex all failed: \(error)")
            #endif
        }
        #endif
    }

    // MARK: - Reindex

    /// Clears the entire index and re-indexes all provided content from scratch.
    /// Useful when data may have changed significantly (e.g. after a full sync).
    func reindexAllContent(courses: [Course], assignments: [Assignment], quizzes: [Quiz]) async {
        #if os(iOS)
        await deindexAllContent()
        await indexAllContent(courses: courses, assignments: assignments, quizzes: quizzes)
        #endif
    }

    // MARK: - Deep Link Handling

    /// Parses an `NSUserActivity` from a Spotlight search result into a `SpotlightDeepLink`.
    /// Returns `nil` if the activity is not a Spotlight continuation or the identifier is unrecognized.
    nonisolated func handleSpotlightActivity(_ activity: NSUserActivity) -> SpotlightDeepLink? {
        guard activity.activityType == CSSearchableItemActionType,
              let identifier = activity.userInfo?[CSSearchableItemActivityIdentifier] as? String else {
            return nil
        }
        return parseDeepLink(from: identifier)
    }

    /// Parses a Spotlight unique identifier string into a `SpotlightDeepLink`.
    nonisolated func parseDeepLink(from identifier: String) -> SpotlightDeepLink? {
        let components = identifier.split(separator: ":", maxSplits: 1)
        guard components.count == 2,
              let uuid = UUID(uuidString: String(components[1])) else {
            return nil
        }

        switch String(components[0]) {
        case "course":
            return .course(uuid)
        case "assignment":
            return .assignment(uuid)
        case "quiz":
            return .quiz(uuid)
        default:
            return nil
        }
    }

    // MARK: - Private Helpers

    #if os(iOS)

    /// Index a single `CSSearchableItem` and update the count.
    private func indexSingleItem(_ item: CSSearchableItem) async {
        error = nil
        do {
            try await CSSearchableIndex.default().indexSearchableItems([item])
            indexedItemCount += 1
            persistIndexedCount()
        } catch {
            self.error = error.localizedDescription
            #if DEBUG
            print("[SpotlightService] Index single item failed: \(error)")
            #endif
        }
    }

    /// Persist the indexed item count to UserDefaults so it survives app restarts.
    private func persistIndexedCount() {
        UserDefaults.standard.set(indexedItemCount, forKey: UserDefaultsKeys.spotlightIndexedCount)
    }

    // MARK: - Searchable Item Builders

    private func makeSearchableItem(for course: Course) -> CSSearchableItem {
        let attributes = CSSearchableItemAttributeSet(contentType: UTType.content)
        attributes.title = course.title
        attributes.contentDescription = buildCourseDescription(course)
        attributes.keywords = buildCourseKeywords(course)
        attributes.thumbnailData = systemImageThumbnailData(named: course.iconSystemName)
        attributes.creator = course.teacherName
        attributes.subject = "Course"

        let identifier = "course:\(course.id.uuidString)"
        let item = CSSearchableItem(
            uniqueIdentifier: identifier,
            domainIdentifier: Self.domainCourse,
            attributeSet: attributes
        )
        // Courses rarely expire; set a long expiration.
        item.expirationDate = Calendar.current.date(byAdding: .year, value: 1, to: Date())
        return item
    }

    private func makeSearchableItem(for assignment: Assignment) -> CSSearchableItem {
        let attributes = CSSearchableItemAttributeSet(contentType: UTType.content)
        attributes.title = assignment.title
        attributes.contentDescription = buildAssignmentDescription(assignment)
        attributes.keywords = buildAssignmentKeywords(assignment)
        attributes.subject = "Assignment"
        attributes.dueDate = assignment.dueDate

        // Use a book icon for assignments
        attributes.thumbnailData = systemImageThumbnailData(named: "doc.text.fill")

        let identifier = "assignment:\(assignment.id.uuidString)"
        let item = CSSearchableItem(
            uniqueIdentifier: identifier,
            domainIdentifier: Self.domainAssignment,
            attributeSet: attributes
        )
        // Expire assignments 30 days after their due date.
        item.expirationDate = Calendar.current.date(byAdding: .day, value: 30, to: assignment.dueDate)
        return item
    }

    private func makeSearchableItem(for quiz: Quiz) -> CSSearchableItem {
        let attributes = CSSearchableItemAttributeSet(contentType: UTType.content)
        attributes.title = quiz.title
        attributes.contentDescription = buildQuizDescription(quiz)
        attributes.keywords = buildQuizKeywords(quiz)
        attributes.subject = "Quiz"
        attributes.dueDate = quiz.dueDate

        // Use a quiz icon
        attributes.thumbnailData = systemImageThumbnailData(named: "questionmark.circle.fill")

        let identifier = "quiz:\(quiz.id.uuidString)"
        let item = CSSearchableItem(
            uniqueIdentifier: identifier,
            domainIdentifier: Self.domainQuiz,
            attributeSet: attributes
        )
        // Expire quizzes 30 days after their due date.
        item.expirationDate = Calendar.current.date(byAdding: .day, value: 30, to: quiz.dueDate)
        return item
    }

    // MARK: - Description Builders

    private func buildCourseDescription(_ course: Course) -> String {
        var parts: [String] = []
        parts.append("Taught by \(course.teacherName)")
        if !course.description.isEmpty {
            parts.append(course.description)
        }
        parts.append("\(course.modules.count) module\(course.modules.count == 1 ? "" : "s")")
        parts.append("\(course.enrolledStudentCount) student\(course.enrolledStudentCount == 1 ? "" : "s") enrolled")
        if course.progress > 0 {
            parts.append("\(Int(course.progress * 100))% complete")
        }
        return parts.joined(separator: " - ")
    }

    private func buildAssignmentDescription(_ assignment: Assignment) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short

        var parts: [String] = []
        parts.append(assignment.courseName)
        parts.append("Due: \(formatter.string(from: assignment.dueDate))")
        parts.append("\(assignment.points) point\(assignment.points == 1 ? "" : "s")")
        if !assignment.instructions.isEmpty {
            // Truncate long instructions for the description
            let truncated = assignment.instructions.prefix(200)
            parts.append(String(truncated))
        }
        if assignment.isSubmitted {
            parts.append("Submitted")
        }
        return parts.joined(separator: " - ")
    }

    private func buildQuizDescription(_ quiz: Quiz) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short

        var parts: [String] = []
        parts.append(quiz.courseName)
        parts.append("Due: \(formatter.string(from: quiz.dueDate))")
        parts.append("\(quiz.questions.count) question\(quiz.questions.count == 1 ? "" : "s")")
        parts.append("\(quiz.timeLimit) min time limit")
        if quiz.isCompleted {
            if let score = quiz.score {
                parts.append("Score: \(Int(score))%")
            } else {
                parts.append("Completed")
            }
        }
        return parts.joined(separator: " - ")
    }

    // MARK: - Keyword Builders

    private func buildCourseKeywords(_ course: Course) -> [String] {
        var keywords = [
            "course",
            "class",
            course.title,
            course.teacherName,
            "WolfWhale",
            "LMS",
            "learning"
        ]
        // Add module titles as keywords for broader searchability
        for module in course.modules {
            keywords.append(module.title)
        }
        // Add individual words from the course title
        keywords.append(contentsOf: course.title.split(separator: " ").map(String.init))
        return keywords
    }

    private func buildAssignmentKeywords(_ assignment: Assignment) -> [String] {
        var keywords = [
            "assignment",
            "homework",
            assignment.title,
            assignment.courseName,
            "WolfWhale",
            "LMS",
            "due"
        ]
        if assignment.isSubmitted {
            keywords.append("submitted")
        }
        if assignment.isOverdue {
            keywords.append("overdue")
        }
        // Add individual words from the assignment title
        keywords.append(contentsOf: assignment.title.split(separator: " ").map(String.init))
        return keywords
    }

    private func buildQuizKeywords(_ quiz: Quiz) -> [String] {
        var keywords = [
            "quiz",
            "test",
            "exam",
            quiz.title,
            quiz.courseName,
            "WolfWhale",
            "LMS"
        ]
        if quiz.isCompleted {
            keywords.append("completed")
        }
        // Add individual words from the quiz title
        keywords.append(contentsOf: quiz.title.split(separator: " ").map(String.init))
        return keywords
    }

    // MARK: - Thumbnail Generation

    /// Renders an SF Symbol into PNG thumbnail data for Spotlight results.
    /// Returns `nil` on non-UIKit platforms or if rendering fails.
    private func systemImageThumbnailData(named systemName: String) -> Data? {
        #if canImport(UIKit)
        let size = CGSize(width: 60, height: 60)
        let config = UIImage.SymbolConfiguration(pointSize: 36, weight: .medium)
        guard let image = UIImage(systemName: systemName, withConfiguration: config) else {
            return nil
        }

        let renderer = UIGraphicsImageRenderer(size: size)
        let rendered = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        return rendered.pngData()
        #else
        return nil
        #endif
    }

    #endif
}
