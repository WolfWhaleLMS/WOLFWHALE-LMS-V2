import Foundation

/// Represents a grammar or style issue found in the user's text.
struct GrammarIssue: Identifiable {
    enum Severity: String {
        case info, warning, error
    }

    let id = UUID()
    let range: Range<String.Index>
    let description: String
    let suggestion: String
    let severity: Severity
}

/// A local writing-analysis service that computes text statistics and checks grammar.
/// No network calls — all analysis is done on-device using string inspection and regex.
@Observable
@MainActor
final class WritingToolsService {

    // MARK: - Published Statistics

    var wordCount: Int = 0
    var characterCount: Int = 0
    var sentenceCount: Int = 0
    var paragraphCount: Int = 0
    var readingTime: String = "0 min"
    var readabilityScore: Double = 0

    // MARK: - Analyse Text

    /// Computes all text statistics at once.
    func analyzeText(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            wordCount = 0
            characterCount = 0
            sentenceCount = 0
            paragraphCount = 0
            readingTime = "0 min"
            readabilityScore = 0
            return
        }

        characterCount = trimmed.count
        let words = trimmed.split(omittingEmptySubsequences: true) { $0.isWhitespace || $0.isNewline }
        wordCount = words.count

        // Sentences: split on .!? followed by whitespace or end-of-string
        let sentenceRegex = try? NSRegularExpression(pattern: "[.!?]+(?:\\s|$)", options: [])
        let nsRange = NSRange(trimmed.startIndex..., in: trimmed)
        sentenceCount = max(sentenceRegex?.numberOfMatches(in: trimmed, options: [], range: nsRange) ?? 1, 1)

        // Paragraphs: blocks separated by one or more blank lines
        let paragraphs = trimmed.components(separatedBy: "\n").split(omittingEmptySubsequences: true) { $0.trimmingCharacters(in: .whitespaces).isEmpty }
        paragraphCount = max(paragraphs.count, 1)

        // Reading time (~238 wpm average)
        let minutes = Double(wordCount) / 238.0
        if minutes < 1 {
            readingTime = "< 1 min"
        } else {
            readingTime = "\(Int(minutes.rounded(.up))) min"
        }

