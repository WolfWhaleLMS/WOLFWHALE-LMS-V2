import Foundation
import Observation

// MARK: - SearchService

@MainActor
@Observable
final class SearchService {

    // MARK: - Public State

    var error: String?
    var isLoading = false
    var results: [SearchCategory: [SearchResult]] = [:]
    var recentSearches: [String] = []

    var totalResultCount: Int {
        results.values.reduce(0) { $0 + $1.count }
    }

    // MARK: - Private

    private static let recentSearchesKey = "wolfwhale_recent_searches"
    private static let maxRecentSearches = 10

    // MARK: - Initializer

    init() {
        loadRecentSearches()
    }

    // MARK: - Search

    /// Performs a client-side search across all entity types and groups results by category.
    func search(
        query: String,
        courses: [Course],
        assignments: [Assignment],
        conversations: [Conversation],
        users: [ProfileDTO],
        lessons: [Lesson]
    ) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            clearResults()
            return
        }

        isLoading = true
        error = nil

        let lowered = trimmed.lowercased()
        var grouped: [SearchCategory: [SearchResult]] = [:]

        // -- Courses --
        let courseResults = courses.compactMap { course -> SearchResult? in
            let titleMatch = course.title.lowercased().contains(lowered)
            let descMatch = course.description.lowercased().contains(lowered)
            let teacherMatch = course.teacherName.lowercased().contains(lowered)
            guard titleMatch || descMatch || teacherMatch else { return nil }
            return SearchResult(
                id: UUID(),
                title: course.title,
                subtitle: "Taught by \(course.teacherName)",
                category: .courses,
                icon: course.iconSystemName,
                entityId: course.id
            )
        }
        if !courseResults.isEmpty {
            grouped[.courses] = courseResults
        }

        // -- Assignments --
        let assignmentResults = assignments.compactMap { assignment -> SearchResult? in
            let titleMatch = assignment.title.lowercased().contains(lowered)
            let descMatch = assignment.instructions.lowercased().contains(lowered)
            let courseMatch = assignment.courseName.lowercased().contains(lowered)
            guard titleMatch || descMatch || courseMatch else { return nil }
            return SearchResult(
                id: UUID(),
                title: assignment.title,
                subtitle: "\(assignment.courseName) \u{2022} \(assignment.statusText)",
                category: .assignments,
                icon: SearchCategory.assignments.iconName,
                entityId: assignment.id
            )
        }
        if !assignmentResults.isEmpty {
            grouped[.assignments] = assignmentResults
        }

        // -- Messages / Conversations --
        let messageResults = conversations.compactMap { conversation -> SearchResult? in
            let titleMatch = conversation.title.lowercased().contains(lowered)
            let lastMsgMatch = conversation.lastMessage.lowercased().contains(lowered)
            let participantMatch = conversation.participantNames.contains { $0.lowercased().contains(lowered) }
            guard titleMatch || lastMsgMatch || participantMatch else { return nil }
            let subtitle: String
            if conversation.lastMessage.isEmpty {
                subtitle = conversation.participantNames.joined(separator: ", ")
            } else {
                let truncated = conversation.lastMessage.prefix(60)
                subtitle = String(truncated)
            }
            return SearchResult(
                id: UUID(),
                title: conversation.title,
                subtitle: subtitle,
                category: .messages,
                icon: conversation.participantNames.count > 2
                    ? "person.3.fill"
                    : SearchCategory.messages.iconName,
                entityId: conversation.id
            )
        }
        if !messageResults.isEmpty {
            grouped[.messages] = messageResults
        }

        // -- People --
        let peopleResults = users.compactMap { profile -> SearchResult? in
            let fullName = "\(profile.firstName ?? "") \(profile.lastName ?? "")"
            let nameMatch = fullName.lowercased().contains(lowered)
            let emailMatch = profile.email.lowercased().contains(lowered)
            let displayNameMatch = (profile.fullName ?? "").lowercased().contains(lowered)
            guard nameMatch || emailMatch || displayNameMatch else { return nil }
            let displayName = (profile.fullName ?? fullName).trimmingCharacters(in: .whitespaces)
            let subtitle: String
            if !profile.role.isEmpty {
                subtitle = profile.role.capitalized
            } else if !profile.email.isEmpty {
                subtitle = profile.email
            } else {
                subtitle = "Member"
            }
            return SearchResult(
                id: UUID(),
                title: displayName.isEmpty ? profile.email : displayName,
                subtitle: subtitle,
                category: .people,
                icon: "person.crop.circle.fill",
                entityId: profile.id
            )
        }
        if !peopleResults.isEmpty {
            grouped[.people] = peopleResults
        }

        // -- Lessons --
        let lessonResults = lessons.compactMap { lesson -> SearchResult? in
            let titleMatch = lesson.title.lowercased().contains(lowered)
            let contentMatch = lesson.content.lowercased().contains(lowered)
            guard titleMatch || contentMatch else { return nil }
            return SearchResult(
                id: UUID(),
                title: lesson.title,
                subtitle: "\(lesson.type.rawValue) \u{2022} \(lesson.duration) min",
                category: .lessons,
                icon: lesson.type.iconName,
                entityId: lesson.id
            )
        }
        if !lessonResults.isEmpty {
            grouped[.lessons] = lessonResults
        }

        results = grouped
        isLoading = false

        saveRecentSearch(trimmed)
    }

    // MARK: - Clear

    func clearResults() {
        results = [:]
        error = nil
    }

    func clearRecentSearches() {
        recentSearches = []
        UserDefaults.standard.removeObject(forKey: Self.recentSearchesKey)
    }

    // MARK: - Recent Searches Persistence

    func loadRecentSearches() {
        if let saved = UserDefaults.standard.stringArray(forKey: Self.recentSearchesKey) {
            recentSearches = saved
        }
    }

    func saveRecentSearch(_ query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // Remove duplicate if it already exists, then insert at front
        recentSearches.removeAll { $0.lowercased() == trimmed.lowercased() }
        recentSearches.insert(trimmed, at: 0)

        // Cap at max
        if recentSearches.count > Self.maxRecentSearches {
            recentSearches = Array(recentSearches.prefix(Self.maxRecentSearches))
        }

        UserDefaults.standard.set(recentSearches, forKey: Self.recentSearchesKey)
    }
}
