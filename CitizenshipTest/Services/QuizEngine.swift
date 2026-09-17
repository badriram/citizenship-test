import Foundation

@Observable
@MainActor
final class QuizEngine {
    let questions: [Question]
    let selectedState: StateInfo?
    let legislatorStore: LegislatorStore?
    let district: Int?
    var currentIndex: Int = 0
    var answers: [Int: String] = [:]
    var isFinished: Bool = false
    var results: [QuizResult] = []
    var score: Int = 0

    /// Set while on-device AI grading is in flight, so the UI can show progress.
    var isGrading: Bool = false
    var gradedCount: Int = 0
    /// True when the finished test was graded by Apple Intelligence rather than
    /// the heuristic matcher. Drives a small badge on the results screen.
    var gradedByAI: Bool = false

    /// Verdicts produced ahead of submission, keyed by question index.
    private var gradeCache: [Int: AIAnswerGrader.Grade] = [:]
    /// The exact answer text each cached verdict was produced from. If the user
    /// goes back and edits, the text no longer matches and we re-grade.
    private var gradedText: [Int: String] = [:]
    /// In-flight background grading, so we can cancel a superseded edit and
    /// await stragglers at submission.
    private var gradingTasks: [Int: Task<Void, Never>] = [:]

    static let totalQuestions = 20
    static let passingScore = 12

    var currentQuestion: Question? {
        guard currentIndex < questions.count else { return nil }
        return questions[currentIndex]
    }

    var isPassing: Bool { score >= Self.passingScore }

    /// Questions with a non-empty answer.
    var answeredCount: Int {
        answers.values.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count
    }

    init(allQuestions: [Question] = questionsData, state: StateInfo?, legislatorStore: LegislatorStore? = nil, district: Int? = nil) {
        self.selectedState = state
        self.legislatorStore = legislatorStore
        self.district = district
        self.questions = Array(allQuestions.shuffled().prefix(Self.totalQuestions))
    }

    func submitAnswer(_ answer: String) {
        answers[currentIndex] = answer
    }

    func nextQuestion() {
        // Grade the answer being left behind, not the one being typed.
        scheduleGrading(for: currentIndex)
        if currentIndex < questions.count - 1 {
            currentIndex += 1
        }
    }

    func previousQuestion() {
        scheduleGrading(for: currentIndex)
        if currentIndex > 0 {
            currentIndex -= 1
        }
    }

    /// Warm the on-device model so the first real grading call isn't the one
    /// that pays model load cost.
    func prepareGrading() {
        AIAnswerGrader.prewarm()
    }

    /// Grade one answer in the background. Cheap to call repeatedly: it no-ops
    /// when the answer is empty or already graded at its current text.
    private func scheduleGrading(for index: Int) {
        guard AIAnswerGrader.isAvailable else { return }
        let answer = (answers[index] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

        guard !answer.isEmpty else {
            // Cleared answer — drop any stale verdict.
            gradingTasks[index]?.cancel()
            gradingTasks[index] = nil
            gradeCache[index] = nil
            gradedText[index] = nil
            return
        }

        // Already have a verdict for this exact text.
        if gradedText[index] == answer, gradeCache[index] != nil { return }

        // Supersede any in-flight grading of older text.
        gradingTasks[index]?.cancel()

        let question = questions[index]
        let acceptedAnswers = question.answersForState(selectedState, legislators: legislatorStore, district: district)

        gradingTasks[index] = Task { [weak self] in
            let grade = await AIAnswerGrader.grade(
                question: question.text,
                userAnswer: answer,
                acceptedAnswers: acceptedAnswers
            )
            guard !Task.isCancelled, let self else { return }
            if let grade {
                self.gradeCache[index] = grade
                self.gradedText[index] = answer
            }
            self.gradingTasks[index] = nil
        }
    }

    func finishTest() async {
        let useAI = AIAnswerGrader.isAvailable

        // Grade the final question, which was never navigated away from.
        scheduleGrading(for: currentIndex)

        // Most answers were graded in the background while the user worked.
        // Only wait on whatever is still in flight.
        // Snapshot into an array: `.values` is a lazy view, and each task clears its
        // own entry on completion — mutating the dictionary while we await across it.
        let pending = Array(gradingTasks.values)
        isGrading = useAI && !pending.isEmpty
        gradedCount = useAI ? max(0, answeredCount - pending.count) : 0
        gradedByAI = false

        for task in pending {
            await task.value
        }
        gradingTasks.removeAll()

        var graded: [QuizResult] = []
        var correct = 0
        var anyAIGrade = false

        for (index, question) in questions.enumerated() {
            let userAnswer = answers[index] ?? ""
            let acceptedAnswers = question.answersForState(selectedState, legislators: legislatorStore, district: district)

            var isCorrect: Bool
            var explanation: String? = nil

            // Prefer the verdict computed in the background; grade inline only if
            // it's missing (model unavailable then, or the answer changed late).
            let trimmedAnswer = userAnswer.trimmingCharacters(in: .whitespacesAndNewlines)
            var resolved: AIAnswerGrader.Grade? = nil
            if useAI {
                if gradedText[index] == trimmedAnswer, let cached = gradeCache[index] {
                    resolved = cached
                } else {
                    resolved = await AIAnswerGrader.grade(
                        question: question.text,
                        userAnswer: userAnswer,
                        acceptedAnswers: acceptedAnswers
                    )
                }
            }

            // The model is additive, never subtractive: it can rescue an answer the
            // heuristic wrongly rejects, but it cannot overturn one the heuristic
            // accepts. A model mistake would otherwise tell a student who answered
            // correctly that they were wrong, and teach them the wrong civics with a
            // confident explanation attached.
            let heuristicSaysCorrect = AnswerMatcher.check(userAnswer: userAnswer, acceptedAnswers: acceptedAnswers)

            if let grade = resolved {
                isCorrect = heuristicSaysCorrect || grade.isCorrect
                anyAIGrade = true
                // Only show the model's reasoning when it agrees with the verdict;
                // otherwise the row would read "correct" above prose explaining why
                // it is wrong.
                explanation = (grade.isCorrect == isCorrect) ? grade.explanation : nil
            } else {
                isCorrect = heuristicSaysCorrect
            }

            if isCorrect { correct += 1 }
            graded.append(
                QuizResult(
                    question: question,
                    userAnswer: userAnswer,
                    isCorrect: isCorrect,
                    explanation: explanation
                )
            )
            gradedCount = index + 1
        }

        results = graded
        score = correct
        gradedByAI = anyAIGrade
        isGrading = false
        isFinished = true
    }
}

struct QuizResult: Identifiable {
    let id = UUID()
    let question: Question
    let userAnswer: String
    let isCorrect: Bool
    /// One-line AI explanation of the verdict; nil when graded by the heuristic matcher.
    var explanation: String? = nil
}
