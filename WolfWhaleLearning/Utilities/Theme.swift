import SwiftUI

struct Theme {
    static func roleColor(_ role: UserRole) -> Color {
        switch role {
        case .student: .indigo
        case .teacher: .pink
        case .parent: .green
        case .admin: .blue
        case .superAdmin: .purple
        }
    }

    static func gradeColor(_ grade: Double) -> Color {
        switch grade {
        case 90...: .green
        case 80..<90: .blue
        case 70..<80: .orange
        default: .red
        }
    }

    static func courseColor(_ name: String) -> Color {
        switch name {
        case "blue": .blue
        case "green": .green
        case "orange": .orange
        case "purple": .purple
        case "red": .red
        case "pink": .pink
        case "indigo": .indigo
        case "teal": .teal
        case "mint": .mint
        case "cyan": .cyan
        case "yellow": .yellow
        case "brown": .brown
        default: .blue
        }
    }
}

struct GlassCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }
}

struct StatRing: View {
    let progress: Double
    let color: Color
    let lineWidth: CGFloat
    let size: CGFloat

    init(progress: Double, color: Color, lineWidth: CGFloat = 6, size: CGFloat = 60) {
        self.progress = progress
        self.color = color
        self.lineWidth = lineWidth
        self.size = size
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.2), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: min(progress, 1.0))
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .frame(width: size, height: size)
    }
}

