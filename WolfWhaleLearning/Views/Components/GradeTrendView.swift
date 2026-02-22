import SwiftUI

struct GradeTrendView: View {
    let dataPoints: [Double]
    let trend: GradeTrend

    private var trendColor: Color {
        switch trend {
        case .improving: return .green
        case .declining: return .red
        case .stable: return .gray
        }
    }

    private var minValue: Double {
        guard let minVal = dataPoints.min() else { return 0 }
        return max(0, minVal - 10)
    }

    private var maxValue: Double {
        guard let maxVal = dataPoints.max() else { return 100 }
        return min(100, maxVal + 10)
    }

    private var range: Double {
        let r = maxValue - minValue
        return r > 0 ? r : 1
    }

    var body: some View {
        HStack(spacing: 4) {
            sparkline
            arrowIndicator
        }
    }

    private var sparkline: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            let points = normalizedPoints(width: width, height: height)

            ZStack {
                // Gradient fill under the line
                if points.count >= 2 {
                    Path { path in
                        path.move(to: CGPoint(x: points[0].x, y: height))
                        path.addLine(to: points[0])
                        for point in points.dropFirst() {
                            path.addLine(to: point)
                        }
                        path.addLine(to: CGPoint(x: points[points.count - 1].x, y: height))
                        path.closeSubpath()
                    }
                    .fill(
                        LinearGradient(
                            colors: [trendColor.opacity(0.3), trendColor.opacity(0.02)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }

                // The line itself
                if points.count >= 2 {
                    Path { path in
                        path.move(to: points[0])
                        for point in points.dropFirst() {
                            path.addLine(to: point)
                        }
                    }
                    .stroke(trendColor, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                }

                // Dots at each data point
                ForEach(Array(points.enumerated()), id: \.offset) { _, point in
                    Circle()
                        .fill(trendColor)
                        .frame(width: 4, height: 4)
                        .position(point)
                }
            }
        }
    }

    private var arrowIndicator: some View {
        Image(systemName: trend.iconName)
            .font(.caption2.bold())
            .foregroundStyle(trendColor)
            .frame(width: 14)
    }

    // MARK: - Helpers

    private func normalizedPoints(width: CGFloat, height: CGFloat) -> [CGPoint] {
        guard dataPoints.count >= 2 else {
            if let single = dataPoints.first {
                let y = height - ((single - minValue) / range * height)
                return [CGPoint(x: width / 2, y: y)]
            }
            return []
        }

        let stepX = width / CGFloat(dataPoints.count - 1)
        return dataPoints.enumerated().map { index, value in
            let x = CGFloat(index) * stepX
            let normalized = (value - minValue) / range
            let y = height - (normalized * height)
            return CGPoint(x: x, y: max(2, min(height - 2, y)))
        }
    }
}

// MARK: - Inline Badge Variant

/// A small inline trend badge showing arrow + label, used inside list rows.
struct GradeTrendBadge: View {
    let trend: GradeTrend

    private var trendColor: Color {
        switch trend {
        case .improving: return .green
        case .declining: return .red
        case .stable: return .gray
        }
    }

    private var label: String {
        switch trend {
        case .improving: return "Up"
        case .declining: return "Down"
        case .stable: return "Stable"
        }
    }

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: trend.iconName)
                .font(.caption2.bold())
            Text(label)
                .font(.caption2)
        }
        .foregroundStyle(trendColor)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(trendColor.opacity(0.12), in: .capsule)
    }
}
