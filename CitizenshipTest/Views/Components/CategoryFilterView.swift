import SwiftUI

struct CategoryFilterView: View {
    @Binding var selected: QuestionCategory?
    var needsReviewSelected: Binding<Bool>?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(title: "All", isSelected: selected == nil && !(needsReviewSelected?.wrappedValue ?? false)) {
                    selected = nil
                    needsReviewSelected?.wrappedValue = false
                }
                if let needsReviewSelected {
                    FilterChip(title: "Needs Review", icon: "arrow.clockwise", isSelected: needsReviewSelected.wrappedValue) {
                        needsReviewSelected.wrappedValue = true
                        selected = nil
                    }
                }
                ForEach(QuestionCategory.allCases) { category in
                    FilterChip(
                        title: category.displayName,
                        icon: category.icon,
                        isSelected: selected == category && !(needsReviewSelected?.wrappedValue ?? false)
                    ) {
                        selected = category
                        needsReviewSelected?.wrappedValue = false
                    }
                }
            }
            .padding(.horizontal)
        }
    }
}

private struct FilterChip: View {
    let title: String
    var icon: String? = nil
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let icon {
                    Image(systemName: icon)
                        .font(.caption2)
                }
                Text(title)
                    .font(.caption)
                    .fontWeight(isSelected ? .semibold : .regular)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? Color.accentColor : Color(.secondarySystemBackground))
            .foregroundStyle(isSelected ? .white : .primary)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
