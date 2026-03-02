import SwiftUI
import SwiftData

struct ProgressSummaryView: View {
    @Query private var progressRecords: [QuestionProgress]

    private var studied: Int {
        progressRecords.filter { $0.progressStatus != .unstudied }.count
    }

    private var mastered: Int {
        progressRecords.filter { $0.progressStatus == .mastered }.count
    }

    private var needsReview: Int {
        progressRecords.filter { $0.progressStatus == .needsReview }.count
    }

    var body: some View {
        HStack(spacing: 12) {
            NavigationLink(value: AppDestination.flashcards) {
                InfoCardView(icon: "book.fill", title: "Studied", value: "\(studied)", color: .green)
            }
            .buttonStyle(.plain)

            NavigationLink(value: AppDestination.flashcards) {
                InfoCardView(icon: "star.fill", title: "Mastered", value: "\(mastered)", color: .blue)
            }
            .buttonStyle(.plain)

            NavigationLink(value: AppDestination.flashcardsReview) {
                InfoCardView(icon: "arrow.clockwise", title: "Review", value: "\(needsReview)", color: .orange)
            }
            .buttonStyle(.plain)
        }
    }
}
