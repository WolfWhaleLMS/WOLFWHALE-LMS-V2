import SwiftUI

// MARK: - SearchResultRow

struct SearchResultRow: View, Equatable {
    let result: SearchResult
    let query: String

    static func == (lhs: SearchResultRow, rhs: SearchResultRow) -> Bool {
        lhs.result == rhs.result && lhs.query == rhs.query
    }

    var body: some View {
        HStack(spacing: 14) {
            // Category-colored icon circle
            ZStack {
                Circle()
                    .fill(result.category.color.opacity(0.15))
                Image(systemName: result.icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(result.category.color)
            }
            .frame(width: 42, height: 42)
            .accessibilityHidden(true)

            // Title + subtitle
            VStack(alignment: .leading, spacing: 3) {
                highlightedText(result.title, query: query)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)

                Text(result.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            // Category badge + chevron
            VStack(alignment: .trailing, spacing: 4) {
                Text(result.category.displayName)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(result.category.color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background {
                        Capsule()
                            .fill(result.category.color.opacity(0.12))
                    }

                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .background {
            RoundedRectangle(cornerRadius: 14)
                .fill(.clear)
                .compatGlassEffect(in: RoundedRectangle(cornerRadius: 14))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(result.title), \(result.category.displayName). \(result.subtitle)")
        .accessibilityAddTraits(.isButton)
    }

    // MARK: - Highlighted Text

    /// Renders the title with the matching portion displayed in bold.
    /// Non-matching portions use the default weight.
    @ViewBuilder
    private func highlightedText(_ text: String, query: String) -> some View {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedQuery.isEmpty {
            Text(text)
        } else {
            let attributed = buildHighlightedAttributedString(text, query: trimmedQuery)
            Text(attributed)
        }
    }

    private func buildHighlightedAttributedString(_ text: String, query: String) -> AttributedString {
        var attributedString = AttributedString(text)

        // Find the range of the query within the text (case-insensitive)
        guard let range = text.range(of: query, options: .caseInsensitive) else {
            return attributedString
        }

        // Convert String.Index range to AttributedString range
        let lowerOffset = text.distance(from: text.startIndex, to: range.lowerBound)
        let upperOffset = text.distance(from: text.startIndex, to: range.upperBound)

        let attrStart = attributedString.index(attributedString.startIndex, offsetByCharacters: lowerOffset)
        let attrEnd = attributedString.index(attributedString.startIndex, offsetByCharacters: upperOffset)

        // Apply bold + accent color to the matching range
        attributedString[attrStart..<attrEnd].font = .subheadline.weight(.heavy)
        attributedString[attrStart..<attrEnd].foregroundColor = .primary

        return attributedString
    }
}
