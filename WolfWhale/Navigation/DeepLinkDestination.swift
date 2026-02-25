import Foundation

/// Represents all possible deep-link destinations throughout the app.
/// Used by ``DeepLinkHandler`` to translate incoming URLs and user activities
/// into a typed navigation target that ``AppViewModel`` can consume.
nonisolated enum DeepLinkDestination: Hashable, Sendable {
    case assignments
    case grades
    case schedule
    case course(UUID)
    case assignment(UUID)
    case quiz(UUID)
    case tools
    case wellness
    case sharePlay
    case recommendations
}
