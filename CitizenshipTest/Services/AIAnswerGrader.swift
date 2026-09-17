import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// On-device grading of free-text civics answers using Apple's Foundation Models.
///
/// This is a progressive enhancement. The app's deployment target is iOS 17, and
/// Apple Intelligence is unavailable on plenty of iOS 26+ devices too, so every
/// entry point degrades to `AnswerMatcher` (fuzzy + NLEmbedding). Nothing here is
/// on the critical path — if the model is missing, busy, or throws, we fall back.
enum AIAnswerGrader {

    /// Verdict for a single answer. `explanation` is shown on the results screen
    /// to tell the user *why* they were wrong, which the heuristic matcher can't do.
    struct Grade {
        let isCorrect: Bool
        let explanation: String?
    }

    /// True when on-device grading can actually run right now.
    static var isAvailable: Bool {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) {
            return SystemLanguageModel.default.availability == .available
        }
        #endif
        return false
    }

    /// Human-readable reason the AI path is off, for a subtle note in the UI.
    static var unavailableReason: String? {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) {
            switch SystemLanguageModel.default.availability {
            case .available:
                return nil
            case .unavailable(.deviceNotEligible):
                return "This device doesn't support Apple Intelligence."
            case .unavailable(.appleIntelligenceNotEnabled):
                return "Turn on Apple Intelligence in Settings for smarter answer checking."
            case .unavailable(.modelNotReady):
                return "Apple Intelligence is still downloading."
            case .unavailable:
                return "Apple Intelligence is unavailable."
            }
        }
        #endif
        return "Smarter answer checking needs iOS 26 or later."
    }

    /// Warm the model ahead of the first real grading call, so that cost isn't
    /// paid on a question the user is waiting on. Safe to call when unavailable.
    static func prewarm() {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) {
            guard SystemLanguageModel.default.availability == .available else { return }
            LanguageModelSession(instructions: instructions).prewarm()
        }
        #endif
    }

    /// Grade one answer. Returns `nil` when the AI path is unavailable or fails,
    /// signalling the caller to use `AnswerMatcher` instead.
    static func grade(
        question: String,
        userAnswer: String,
        acceptedAnswers: [String]
    ) async -> Grade? {
        let trimmed = userAnswer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !acceptedAnswers.isEmpty else { return nil }

        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) {
            return await gradeWithFoundationModels(
                question: question,
                userAnswer: trimmed,
                acceptedAnswers: acceptedAnswers
            )
        }
        #endif
        return nil
    }
}

#if canImport(FoundationModels)

/// Structured verdict the model is constrained to produce. Guided generation means
/// we never have to parse prose or worry about the model answering in a stray format.
@available(iOS 26.0, macOS 26.0, visionOS 26.0, *)
@Generable
struct CivicsAnswerVerdict {
    @Guide(description: "True only if the student's answer means the same thing as one of the official accepted answers.")
    var isCorrect: Bool

    @Guide(description: "One short sentence, addressed to the student, explaining why the answer is right or wrong. Max 20 words.")
    var explanation: String
}

@available(iOS 26.0, macOS 26.0, visionOS 26.0, *)
extension AIAnswerGrader {

    private static let instructions = """
        You grade answers for the USCIS civics (naturalization) test.

        You are given a question, the official list of accepted answers, and what \
        the student wrote. Decide whether the student's answer matches the meaning \
        of ANY one of the accepted answers.

        Grade the way a USCIS officer does in the real spoken interview:
        - Accept correct meaning regardless of spelling, capitalization, punctuation, \
        grammar, or word order. The real test is spoken, so spelling never matters.
        - Accept partial names and common short forms when unambiguous: a surname \
        alone for an official, "US" for "the United States", "the Constitution" for \
        "the U.S. Constitution".
        - Accept a correct answer even if the student adds extra harmless words.
        - The student only needs ONE accepted answer, even when the official list \
        has many. Never require more than one.

        Mark incorrect when the answer names the wrong thing, is a different \
        office/person/document, is blank, or is too vague to show real knowledge.

        Never invent new correct answers that are not supported by the accepted list.
        """

    static func gradeWithFoundationModels(
        question: String,
        userAnswer: String,
        acceptedAnswers: [String]
    ) async -> Grade? {
        guard SystemLanguageModel.default.availability == .available else { return nil }

        // A fresh session per answer keeps each grading independent — no transcript
        // carry-over that would let one question bias the next.
        let session = LanguageModelSession(instructions: instructions)

        let accepted = acceptedAnswers
            .map { "- \($0)" }
            .joined(separator: "\n")

        let prompt = """
            Question: \(question)

            Accepted answers:
            \(accepted)

            Student's answer: \(userAnswer)
            """

        do {
            let response = try await session.respond(
                to: prompt,
                generating: CivicsAnswerVerdict.self,
                options: GenerationOptions(temperature: 0.0)
            )
            let verdict = response.content
            let explanation = verdict.explanation.trimmingCharacters(in: .whitespacesAndNewlines)
            return Grade(
                isCorrect: verdict.isCorrect,
                explanation: explanation.isEmpty ? nil : explanation
            )
        } catch {
            // Guardrail trips, context overflow, model eviction — all fall back.
            return nil
        }
    }
}

#endif
