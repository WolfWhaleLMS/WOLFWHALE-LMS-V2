import SwiftUI

struct CourseIconPicker: View {
    @Binding var selectedIcon: String
    var accentColor: Color = .purple
    @State private var hapticTrigger = false

    private let icons = [
        "book.fill", "atom", "function", "globe.americas.fill",
        "paintpalette.fill", "music.note", "figure.run",
        "laptopcomputer", "character.book.closed.fill", "flask.fill",
        "building.columns.fill", "leaf.fill", "heart.fill",
        "star.fill", "bolt.fill", "camera.fill"
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Course Icon", systemImage: "square.grid.2x2.fill")
                .font(.headline)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 10) {
                ForEach(icons, id: \.self) { iconName in
                    let isSelected = selectedIcon == iconName

                    Button {
                        hapticTrigger.toggle()
                        withAnimation(.snappy(duration: 0.2)) {
                            selectedIcon = iconName
                        }
                    } label: {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(isSelected ? accentColor.opacity(0.2) : Color(.tertiarySystemFill))
                            .frame(height: 52)
                            .overlay {
                                Image(systemName: iconName)
                                    .font(.title3)
                                    .foregroundStyle(isSelected ? accentColor : .secondary)
                            }
                            .overlay {
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(isSelected ? accentColor.opacity(0.6) : .clear, lineWidth: 2)
                            }
                    }
                    .buttonStyle(.plain)
                    .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
                    .accessibilityLabel(iconName.replacingOccurrences(of: ".", with: " ").replacingOccurrences(of: "fill", with: ""))
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))
    }
}
