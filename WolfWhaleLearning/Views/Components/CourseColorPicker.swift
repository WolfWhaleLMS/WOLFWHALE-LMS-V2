import SwiftUI

struct CourseColorPicker: View {
    @Binding var selectedColor: String
    @State private var hapticTrigger = false

    private let colors: [(name: String, color: Color)] = [
        ("red", .red), ("orange", .orange), ("yellow", .yellow),
        ("green", .green), ("teal", .teal), ("blue", .blue),
        ("indigo", .indigo), ("purple", .purple), ("pink", .pink),
        ("brown", .brown)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Course Color", systemImage: "paintpalette.fill")
                .font(.headline)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 5), spacing: 10) {
                ForEach(colors, id: \.name) { item in
                    let isSelected = selectedColor == item.name

                    Button {
                        hapticTrigger.toggle()
                        withAnimation(.snappy(duration: 0.2)) {
                            selectedColor = item.name
                        }
                    } label: {
                        Circle()
                            .fill(item.color.gradient)
                            .frame(width: 44, height: 44)
                            .overlay {
                                if isSelected {
                                    Image(systemName: "checkmark")
                                        .font(.callout.bold())
                                        .foregroundStyle(.white)
                                }
                            }
                            .overlay {
                                Circle()
                                    .stroke(isSelected ? item.color : .clear, lineWidth: 3)
                                    .padding(-4)
                            }
                    }
                    .buttonStyle(.plain)
                    .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
                    .accessibilityLabel(item.name)
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))
    }
}
