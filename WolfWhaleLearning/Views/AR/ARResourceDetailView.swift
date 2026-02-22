import SwiftUI

struct ARResourceDetailView: View {
    let resource: ARResource
    let viewModel: AppViewModel
    @State private var showARExperience = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                heroCard
                infoSection
                tagsSection
                aboutSection
                launchButton
            }
            .padding()
            .padding(.bottom, 20)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(resource.title)
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $showARExperience) {
            ARExperienceView(resource: resource)
        }
    }

    private var heroCard: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24)
                .fill(
                    MeshGradient(
                        width: 3, height: 3,
                        points: [
                            [0, 0], [0.5, 0], [1, 0],
                            [0, 0.5], [0.5, 0.5], [1, 0.5],
                            [0, 1], [0.5, 1], [1, 1]
                        ],
                        colors: [
                            Theme.courseColor(resource.colorName),
                            Theme.courseColor(resource.colorName).opacity(0.8),
                            .indigo,
                            Theme.courseColor(resource.colorName).opacity(0.6),
                            .purple,
                            Theme.courseColor(resource.colorName).opacity(0.7),
                            .indigo.opacity(0.8),
                            Theme.courseColor(resource.colorName).opacity(0.5),
                            Theme.courseColor(resource.colorName)
                        ]
                    )
                )
                .frame(height: 220)

            VStack(spacing: 16) {
                Image(systemName: resource.iconSystemName)
                    .font(.system(size: 64, weight: .light))
                    .foregroundStyle(.white)
                    .symbolEffect(.breathe, options: .repeating)

                VStack(spacing: 4) {
                    Text(resource.title)
                        .font(.title.bold())
                        .foregroundStyle(.white)
                    Text(resource.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.85))
                }
            }
        }
        .clipShape(.rect(cornerRadius: 24))
    }

    private var infoSection: some View {
        HStack(spacing: 0) {
            infoItem(icon: "clock.fill", value: "\(resource.estimatedDuration) min", label: "Duration")
            Divider().frame(height: 40)
            infoItem(icon: "graduationcap.fill", value: resource.gradeLevel, label: "Grades")
            Divider().frame(height: 40)
            infoItem(icon: resource.category.iconName, value: resource.category.rawValue, label: "Category")
        }
        .padding(.vertical, 16)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

    private func infoItem(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(Theme.courseColor(resource.colorName))
            Text(value)
                .font(.subheadline.bold())
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Topics")
                .font(.headline)

            FlowLayout(spacing: 8) {
                ForEach(resource.tags, id: \.self) { tag in
                    Text(tag)
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Theme.courseColor(resource.colorName).opacity(0.12), in: Capsule())
                        .foregroundStyle(Theme.courseColor(resource.colorName))
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("About This Experience")
                .font(.headline)
            Text(resource.description)
                .font(.body)
                .foregroundStyle(.secondary)
                .lineSpacing(4)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

    private var launchButton: some View {
        Button {
            showARExperience = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "arkit")
                    .font(.title3)
                Text("Launch AR Experience")
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
        }
        .buttonStyle(.borderedProminent)
        .tint(Theme.courseColor(resource.colorName))
        .sensoryFeedback(.impact(weight: .medium), trigger: showARExperience)
    }
}

private struct FlowLayout: Layout {
    let spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
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
