import SwiftUI

struct FlashcardView: View {
    let question: Question
    let answers: [String]
    @Binding var isFlipped: Bool

    var body: some View {
        ZStack {
            // Front (question)
            cardContent(isFront: true)
                .rotation3DEffect(.degrees(isFlipped ? 180 : 0), axis: (x: 0, y: 1, z: 0))
                .opacity(isFlipped ? 0 : 1)

            // Back (answers)
            cardContent(isFront: false)
                .rotation3DEffect(.degrees(isFlipped ? 0 : -180), axis: (x: 0, y: 1, z: 0))
                .opacity(isFlipped ? 1 : 0)
        }
        .frame(maxWidth: .infinity, minHeight: 300)
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.4)) {
                isFlipped.toggle()
            }
        }
        .accessibilityAction {
            isFlipped.toggle()
        }
        .accessibilityLabel(isFlipped ? "Answer card" : "Question card")
        .accessibilityHint("Double tap to flip")
    }

    @ViewBuilder
    private func cardContent(isFront: Bool) -> some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: question.category.icon)
                Text(question.category.displayName)
                    .font(.caption)
                Spacer()
                Text("Q\(question.id)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .foregroundStyle(.secondary)

            Spacer()

            if isFront {
                Text(question.text)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)

                Spacer()

                Text("Tap to reveal answer")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            } else {
                VStack(spacing: 8) {
                    ForEach(answers, id: \.self) { answer in
                        Text(answer)
                            .font(.body)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                }

                Spacer()

                Text("Tap to see question")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, minHeight: 300)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
    }
}
