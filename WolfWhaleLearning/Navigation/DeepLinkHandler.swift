import Foundation
import CoreSpotlight

/// Parses incoming deep-link URLs (from widgets, notifications, etc.) and
/// `NSUserActivity` instances (from Spotlight) into ``DeepLinkDestination``
/// values, then updates navigation state on ``AppViewModel``.
@MainActor
struct DeepLinkHandler {

    // MARK: - Pending Deep Link (stored when user is not authenticated)

    /// Stores a deep-link URL that arrived before the user was authenticated.
    /// Call ``processPendingDeepLink(in:)`` after login to replay it.
    private(set) static var pendingDeepLink: URL?

    // MARK: - URL Deep Links (Widgets / Universal Links)

    /// Parses a `wolfwhale://` URL into a ``DeepLinkDestination``.
    ///
    /// Supported URL formats:
    /// - `wolfwhale://assignments`
    /// - `wolfwhale://grades`
    /// - `wolfwhale://schedule`
    /// - `wolfwhale://course/{uuid}`
    /// - `wolfwhale://assignment/{uuid}`
    /// - `wolfwhale://quiz/{uuid}`
    /// - `wolfwhale://tools`
    /// - `wolfwhale://wellness`
    /// - `wolfwhale://shareplay`
    /// - `wolfwhale://recommendations`
    static func destination(from url: URL) -> DeepLinkDestination? {
        guard url.scheme == "wolfwhale" else { return nil }

        // host carries the first path component for scheme-based URLs
        let host = url.host() ?? ""
        let pathComponents = url.pathComponents.filter { $0 != "/" }

        switch host {
        case "assignments":
            return .assignments
        case "grades":
            return .grades
        case "schedule":
            return .schedule
        case "tools":
            return .tools
        case "wellness":
            return .wellness
        case "shareplay":
            return .sharePlay
        case "recommendations":
            return .recommendations
        case "course":
            if let idString = pathComponents.first, let uuid = UUID(uuidString: idString) {
                return .course(uuid)
            }
            return nil
        case "assignment":
            if let idString = pathComponents.first, let uuid = UUID(uuidString: idString) {
                return .assignment(uuid)
            }
            return nil
        case "quiz":
            if let idString = pathComponents.first, let uuid = UUID(uuidString: idString) {
                return .quiz(uuid)
            }
            return nil
        default:
            return nil
        }
    }

    // MARK: - Spotlight / NSUserActivity Deep Links

    /// Parses an `NSUserActivity` from CoreSpotlight into a ``DeepLinkDestination``.
    ///
    /// Spotlight unique identifiers follow the format:
    /// - `course:{uuid}`
    /// - `assignment:{uuid}`
    /// - `quiz:{uuid}`
    static func destination(from activity: NSUserActivity) -> DeepLinkDestination? {
        guard activity.activityType == CSSearchableItemActionType,
              let identifier = activity.userInfo?[CSSearchableItemActivityIdentifier] as? String else {
            return nil
        }
        return destination(fromSpotlightIdentifier: identifier)
    }

    /// Parses a Spotlight unique identifier string into a ``DeepLinkDestination``.
    static func destination(fromSpotlightIdentifier identifier: String) -> DeepLinkDestination? {
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

    // MARK: - Apply Destination to ViewModel

    /// Updates navigation-related state on the given ``AppViewModel`` to navigate
    /// to the supplied ``DeepLinkDestination``. The tab views observe these
    /// properties and react accordingly.
    static func navigate(to destination: DeepLinkDestination, in viewModel: AppViewModel) {
        switch destination {
        case .assignments:
            viewModel.notificationService.deepLinkAssignmentId = UUID()
        case .grades:
            viewModel.notificationService.deepLinkGradeId = UUID()
        case .schedule:
            // Schedule is shown on the home / dashboard tab
            viewModel.notificationService.deepLinkAssignmentId = UUID()
        case .course(let id):
            viewModel.deepLinkCourseId = id
        case .assignment(let id):
            viewModel.notificationService.deepLinkAssignmentId = id
        case .quiz(let id):
            viewModel.deepLinkQuizId = id
        case .tools:
            viewModel.deepLinkShowTools = true
        case .wellness:
            viewModel.deepLinkShowWellness = true
        case .sharePlay:
            viewModel.deepLinkShowSharePlay = true
        case .recommendations:
            viewModel.deepLinkShowRecommendations = true
        }
    }

    // MARK: - Convenience: Handle URL end-to-end

    /// Parses the URL and, if valid, navigates the view model to the destination.
    /// If the user is not authenticated the URL is stored in ``pendingDeepLink``
    /// and will be replayed when ``processPendingDeepLink(in:)`` is called.
    /// Returns `true` when the URL was handled (or deferred).
    @discardableResult
    static func handle(url: URL, in viewModel: AppViewModel) -> Bool {
        guard let dest = destination(from: url) else { return false }
        guard viewModel.isAuthenticated else {
            pendingDeepLink = url
            return true
        }
        navigate(to: dest, in: viewModel)
        return true
    }

    /// Parses the user activity and, if valid, navigates the view model to the destination.
    /// If the user is not authenticated the underlying URL (if any) is stored
    /// in ``pendingDeepLink``.
    /// Returns `true` when the activity was handled (or deferred).
    @discardableResult
    static func handle(activity: NSUserActivity, in viewModel: AppViewModel) -> Bool {
        guard let dest = destination(from: activity) else { return false }
        guard viewModel.isAuthenticated else {
            // No URL equivalent for Spotlight activities; store the destination
            // by round-tripping through a synthetic URL is impractical.
            // Instead, just drop — Spotlight can be re-triggered.
            return false
        }
        navigate(to: dest, in: viewModel)
        return true
    }

    /// Replays a deep link that was deferred because the user was not yet
    /// authenticated. Call this after a successful login.
    static func processPendingDeepLink(in viewModel: AppViewModel) {
        guard let url = pendingDeepLink else { return }
        pendingDeepLink = nil
        handle(url: url, in: viewModel)
    }
}
