import Foundation
import NaturalLanguage

struct SemanticMatcher {
    private static let similarityThreshold: Double = 0.70

    static func check(userAnswer: String, acceptedAnswers: [String]) -> Bool {
        let trimmed = userAnswer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        guard let embedding = NLEmbedding.sentenceEmbedding(for: .english) else {
            return false
        }

        return acceptedAnswers.contains { accepted in
            // Skip semantic matching for very short / numeric answers
            if shouldSkipSemantic(userAnswer: trimmed, accepted: accepted) {
                return false
            }

            let distance = embedding.distance(between: trimmed.lowercased(), and: accepted.lowercased(), distanceType: .cosine)
            let similarity = 1.0 - (distance / 2.0)
            return similarity >= similarityThreshold
        }
    }

    private static func shouldSkipSemantic(userAnswer: String, accepted: String) -> Bool {
        let userWords = userAnswer.split(separator: " ")
        let acceptedWords = accepted.split(separator: " ")

        // Skip if accepted answer is numeric
        if accepted.trimmingCharacters(in: .whitespaces).allSatisfy({ $0.isNumber || $0 == "," || $0 == "." }) {
            return true
        }

        // Skip if both are very short (2 words or fewer) — let fuzzy handle these
        if acceptedWords.count <= 2 && userWords.count <= 2 {
            return true
        }

        return false
    }
}
