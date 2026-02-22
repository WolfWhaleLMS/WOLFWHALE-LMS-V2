import SwiftUI

struct PlaybackSpeedPicker: View {
    @Binding var selectedSpeed: Float
    @State private var hapticTrigger = false

    private static let speeds: [Float] = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Self.speeds, id: \.self) { speed in
                let isSelected = selectedSpeed == speed
                Button {
                    hapticTrigger.toggle()
                    withAnimation(.snappy(duration: 0.2)) {
                        selectedSpeed = speed
                    }
                } label: {
                    Text(speedLabel(speed))
                        .font(.caption2.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(isSelected ? .white : .secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            isSelected
                                ? AnyShapeStyle(Color.indigo)
                                : AnyShapeStyle(Color.clear),
                            in: .capsule
                        )
                }
                .buttonStyle(.plain)
                #if canImport(UIKit)
                .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
                #endif
            }
        }
        .padding(4)
        .background(.ultraThinMaterial, in: .capsule)
    }

    // MARK: - Helpers

    private func speedLabel(_ speed: Float) -> String {
        if speed == Float(Int(speed)) {
            return "\(Int(speed))x"
        }
        return String(format: "%.2gx", speed)
    }
}
