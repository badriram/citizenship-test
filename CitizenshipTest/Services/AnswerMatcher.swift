import Foundation

struct AnswerMatcher {
    private static let abbreviations: [String: String] = [
        "us": "united states",
        "usa": "united states",
        "dc": "district of columbia",
        "jb": "j.b.",
        "rep": "representative",
        "sen": "senator",
        "pres": "president",
    ]

    private static let stopWords: Set<String> = [
        "a", "an", "the", "is", "are", "was", "were", "be", "been",
        "to", "of", "in", "for", "on", "at", "by", "it", "its",
        "that", "this", "there", "here", "from", "with", "and", "or",
        "because", "they", "them", "we", "he", "she", "his", "her",
        "do", "does", "did", "has", "have", "had", "will", "would",
        "can", "could", "should", "may", "might",
    ]

    static func check(userAnswer: String, acceptedAnswers: [String]) -> Bool {
        let trimmed = userAnswer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        // 1. Try fuzzy match (fast, existing logic)
        let fuzzyMatch = acceptedAnswers.contains { accepted in
            matches(userInput: trimmed, accepted: accepted)
        }
        if fuzzyMatch { return true }

        // 2. Try semantic match (NLEmbedding)
        return SemanticMatcher.check(userAnswer: trimmed, acceptedAnswers: acceptedAnswers)
    }

    private static func matches(userInput: String, accepted: String) -> Bool {
        let cleanUser = userInput.normalized()
        let cleanAccepted = accepted.normalized()

        // Exact match after cleaning
        if cleanUser == cleanAccepted { return true }

        // Either contains the other
        if cleanUser.contains(cleanAccepted) || cleanAccepted.contains(cleanUser) { return true }

        // Word-level matching
        let userWords = cleanUser.words()
        let acceptedWords = cleanAccepted.words()

        // For very short accepted answers (1-2 words), be lenient
        if acceptedWords.count <= 2 {
            let anyWordMatch = userWords.contains { uw in
                acceptedWords.contains { aw in
                    uw == aw || uw.contains(aw) || aw.contains(uw) || stemMatch(uw, aw)
                }
            }
            if anyWordMatch { return true }
        }

        // Content-word overlap: filter stop words for ratio calculation
        let userContent = userWords.filter { !stopWords.contains($0) }
        let acceptedContent = acceptedWords.filter { !stopWords.contains($0) }

        let matchingContent = userContent.filter { word in
            acceptedContent.contains { aw in
                aw == word || aw.contains(word) || word.contains(aw) || stemMatch(word, aw)
            }
        }

        // Use the SMALLER content word set as denominator so short answers aren't penalized
        let denominator = max(min(userContent.count, acceptedContent.count), 1)
        let contentRatio = Double(matchingContent.count) / Double(denominator)
        if contentRatio >= 0.5 { return true }

        // Also check raw word overlap at a lower threshold (for longer answers)
        let matchingWords = userWords.filter { word in
            acceptedWords.contains { aw in
                aw == word || aw.contains(word) || word.contains(aw) || stemMatch(word, aw)
            }
        }
        let rawRatio = Double(matchingWords.count) / Double(max(userWords.count, acceptedWords.count, 1))
        if rawRatio >= 0.4 { return true }

        // Name matching — extract capitalized words from originals
        let userNames = userInput.extractCapitalizedNames()
        let acceptedNames = accepted.extractCapitalizedNames()

        if !userNames.isEmpty && !acceptedNames.isEmpty {
            let nameMatch = userNames.contains { un in
                acceptedNames.contains { an in
                    an.lowercased() == un.lowercased() || stemMatch(an.lowercased(), un.lowercased())
                }
            }
            if nameMatch { return true }
        }

        // Abbreviation expansion
        var expandedUser = cleanUser
        for (abbrev, full) in abbreviations {
            expandedUser = expandedUser.replacingOccurrences(
                of: "\\b\(abbrev)\\b",
                with: full,
                options: .regularExpression
            )
        }

        if expandedUser.contains(cleanAccepted) || cleanAccepted.contains(expandedUser) {
            return true
        }

        return false
    }

    /// Stem-aware match: two words match if they share a common prefix of 5+ characters.
    /// Catches celebrate/celebration, british/britain, etc.
    private static func stemMatch(_ a: String, _ b: String) -> Bool {
        guard a.count >= 5 && b.count >= 5 else { return false }
        let minLen = min(a.count, b.count)
        let prefixLen = min(minLen, 7)
        let aPrefix = a.prefix(prefixLen)
        let bPrefix = b.prefix(prefixLen)

        // Check shared prefix of at least 5 characters
        var shared = 0
        for (c1, c2) in zip(aPrefix, bPrefix) {
            if c1 == c2 { shared += 1 } else { break }
        }
        return shared >= 5
    }
}
