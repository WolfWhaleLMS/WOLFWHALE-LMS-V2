import SwiftUI

struct ActivityRingView: View {
    let lessonsProgress: Double
    let assignmentsProgress: Double
    let xpProgress: Double
    @State private var animatedProgress: [Double] = [0, 0, 0]

    var body: some View {
        ZStack {
            ring(progress: animatedProgress[0], color: .green, padding: 0)
            ring(progress: animatedProgress[1], color: .cyan, padding: 20)
            ring(progress: animatedProgress[2], color: .purple, padding: 40)

            VStack(spacing: 2) {
                Image(systemName: "flame.fill")
                    .font(.title2)
                    .foregroundStyle(.orange)
                Text("Today")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 140, height: 140)
        .onAppear {
            withAnimation(.spring(duration: 1.2, bounce: 0.2).delay(0.2)) {
                animatedProgress = [lessonsProgress, assignmentsProgress, xpProgress]
            }
        }
    }

    private func ring(progress: Double, color: Color, padding: CGFloat) -> some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.15), lineWidth: 14)
            Circle()
                .trim(from: 0, to: min(progress, 1.0))
                .stroke(
                    AngularGradient(
                        colors: [color, color.opacity(0.7), color],
                        center: .center,
                        startAngle: .degrees(-90),
                        endAngle: .degrees(270)
                    ),
                    style: StrokeStyle(lineWidth: 14, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
        }
        .padding(padding)
    }
}

struct ActivityRingLabel: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.caption.bold())
            }
        }
    }
}
