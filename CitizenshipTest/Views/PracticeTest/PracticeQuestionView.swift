import SwiftUI

struct PracticeQuestionView: View {
    let questionNumber: Int
    let question: Question
    @Binding var answer: String
    let onNext: () -> Void
    let isLast: Bool

    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Question number badge
            HStack {
                Text("Question \(questionNumber) of 20")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)

                Spacer()

                HStack(spacing: 4) {
                    Image(systemName: question.category.icon)
                    Text(question.category.displayName)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            // Question text
            Text(question.text)
                .font(.title3)
                .fontWeight(.semibold)
                .fixedSize(horizontal: false, vertical: true)

            // Answer field
            TextField("Type your answer...", text: $answer, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(3...6)
                .focused($isFocused)
                .submitLabel(isLast ? .done : .next)
                .onSubmit {
                    onNext()
                }

            Spacer()
        }
        .padding()
        .onAppear {
            isFocused = true
        }
    }
}
