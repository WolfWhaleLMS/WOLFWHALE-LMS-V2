import Foundation

// MARK: - Plagiarism Report Models

/// A single pair of submissions flagged for similarity.
nonisolated struct PlagiarismMatch: Identifiable, Sendable {
    let id: UUID
    let studentNameA: String
    let studentNameB: String
    let studentIdA: UUID
    let studentIdB: UUID
    let similarityPercentage: Double
    let matchingExcerpts: [(excerptA: String, excerptB: String)]

    /// Severity tier based on similarity percentage.
    var severity: PlagiarismSeverity {
        if similarityPercentage >= 85 {
            return .high
        } else if similarityPercentage >= 70 {
            return .medium
        } else {
            return .low
        }
    }
}

/// Severity tiers for color coding.
nonisolated enum PlagiarismSeverity: String, Sendable {
    case high   // > 85%
    case medium // 70-85%
    case low    // 50-70%

    var displayName: String {
        switch self {
        case .high: return "High"
        case .medium: return "Medium"
        case .low: return "Low"
        }
    }
}

/// Full plagiarism report for an assignment.
nonisolated struct PlagiarismReport: Sendable {
    let assignmentId: UUID
    let assignmentTitle: String
    let totalSubmissionsChecked: Int
    let matches: [PlagiarismMatch]
    let runDate: Date

    var flaggedCount: Int {
        matches.count
    }

    var highSeverityCount: Int {
        matches.filter { $0.severity == .high }.count
    }

    var mediumSeverityCount: Int {
        matches.filter { $0.severity == .medium }.count
    }

    var lowSeverityCount: Int {
        matches.filter { $0.severity == .low }.count
    }
}

// MARK: - Plagiarism Service

/// Performs basic plagiarism detection on text submissions within an assignment
/// using Jaccard similarity on word n-grams.
@MainActor
final class PlagiarismService {

    static let shared = PlagiarismService()

    // MARK: - Configuration

    /// The n-gram size used for comparison. Trigrams (n=3) balance precision and recall.
    private let ngramSize: Int = 3

    /// Minimum similarity percentage to include in results (50% for the low tier).
    private let minimumSimilarityThreshold: Double = 50.0

    /// Minimum word count for a submission to be analyzed.
    private let minimumWordCount: Int = 10

    /// Maximum excerpt length (characters) returned in matching excerpts.
    private let maxExcerptLength: Int = 200

    // MARK: - Public API

    /// Runs a plagiarism check on all text submissions for a given assignment.
    /// - Parameters:
    ///   - submissions: Array of tuples containing student info and their submission text.
    ///   - assignmentId: The assignment being checked.
    ///   - assignmentTitle: Display title for the report.
    /// - Returns: A `PlagiarismReport` with flagged pairs.
    func checkSubmissions(
        submissions: [(studentId: UUID, studentName: String, text: String)],
        assignmentId: UUID,
        assignmentTitle: String
    ) -> PlagiarismReport {
        // Filter out submissions that are too short to meaningfully analyze
        let validSubmissions = submissions.filter { submission in
            let wordCount = submission.text.split(separator: " ").count
            return wordCount >= minimumWordCount
        }

        // Build n-gram sets for each submission
        let ngramSets: [(studentId: UUID, studentName: String, text: String, ngrams: Set<String>)] =
            validSubmissions.map { sub in
                let ngrams = generateNgrams(from: sub.text, n: ngramSize)
                return (studentId: sub.studentId, studentName: sub.studentName, text: sub.text, ngrams: ngrams)
            }

        var matches: [PlagiarismMatch] = []

        // Compare every pair of submissions
        for i in 0..<ngramSets.count {
            for j in (i + 1)..<ngramSets.count {
                let a = ngramSets[i]
                let b = ngramSets[j]

                let similarity = jaccardSimilarity(a.ngrams, b.ngrams)
                let percentage = similarity * 100.0

                if percentage >= minimumSimilarityThreshold {
                    let excerpts = findMatchingExcerpts(
                        textA: a.text,
                        textB: b.text,
                        ngramSize: ngramSize
                    )

                    let match = PlagiarismMatch(
                        id: UUID(),
                        studentNameA: a.studentName,
                        studentNameB: b.studentName,
                        studentIdA: a.studentId,
                        studentIdB: b.studentId,
                        similarityPercentage: percentage,
                        matchingExcerpts: excerpts
                    )
                    matches.append(match)
                }
            }
        }

        // Sort matches by similarity (highest first)
        let sortedMatches = matches.sorted { $0.similarityPercentage > $1.similarityPercentage }

        return PlagiarismReport(
            assignmentId: assignmentId,
            assignmentTitle: assignmentTitle,
            totalSubmissionsChecked: validSubmissions.count,
            matches: sortedMatches,
            runDate: Date()
        )
    }

