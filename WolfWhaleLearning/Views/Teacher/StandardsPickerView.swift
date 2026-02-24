import SwiftUI

struct StandardsPickerView: View {
    @Bindable var viewModel: AppViewModel
    @Binding var selectedStandardIds: [UUID]

    @State private var searchText = ""
    @State private var selectedSubject: String?
    @State private var hapticTrigger = false

    @Environment(\.dismiss) private var dismiss

    private var allStandards: [LearningStandard] {
        viewModel.storedLearningStandards
    }

    private var subjects: [String] {
        Array(Set(allStandards.map(\.subject))).sorted()
    }

    private var filteredStandards: [LearningStandard] {
        var result = allStandards

        if let subject = selectedSubject {
            result = result.filter { $0.subject == subject }
        }

        if !searchText.isEmpty {
            let query = searchText.lowercased()
            result = result.filter {
                $0.code.lowercased().contains(query) ||
                $0.title.lowercased().contains(query) ||
                $0.description.lowercased().contains(query) ||
                $0.category.lowercased().contains(query)
            }
        }

        return result
    }

    /// Group filtered standards by category for display.
    private var groupedStandards: [(category: String, standards: [LearningStandard])] {
        let grouped = Dictionary(grouping: filteredStandards) { $0.category }
        return grouped.map { (category: $0.key, standards: $0.value) }
            .sorted { $0.category.localizedStandardCompare($1.category) == .orderedAscending }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Subject filter chips
                subjectFilterBar

                // Standards list
                if filteredStandards.isEmpty {
                    emptyState
                } else {
                    standardsList
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Learning Standards")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search by code, title, or topic")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        hapticTrigger.toggle()
                        dismiss()
                    }
                    .hapticFeedback(.impact(weight: .light), trigger: hapticTrigger)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done (\(selectedStandardIds.count))") {
                        hapticTrigger.toggle()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .hapticFeedback(.impact(weight: .medium), trigger: hapticTrigger)
                }
            }
        }
    }

    // MARK: - Subject Filter Bar

    private var subjectFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterChip(label: "All Subjects", isSelected: selectedSubject == nil) {
                    selectedSubject = nil
                }
                ForEach(subjects, id: \.self) { subject in
                    filterChip(label: subject, isSelected: selectedSubject == subject) {
                        selectedSubject = selectedSubject == subject ? nil : subject
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
        }
        .background(Color(.secondarySystemGroupedBackground))
    }

    private func filterChip(label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            hapticTrigger.toggle()
            action()
        } label: {
            Text(label)
                .font(.caption.bold())
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(
                    isSelected ? Color.accentColor : Color(.tertiarySystemGroupedBackground),
                    in: Capsule()
                )
                .foregroundStyle(isSelected ? .white : Color(.label))
        }
        .hapticFeedback(.impact(weight: .light), trigger: hapticTrigger)
        .accessibilityLabel("\(label) filter")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            Text("No Standards Found")
                .font(.headline)
                .foregroundStyle(Color(.label))
            Text("Try adjusting your search or filter.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 60)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Standards List

    private var standardsList: some View {
        ScrollView {
            LazyVStack(spacing: 12, pinnedViews: .sectionHeaders) {
                // Selection summary at top
                if !selectedStandardIds.isEmpty {
                    selectionSummary
                }

                ForEach(groupedStandards, id: \.category) { group in
                    Section {
                        ForEach(group.standards) { standard in
                            standardRow(standard)
                        }
                    } header: {
                        HStack {
                            Text(group.category)
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                                .textCase(.uppercase)
                            Spacer()
                        }
                        .padding(.horizontal, 4)
                        .padding(.vertical, 6)
                        .background(Color(.systemGroupedBackground))
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
    }

    // MARK: - Selection Summary

    private var selectionSummary: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("\(selectedStandardIds.count) standard\(selectedStandardIds.count == 1 ? "" : "s") selected")
                    .font(.subheadline.bold())
                    .foregroundStyle(Color(.label))
                Spacer()
                Button("Clear All") {
                    hapticTrigger.toggle()
                    selectedStandardIds.removeAll()
                }
                .font(.caption.bold())
                .foregroundStyle(.red)
                .hapticFeedback(.impact(weight: .light), trigger: hapticTrigger)
            }

            // Show selected standard codes
            FlowLayout(spacing: 6) {
                ForEach(selectedStandardIds, id: \.self) { sid in
                    if let std = allStandards.first(where: { $0.id == sid }) {
                        Text(std.code)
                            .font(.caption2.bold())
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.accentColor.opacity(0.15), in: Capsule())
                            .foregroundStyle(Color.accentColor)
                    }
                }
            }
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Standard Row

    private func standardRow(_ standard: LearningStandard) -> some View {
        let isSelected = selectedStandardIds.contains(standard.id)

        return Button {
            hapticTrigger.toggle()
            if isSelected {
                selectedStandardIds.removeAll { $0 == standard.id }
            } else {
                selectedStandardIds.append(standard.id)
            }
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? .green : .secondary)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(standard.code)
                            .font(.caption.bold())
                            .foregroundStyle(Color.accentColor)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 4))
                        Text(standard.gradeLevel)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 4))
                    }
                    Text(standard.title)
                        .font(.subheadline.bold())
                        .foregroundStyle(Color(.label))
                        .multilineTextAlignment(.leading)
                    Text(standard.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 0)
            }
            .padding(12)
            .background(
                isSelected ? Color.accentColor.opacity(0.06) : Color(.secondarySystemGroupedBackground),
                in: RoundedRectangle(cornerRadius: 12)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(isSelected ? Color.accentColor.opacity(0.3) : .clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .hapticFeedback(.impact(weight: .light), trigger: hapticTrigger)
        .accessibilityLabel("\(standard.code): \(standard.title)")
        .accessibilityHint(isSelected ? "Selected. Double tap to deselect." : "Double tap to select.")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Simple Flow Layout for Tag Display

/// A simple horizontal wrapping layout for displaying tags / chips.
private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = computeLayout(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = computeLayout(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func computeLayout(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            totalHeight = y + rowHeight
        }

        return (CGSize(width: maxWidth, height: totalHeight), positions)
    }
}
