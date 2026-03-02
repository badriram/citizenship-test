import SwiftUI
import SwiftData

struct PracticeTestView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(LegislatorStore.self) private var legislatorStore
    @Query private var settingsResults: [UserSettings]
    @State private var engine: QuizEngine?

    private var selectedState: StateInfo? {
        let stateId = settingsResults.first?.selectedStateId ?? "IL"
        return statesData.first { $0.id == stateId }
    }

    private var selectedDistrict: Int? {
        settingsResults.first?.selectedDistrict
    }

    var body: some View {
        Group {
            if let engine {
                if engine.isFinished {
                    PracticeResultsView(engine: engine, selectedState: selectedState, legislatorStore: legislatorStore, district: selectedDistrict) {
                        startNewTest()
                    }
                } else {
                    testContent(engine: engine)
                }
            } else {
                ProgressView()
            }
        }
        .navigationTitle("Practice Test")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if engine == nil {
                startNewTest()
            }
        }
    }

    @ViewBuilder
    private func testContent(engine: QuizEngine) -> some View {
        VStack(spacing: 0) {
            // Progress bar
            ProgressView(value: Double(engine.currentIndex + 1), total: Double(QuizEngine.totalQuestions))
                .tint(.accentColor)
                .padding(.horizontal)

            // Question
            PracticeQuestionView(
                questionNumber: engine.currentIndex + 1,
                question: engine.questions[engine.currentIndex],
                answer: Binding(
                    get: { engine.answers[engine.currentIndex] ?? "" },
                    set: { engine.submitAnswer($0) }
                ),
                onNext: {
                    if engine.currentIndex < QuizEngine.totalQuestions - 1 {
                        engine.nextQuestion()
                    }
                },
                isLast: engine.currentIndex == QuizEngine.totalQuestions - 1
            )
            .id(engine.currentIndex)

            Spacer()

            // Bottom navigation
            HStack {
                Button {
                    engine.previousQuestion()
                } label: {
                    Label("Previous", systemImage: "chevron.left")
                }
                .disabled(engine.currentIndex == 0)

                Spacer()

                if engine.currentIndex == QuizEngine.totalQuestions - 1 {
                    Button {
                        engine.finishTest()
                        recordResults(engine)

                        let generator = UINotificationFeedbackGenerator()
                        generator.notificationOccurred(engine.isPassing ? .success : .warning)
                    } label: {
                        Label("Submit Test", systemImage: "checkmark.circle.fill")
                            .fontWeight(.semibold)
                    }
                    .tint(.green)
                } else {
                    Button {
                        engine.nextQuestion()
                    } label: {
                        Label("Next", systemImage: "chevron.right")
                    }
                }
            }
            .padding()
        }
    }

    private func startNewTest() {
        engine = QuizEngine(state: selectedState, legislatorStore: legislatorStore, district: selectedDistrict)
    }

    private func recordResults(_ engine: QuizEngine) {
        for result in engine.results {
            ProgressTracker.markStudied(
                questionId: result.question.id,
                correct: result.isCorrect,
                context: modelContext
            )
        }
    }
}
