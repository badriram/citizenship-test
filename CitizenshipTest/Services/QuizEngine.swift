import Foundation

@Observable
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

    static let totalQuestions = 20
    static let passingScore = 12

    var currentQuestion: Question? {
        guard currentIndex < questions.count else { return nil }
        return questions[currentIndex]
    }

    var isPassing: Bool { score >= Self.passingScore }

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
        if currentIndex < questions.count - 1 {
            currentIndex += 1
        }
    }

    func previousQuestion() {
        if currentIndex > 0 {
            currentIndex -= 1
        }
    }

    func finishTest() {
        var correct = 0
        results = questions.enumerated().map { index, question in
            let userAnswer = answers[index] ?? ""
            let acceptedAnswers = question.answersForState(selectedState, legislators: legislatorStore, district: district)
            let isCorrect = AnswerMatcher.check(userAnswer: userAnswer, acceptedAnswers: acceptedAnswers)
            if isCorrect { correct += 1 }
            return QuizResult(question: question, userAnswer: userAnswer, isCorrect: isCorrect)
        }
        score = correct
        isFinished = true
    }
}

struct QuizResult: Identifiable {
    let id = UUID()
    let question: Question
    let userAnswer: String
    let isCorrect: Bool
}
