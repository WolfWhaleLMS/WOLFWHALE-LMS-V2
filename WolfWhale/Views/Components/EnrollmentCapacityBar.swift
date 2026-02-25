import SwiftUI

struct EnrollmentCapacityBar: View {
    let current: Int
    let max: Int

    private var fraction: Double {
        guard max > 0 else { return 0 }
        return min(Double(current) / Double(max), 1.0)
    }

    private var percentage: Double {
        fraction * 100
    }

    private var barColor: Color {
        switch percentage {
        case 95...: .red
        case 80..<95: .orange
        case 50..<80: .yellow
        default: .green
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(barColor.opacity(0.2))

                    Capsule()
                        .fill(barColor.gradient)
                        .frame(width: geometry.size.width * fraction)
                }
            }
            .frame(height: 6)

            Text("\(current)/\(max)")
                .font(.caption2.bold())
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(current) of \(max) students enrolled")
        .accessibilityValue("\(Int(percentage)) percent capacity")
    }
}

#Preview {
    VStack(spacing: 16) {
        EnrollmentCapacityBar(current: 10, max: 30)
        EnrollmentCapacityBar(current: 18, max: 30)
        EnrollmentCapacityBar(current: 26, max: 30)
        EnrollmentCapacityBar(current: 30, max: 30)
    }
    .padding()
}