    // MARK: - N-gram Generation

    /// Generates a set of word n-grams from the given text.
    /// Text is lowercased and stripped of punctuation before tokenization.
    private func generateNgrams(from text: String, n: Int) -> Set<String> {
        let normalized = normalizeText(text)
        let words = normalized.split(separator: " ").map(String.init)

        guard words.count >= n else {
            // If fewer words than n, return the entire text as a single gram
            return words.isEmpty ? [] : Set([words.joined(separator: " ")])
        }

        var ngrams = Set<String>()
        for i in 0...(words.count - n) {
            let gram = words[i..<(i + n)].joined(separator: " ")
            ngrams.insert(gram)
        }

        return ngrams
    }

    /// Normalizes text: lowercases, removes punctuation, collapses whitespace.
    private func normalizeText(_ text: String) -> String {
        let lowered = text.lowercased()
        // Remove punctuation but keep alphanumerics and whitespace
        let cleaned = lowered.unicodeScalars.filter { scalar in
            CharacterSet.alphanumerics.contains(scalar) || CharacterSet.whitespaces.contains(scalar)
        }
        let result = String(String.UnicodeScalarView(cleaned))
        // Collapse multiple spaces
        return result.components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    // MARK: - Jaccard Similarity

    /// Calculates Jaccard similarity between two sets: |A intersection B| / |A union B|
    private func jaccardSimilarity(_ setA: Set<String>, _ setB: Set<String>) -> Double {
        guard !setA.isEmpty || !setB.isEmpty else { return 0.0 }
        let intersection = setA.intersection(setB)
        let union = setA.union(setB)
        return Double(intersection.count) / Double(union.count)
    }

    // MARK: - Matching Excerpts

    /// Finds overlapping text segments between two submissions to display as evidence.
    /// Returns up to 3 matching excerpt pairs.
    private func findMatchingExcerpts(
        textA: String,
        textB: String,
        ngramSize: Int
    ) -> [(excerptA: String, excerptB: String)] {
        let wordsA = normalizeText(textA).split(separator: " ").map(String.init)
        let wordsB = normalizeText(textB).split(separator: " ").map(String.init)

        // Build n-gram to position mapping for text B
        var bGramPositions: [String: [Int]] = [:]
        if wordsB.count >= ngramSize {
            for i in 0...(wordsB.count - ngramSize) {
                let gram = wordsB[i..<(i + ngramSize)].joined(separator: " ")
                bGramPositions[gram, default: []].append(i)
            }
        }

        // Find runs of consecutive matching n-grams in text A
        var matchRanges: [(startA: Int, startB: Int, length: Int)] = []
        var usedPositionsA = Set<Int>()

        if wordsA.count >= ngramSize {
            for i in 0...(wordsA.count - ngramSize) {
                guard !usedPositionsA.contains(i) else { continue }
                let gram = wordsA[i..<(i + ngramSize)].joined(separator: " ")

                guard let bPositions = bGramPositions[gram] else { continue }

                for bStart in bPositions {
                    // Extend the match as far as possible
                    var length = ngramSize
                    while (i + length) < wordsA.count && (bStart + length) < wordsB.count
                            && wordsA[i + length] == wordsB[bStart + length] {
                        length += 1
                    }

                    if length >= ngramSize + 2 { // Require at least 5 matching words
                        matchRanges.append((startA: i, startB: bStart, length: length))
                        for pos in i..<(i + length) {
                            usedPositionsA.insert(pos)
                        }
                        break
                    }
                }
            }
        }

        // Sort by length (longest matches first) and take top 3
        let topMatches = matchRanges
            .sorted { $0.length > $1.length }
            .prefix(3)

        return topMatches.map { match in
            let excerptA = wordsA[match.startA..<min(match.startA + match.length, wordsA.count)]
                .joined(separator: " ")
            let excerptB = wordsB[match.startB..<min(match.startB + match.length, wordsB.count)]
                .joined(separator: " ")

            // Truncate if needed
            let truncatedA = excerptA.count > maxExcerptLength
                ? String(excerptA.prefix(maxExcerptLength)) + "..."
                : excerptA
            let truncatedB = excerptB.count > maxExcerptLength
                ? String(excerptB.prefix(maxExcerptLength)) + "..."
                : excerptB

            return (excerptA: truncatedA, excerptB: truncatedB)
        }
    }
}
