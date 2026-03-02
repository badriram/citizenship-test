import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationStack {
            HomeView()
                .navigationDestination(for: AppDestination.self) { destination in
                    switch destination {
                    case .flashcards:
                        FlashcardDeckView()
                    case .flashcardsReview:
                        FlashcardDeckView(initialReviewFilter: true)
                    case .practiceTest:
                        PracticeTestView()
                    case .review:
                        ReviewListView()
                    }
                }
        }
    }
}
