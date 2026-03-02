import SwiftUI

struct PracticeResultsView: View {
    let engine: QuizEngine
    let selectedState: StateInfo?
    let legislatorStore: LegislatorStore?
    let district: Int?
    let onRetake: () -> Void

    init(engine: QuizEngine, selectedState: StateInfo?, legislatorStore: LegislatorStore? = nil, district: Int? = nil, onRetake: @escaping () -> Void) {
        self.engine = engine
        self.selectedState = selectedState
        self.legislatorStore = legislatorStore
        self.district = district
        self.onRetake = onRetake
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Pass/Fail banner
                VStack(spacing: 12) {
                    Image(systemName: engine.isPassing ? "checkmark.seal.fill" : "xmark.seal.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(engine.isPassing ? .green : .red)

                    Text(engine.isPassing ? "You Passed!" : "Not Yet Passing")
                        .font(.title)
                        .fontWeight(.bold)

                    Text("\(engine.score) out of \(QuizEngine.totalQuestions) correct")
                        .font(.title3)
                        .foregroundStyle(.secondary)

                    Text(engine.isPassing ? "Great job! You met the 60% passing threshold." : "You need at least \(QuizEngine.passingScore) correct. Keep studying!")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()

                // Score bar
                ProgressView(value: Double(engine.score), total: Double(QuizEngine.totalQuestions))
                    .tint(engine.isPassing ? .green : .red)
                    .padding(.horizontal)

                Divider()

                // Detailed results
                VStack(alignment: .leading, spacing: 16) {
                    Text("Question Review")
                        .font(.headline)
                        .padding(.horizontal)

                    ForEach(engine.results) { result in
                        ResultRow(result: result, selectedState: selectedState, legislatorStore: legislatorStore, district: district)
                    }
                }

                // Retake button
                Button(action: onRetake) {
                    Label("Take Another Test", systemImage: "arrow.clockwise")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal)
                .padding(.bottom, 40)
            }
        }
    }
}

private struct ResultRow: View {
    let result: QuizResult
    let selectedState: StateInfo?
    let legislatorStore: LegislatorStore?
    let district: Int?

    init(result: QuizResult, selectedState: StateInfo?, legislatorStore: LegislatorStore? = nil, district: Int? = nil) {
        self.result = result
        self.selectedState = selectedState
        self.legislatorStore = legislatorStore
        self.district = district
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                Image(systemName: result.isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(result.isCorrect ? .green : .red)
                    .font(.title3)

                VStack(alignment: .leading, spacing: 4) {
                    Text(result.question.text)
                        .font(.subheadline)
                        .fontWeight(.medium)

                    if !result.userAnswer.isEmpty {
                        Text("Your answer: \(result.userAnswer)")
                            .font(.caption)
                            .foregroundStyle(result.isCorrect ? .green : .red)
                    } else {
                        Text("No answer provided")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    let accepted = result.question.answersForState(selectedState, legislators: legislatorStore, district: district)
                    Text("Accepted: \(accepted.joined(separator: "; "))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(result.isCorrect ? Color.green.opacity(0.05) : Color.red.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal)
    }
}
