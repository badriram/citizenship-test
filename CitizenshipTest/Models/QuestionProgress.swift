import Foundation
import SwiftData

@Model
final class QuestionProgress {
    var questionId: Int = 0
    var status: String = "unstudied"
    var timesReviewed: Int = 0
    var lastReviewedAt: Date = Date.distantPast
    var correctStreak: Int = 0

    init(questionId: Int = 0, status: String = "unstudied", timesReviewed: Int = 0, lastReviewedAt: Date = .distantPast, correctStreak: Int = 0) {
        self.questionId = questionId
        self.status = status
        self.timesReviewed = timesReviewed
        self.lastReviewedAt = lastReviewedAt
        self.correctStreak = correctStreak
    }
}

extension QuestionProgress {
    enum Status: String {
        case unstudied
        case studied
        case mastered
        case needsReview
    }

    var progressStatus: Status {
        get { Status(rawValue: status) ?? .unstudied }
        set { status = newValue.rawValue }
    }
}
