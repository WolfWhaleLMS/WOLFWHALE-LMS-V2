import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

// MARK: - ProfileImageView

/// A reusable circular profile image component.
///
/// - When a URL is available, displays the remote image using ``CachedAsyncImage``
///   clipped to a circle.
/// - When no URL is available (or the URL is nil), shows the user's initials inside a
///   deterministically-colored circle derived from the name hash.
/// - A thin border stroke is always applied for visual consistency.
///
/// Usage:
/// ```swift
/// ProfileImageView(url: user.avatarURL, name: user.displayName, size: 44)
/// ```
///
/// Common contexts: user profiles, message avatars, student list rows.
struct ProfileImageView: View {
    let url: URL?
    let name: String
    let size: CGFloat

    var body: some View {
        Group {
            if let url {
                CachedAsyncImage(url: url, maxDimension: 100) {
                    initialsView
                }
                .frame(width: size, height: size)
                .clipShape(Circle())
            } else {
                initialsView
            }
        }
        .overlay {
            Circle()
                .strokeBorder(Color.gray.opacity(0.3), lineWidth: 1)
                .frame(width: size, height: size)
        }
        .accessibilityLabel("Profile image for \(name)")
    }

    // MARK: - Initials Fallback

    /// Displays the user's initials in a colored circle.
    private var initialsView: some View {
        Circle()
            .fill(backgroundColor)
            .frame(width: size, height: size)
            .overlay {
                Text(initials)
                    .font(.system(size: size * 0.38, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
            }
    }

    // MARK: - Computed Properties

    /// Extracts up to two initials from the name (first and last components).
    private var initials: String {
        let components = name
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: " ")

        switch components.count {
        case 0:
            return "?"
        case 1:
            return String(components[0].prefix(1)).uppercased()
        default:
            let first = String(components[0].prefix(1)).uppercased()
            let last = String(components[components.count - 1].prefix(1)).uppercased()
            return first + last
        }
    }

    /// Deterministic gradient derived from the name's hash value.
    ///
    /// The palette uses the project's indigo/purple theme while providing enough
    /// variation to visually distinguish different users.
    private var backgroundColor: LinearGradient {
        let palette: [(Color, Color)] = [
            (.indigo, .purple),
            (.purple, .orange),
            (.blue, .indigo),
            (.teal, .blue),
            (.indigo, .blue),
            (.purple, .indigo),
            (.orange, .purple),
            (.blue, .purple),
        ]

        let hash = abs(name.hashValue)
        let pair = palette[hash % palette.count]

        return LinearGradient(
            colors: [pair.0, pair.1],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - Previews

#Preview("With URL") {
    ProfileImageView(
        url: URL(string: "https://picsum.photos/200"),
        name: "Jane Doe",
        size: 80
    )
    .padding()
}

#Preview("Initials Fallback") {
    HStack(spacing: 16) {
        ProfileImageView(url: nil, name: "Alice Wang", size: 44)
        ProfileImageView(url: nil, name: "Bob Smith", size: 44)
        ProfileImageView(url: nil, name: "Charlie", size: 44)
        ProfileImageView(url: nil, name: "", size: 44)
    }
    .padding()
}

#Preview("Sizes") {
    VStack(spacing: 20) {
        ProfileImageView(url: nil, name: "Small User", size: 32)
        ProfileImageView(url: nil, name: "Medium User", size: 64)
        ProfileImageView(url: nil, name: "Large User", size: 120)
    }
    .padding()
}
