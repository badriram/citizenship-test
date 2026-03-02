import SwiftUI

struct FlashcardControlsView: View {
    let onKnewIt: () -> Void
    let onReviewAgain: () -> Void

    var body: some View {
        HStack(spacing: 20) {
            Button(action: onReviewAgain) {
                Label("Review Again", systemImage: "arrow.clockwise")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.orange.opacity(0.15))
                    .foregroundStyle(.orange)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            Button(action: onKnewIt) {
                Label("I Knew This", systemImage: "checkmark.circle.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green.opacity(0.15))
                    .foregroundStyle(.green)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }
}
