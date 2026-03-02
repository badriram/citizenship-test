import Foundation
import SwiftData

struct ProgressTracker {
    static func getOrCreate(questionId: Int, context: ModelContext) -> QuestionProgress {
        let descriptor = FetchDescriptor<QuestionProgress>(
            predicate: #Predicate { $0.questionId == questionId }
        )
        if let existing = try? context.fetch(descriptor).first {
            return existing
        }
        let progress = QuestionProgress(questionId: questionId)
        context.insert(progress)
        return progress
    }

    static func fetchAll(context: ModelContext) -> [QuestionProgress] {
        let descriptor = FetchDescriptor<QuestionProgress>()
        return (try? context.fetch(descriptor)) ?? []
    }

    static func counts(context: ModelContext) -> (studied: Int, mastered: Int, needsReview: Int) {
        let all = fetchAll(context: context)
        let deduplicated = deduplicate(all, context: context)
        let studied = deduplicated.filter { $0.progressStatus != .unstudied }.count
        let mastered = deduplicated.filter { $0.progressStatus == .mastered }.count
        let needsReview = deduplicated.filter { $0.progressStatus == .needsReview }.count
        return (studied, mastered, needsReview)
    }

    static func deduplicate(_ records: [QuestionProgress], context: ModelContext) -> [QuestionProgress] {
        var seen: [Int: QuestionProgress] = [:]
        var toDelete: [QuestionProgress] = []

        for record in records {
            if let existing = seen[record.questionId] {
                // Keep the one with more reviews
                if record.timesReviewed > existing.timesReviewed {
                    toDelete.append(existing)
                    seen[record.questionId] = record
                } else {
                    toDelete.append(record)
                }
            } else {
                seen[record.questionId] = record
            }
        }

        for dup in toDelete {
            context.delete(dup)
        }

        return Array(seen.values)
    }

    static func markStudied(questionId: Int, correct: Bool, context: ModelContext) {
        let progress = getOrCreate(questionId: questionId, context: context)
        progress.timesReviewed += 1
        progress.lastReviewedAt = Date()

        if correct {
            progress.correctStreak += 1
            progress.progressStatus = progress.correctStreak >= 2 ? .mastered : .studied
        } else {
            progress.correctStreak = 0
            progress.progressStatus = .needsReview
        }

        try? context.save()
    }

    static func resetProgress(context: ModelContext) {
        let all = fetchAll(context: context)
        for record in all {
            context.delete(record)
        }
        try? context.save()
    }
}
