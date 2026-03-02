import SwiftUI
import SwiftData

struct FlashcardDeckView: View {
    var initialReviewFilter: Bool = false

    @Environment(\.modelContext) private var modelContext
    @Environment(LegislatorStore.self) private var legislatorStore
    @Query private var settingsResults: [UserSettings]
    @Query private var progressRecords: [QuestionProgress]
    @State private var currentIndex = 0
    @State private var isFlipped = false
    @State private var selectedCategory: QuestionCategory? = nil
    @State private var needsReviewOnly = false
    @State private var isShuffled = false
    @State private var shuffledQuestions: [Question]? = nil

    private var selectedState: StateInfo? {
        let stateId = settingsResults.first?.selectedStateId ?? "IL"
        return statesData.first { $0.id == stateId }
    }

    private var selectedDistrict: Int? {
        settingsResults.first?.selectedDistrict
    }

    private var reviewQuestionIds: Set<Int> {
        Set(progressRecords.filter { $0.progressStatus == .needsReview }.map { $0.questionId })
    }

    private var filteredQuestions: [Question] {
        var base: [Question]
        if needsReviewOnly {
            base = questionsData.filter { reviewQuestionIds.contains($0.id) }
        } else if let category = selectedCategory {
            base = questionsData.filter { $0.category == category }
        } else {
            base = questionsData
        }
        if isShuffled, let shuffled = shuffledQuestions {
            return shuffled.filter { q in base.contains { $0.id == q.id } }
        }
        return base
    }

    private var currentQuestion: Question? {
        guard currentIndex < filteredQuestions.count else { return nil }
        return filteredQuestions[currentIndex]
    }

    var body: some View {
        VStack(spacing: 16) {
            // Category filter
            CategoryFilterView(selected: $selectedCategory, needsReviewSelected: $needsReviewOnly)
                .onChange(of: selectedCategory) { _, _ in
                    currentIndex = 0
                    isFlipped = false
                }
                .onChange(of: needsReviewOnly) { _, _ in
                    currentIndex = 0
                    isFlipped = false
                }

            // Progress bar
            if !filteredQuestions.isEmpty {
                VStack(spacing: 4) {
                    ProgressView(value: Double(currentIndex + 1), total: Double(filteredQuestions.count))
                        .tint(.accentColor)
                    Text("\(currentIndex + 1) of \(filteredQuestions.count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)
            }

            // Card
            if let question = currentQuestion {
                FlashcardView(
                    question: question,
                    answers: question.answersForState(selectedState, legislators: legislatorStore, district: selectedDistrict),
                    isFlipped: $isFlipped
                )
                .id(question.id)
                .padding(.horizontal)

                // Controls (only when flipped)
                if isFlipped {
                    FlashcardControlsView(
                        onKnewIt: {
                            markAndAdvance(correct: true)
                        },
                        onReviewAgain: {
                            markAndAdvance(correct: false)
                        }
                    )
                    .padding(.horizontal)
                }
            } else {
                ContentUnavailableView("No Questions", systemImage: "questionmark.circle", description: Text("Select a category to get started"))
            }

            Spacer()

            // Navigation
            if !filteredQuestions.isEmpty {
                HStack {
                    Button {
                        guard currentIndex > 0 else { return }
                        currentIndex -= 1
                        isFlipped = false
                    } label: {
                        Image(systemName: "chevron.left.circle.fill")
                            .font(.title)
                    }
                    .disabled(currentIndex == 0)

                    Spacer()

                    Button {
                        isShuffled.toggle()
                        if isShuffled {
                            shuffledQuestions = questionsData.shuffled()
                        }
                        currentIndex = 0
                        isFlipped = false
                    } label: {
                        Image(systemName: isShuffled ? "shuffle.circle.fill" : "shuffle.circle")
                            .font(.title)
                    }

                    Spacer()

                    Button {
                        guard currentIndex < filteredQuestions.count - 1 else { return }
                        currentIndex += 1
                        isFlipped = false
                    } label: {
                        Image(systemName: "chevron.right.circle.fill")
                            .font(.title)
                    }
                    .disabled(currentIndex >= filteredQuestions.count - 1)
                }
                .padding(.horizontal, 40)
                .padding(.bottom)
            }
        }
        .navigationTitle("Flashcards")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            needsReviewOnly = initialReviewFilter
        }
    }

    private func markAndAdvance(correct: Bool) {
        guard let question = currentQuestion else { return }
        ProgressTracker.markStudied(questionId: question.id, correct: correct, context: modelContext)

        let generator = UIImpactFeedbackGenerator(style: correct ? .light : .medium)
        generator.impactOccurred()

        if currentIndex < filteredQuestions.count - 1 {
            currentIndex += 1
            isFlipped = false
        }
    }
}
