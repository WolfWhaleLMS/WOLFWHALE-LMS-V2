import SwiftUI

// MARK: - SearchCategory

nonisolated enum SearchCategory: String, CaseIterable, Sendable {
    case courses
    case assignments
    case messages
    case people
    case lessons

    var displayName: String {
        switch self {
        case .courses: "Courses"
        case .assignments: "Assignments"
        case .messages: "Messages"
        case .people: "People"
        case .lessons: "Lessons"
        }
    }

    var iconName: String {
        switch self {
        case .courses: "book.fill"
        case .assignments: "doc.text.fill"
        case .messages: "bubble.left.and.bubble.right.fill"
        case .people: "person.2.fill"
        case .lessons: "play.rectangle.fill"
        }
    }

    var color: Color {
        switch self {
        case .courses: .indigo
        case .assignments: .orange
        case .messages: .purple
        case .people: .teal
        case .lessons: .pink
        }
    }
}

// MARK: - SearchResult

nonisolated struct SearchResult: Identifiable, Hashable, Sendable {
    let id: UUID
    let title: String
    let subtitle: String
    let category: SearchCategory
    let icon: String
    let entityId: UUID
}
