import SwiftUI
import SwiftData

struct ReviewListView: View {
    @Environment(LegislatorStore.self) private var legislatorStore
    @Query private var settingsResults: [UserSettings]
    @State private var selectedCategory: QuestionCategory? = nil
    @State private var searchText = ""

    private var selectedState: StateInfo? {
        let stateId = settingsResults.first?.selectedStateId ?? "IL"
        return statesData.first { $0.id == stateId }
    }

    private var selectedDistrict: Int? {
        settingsResults.first?.selectedDistrict
    }

    private var filteredQuestions: [Question] {
        var questions = questionsData

        if let category = selectedCategory {
            questions = questions.filter { $0.category == category }
        }

        if !searchText.isEmpty {
            let search = searchText.lowercased()
            questions = questions.filter { q in
                q.text.lowercased().contains(search) ||
                q.answersForState(selectedState, legislators: legislatorStore, district: selectedDistrict).contains { $0.lowercased().contains(search) }
            }
        }

        return questions
    }

    var body: some View {
        VStack(spacing: 0) {
            CategoryFilterView(selected: $selectedCategory)
                .padding(.vertical, 8)

            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(filteredQuestions) { question in
                        ReviewQuestionRow(
                            question: question,
                            answers: question.answersForState(selectedState, legislators: legislatorStore, district: selectedDistrict)
                        )
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 40)
            }
        }
        .navigationTitle("Review Questions")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "Search questions...")
    }
}