        readabilityScore = calculateReadability(trimmed)
    }

    // MARK: - Readability (Flesch-Kincaid Grade Level)

    /// Returns the Flesch-Kincaid Grade Level score.
    func calculateReadability(_ text: String) -> Double {
        let words = text.split(omittingEmptySubsequences: true) { $0.isWhitespace || $0.isNewline }
        guard words.count > 0 else { return 0 }

        let sentenceRegex = try? NSRegularExpression(pattern: "[.!?]+(?:\\s|$)", options: [])
        let nsRange = NSRange(text.startIndex..., in: text)
        let sentences = max(sentenceRegex?.numberOfMatches(in: text, options: [], range: nsRange) ?? 1, 1)

        var totalSyllables = 0
        for word in words {
            totalSyllables += syllableCount(for: String(word))
        }

        let avgWordsPerSentence = Double(words.count) / Double(sentences)
        let avgSyllablesPerWord = Double(totalSyllables) / Double(words.count)

        // Flesch-Kincaid Grade Level
        let grade = 0.39 * avgWordsPerSentence + 11.8 * avgSyllablesPerWord - 15.59
        return max(0, min(grade, 18)).rounded(toPlaces: 1)
    }

    /// A simple syllable counter heuristic.
    private func syllableCount(for word: String) -> Int {
        let lower = word.lowercased().filter(\.isLetter)
        guard !lower.isEmpty else { return 1 }

        let vowels: Set<Character> = ["a", "e", "i", "o", "u", "y"]
        var count = 0
        var prevIsVowel = false
        for ch in lower {
            let isVowel = vowels.contains(ch)
            if isVowel && !prevIsVowel {
                count += 1
            }
            prevIsVowel = isVowel
        }

        // Silent e at end
        if lower.hasSuffix("e") && count > 1 {
            count -= 1
        }
        // Words like "le" at end still count
        if lower.hasSuffix("le") && lower.count > 2 && !vowels.contains(lower[lower.index(lower.endIndex, offsetBy: -3)]) {
            count += 1
        }

        return max(count, 1)
    }

    // MARK: - Grammar Checking

    /// Runs a battery of local grammar/style checks and returns issues.
    func checkGrammar(_ text: String) -> [GrammarIssue] {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return [] }

        var issues: [GrammarIssue] = []
        issues.append(contentsOf: checkDoubleSpaces(text))
        issues.append(contentsOf: checkSentenceCapitalization(text))
        issues.append(contentsOf: checkMissingPeriods(text))
        issues.append(contentsOf: checkRepeatedWords(text))
        issues.append(contentsOf: checkOverlyLongSentences(text))
        issues.append(contentsOf: checkCommonConfusables(text))
        return issues
    }

    // MARK: - Individual Checks

    private func checkDoubleSpaces(_ text: String) -> [GrammarIssue] {
        var issues: [GrammarIssue] = []
        guard let regex = try? NSRegularExpression(pattern: " {2,}", options: []) else { return [] }
        let nsRange = NSRange(text.startIndex..., in: text)
        for match in regex.matches(in: text, options: [], range: nsRange) {
            if let range = Range(match.range, in: text) {
                issues.append(GrammarIssue(
                    range: range,
                    description: "Multiple spaces detected",
                    suggestion: "Replace with a single space",
                    severity: .info
                ))
            }
        }
        return issues
    }

    private func checkSentenceCapitalization(_ text: String) -> [GrammarIssue] {
        var issues: [GrammarIssue] = []
        // Match after sentence-ending punctuation + whitespace, or start of string
        guard let regex = try? NSRegularExpression(pattern: "(?:^|[.!?]\\s+)([a-z])", options: .anchorsMatchLines) else { return [] }
        let nsRange = NSRange(text.startIndex..., in: text)
        for match in regex.matches(in: text, options: [], range: nsRange) {
            let captureNS = match.range(at: 1)
            if let range = Range(captureNS, in: text) {
                let char = String(text[range])
                issues.append(GrammarIssue(
                    range: range,
                    description: "Sentence should start with a capital letter",
                    suggestion: "Capitalize '\(char)' to '\(char.uppercased())'",
                    severity: .warning
                ))
            }
        }
        return issues
    }

    private func checkMissingPeriods(_ text: String) -> [GrammarIssue] {
        var issues: [GrammarIssue] = []
        let paragraphs = text.components(separatedBy: "\n")
        for paragraph in paragraphs {
            let trimmed = paragraph.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, trimmed.count > 10 else { continue }
            let lastChar = trimmed.last
            if let lastChar, !".!?:\"')".contains(lastChar) {
                // Find the range of the last character in the original text
                if let paragraphRange = text.range(of: paragraph) {
                    let endIndex = paragraphRange.upperBound
                    let startIndex = text.index(before: endIndex)
                    issues.append(GrammarIssue(
                        range: startIndex..<endIndex,
                        description: "Paragraph may be missing ending punctuation",
                        suggestion: "Add a period at the end",
                        severity: .info
                    ))
                }
            }
        }
        return issues
    }

    private func checkRepeatedWords(_ text: String) -> [GrammarIssue] {
        var issues: [GrammarIssue] = []
        guard let regex = try? NSRegularExpression(pattern: "\\b(\\w+)\\s+\\1\\b", options: .caseInsensitive) else { return [] }
        let nsRange = NSRange(text.startIndex..., in: text)
        for match in regex.matches(in: text, options: [], range: nsRange) {
            if let range = Range(match.range, in: text) {
                let repeated = String(text[range])
                let word = repeated.split(separator: " ").first.map(String.init) ?? repeated
                issues.append(GrammarIssue(
                    range: range,
                    description: "Repeated word: \"\(word)\"",
                    suggestion: "Remove the duplicate word",
                    severity: .warning
                ))
            }
        }
        return issues
    }

    private func checkOverlyLongSentences(_ text: String) -> [GrammarIssue] {
        var issues: [GrammarIssue] = []
        guard let regex = try? NSRegularExpression(pattern: "[^.!?]*[.!?]", options: []) else { return [] }
        let nsRange = NSRange(text.startIndex..., in: text)
        for match in regex.matches(in: text, options: [], range: nsRange) {
            if let range = Range(match.range, in: text) {
                let sentence = String(text[range])
                let wordCount = sentence.split(omittingEmptySubsequences: true) { $0.isWhitespace }.count
                if wordCount > 40 {
                    issues.append(GrammarIssue(
                        range: range,
                        description: "Sentence is very long (\(wordCount) words)",
                        suggestion: "Consider splitting into shorter sentences for clarity",
                        severity: .info
                    ))
                }
            }
        }
        return issues
    }

    private func checkCommonConfusables(_ text: String) -> [GrammarIssue] {
        var issues: [GrammarIssue] = []

        // Patterns: (regex, description, suggestion)
        let confusables: [(String, String, String)] = [
            // their/there/they're — flag potential misuse heuristically
            ("\\btheir\\s+(is|are|was|were|have|has|will|would|could|should)\\b",
             "Possible misuse of 'their' — did you mean 'there' or 'they're'?",
             "Check whether 'there' or 'they're' fits better"),
            ("\\bthere\\s+(car|house|book|dog|cat|name|friend)\\b",
             "Possible misuse of 'there' — did you mean 'their'?",
             "Consider using 'their' for possession"),
            // its/it's
            ("\\bits\\s+(a|an|the|not|very|been|going|always|never)\\b",
             "Possible misuse of 'its' — did you mean 'it's' (it is)?",
             "Use 'it's' for 'it is' or 'it has'"),
            ("\\bit's\\s+(own)\\b",
             "Possible misuse of 'it's' — did you mean 'its' (possessive)?",
             "Use 'its' for possession"),
            // your/you're
            ("\\byour\\s+(welcome|right|wrong|going|not|the\\s+best|a|an)\\b",
             "Possible misuse of 'your' — did you mean 'you're' (you are)?",
             "Use 'you're' for 'you are'"),
            ("\\byou're\\s+(car|house|book|dog|cat|name|friend)\\b",
             "Possible misuse of 'you're' — did you mean 'your' (possessive)?",
             "Use 'your' for possession"),
        ]

        for (pattern, description, suggestion) in confusables {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { continue }
            let nsRange = NSRange(text.startIndex..., in: text)
            for match in regex.matches(in: text, options: [], range: nsRange) {
                if let range = Range(match.range, in: text) {
                    issues.append(GrammarIssue(
                        range: range,
                        description: description,
                        suggestion: suggestion,
                        severity: .warning
                    ))
                }
            }
        }
        return issues
    }
}

// MARK: - Double Rounding Helper

private extension Double {
    func rounded(toPlaces places: Int) -> Double {
        let multiplier = pow(10.0, Double(places))
        return (self * multiplier).rounded() / multiplier
    }
}
