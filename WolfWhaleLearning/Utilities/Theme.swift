import SwiftUI

struct Theme {
    // MARK: - Brand Colors

    /// Primary brand blue (#1E6EF4)
    static let brandBlue = Color(red: 30 / 255, green: 110 / 255, blue: 244 / 255)

    /// Secondary brand green (#34C759)
    static let brandGreen = Color(red: 52 / 255, green: 199 / 255, blue: 89 / 255)

    /// Tertiary brand purple (#564ADE)
    static let brandPurple = Color(red: 86 / 255, green: 74 / 255, blue: 222 / 255)

    /// Standard brand gradient: purple to blue, top-leading to bottom-trailing
    static let brandGradient = LinearGradient(
        colors: [brandPurple, brandBlue],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Horizontal brand gradient variant for buttons and bars
    static let brandGradientHorizontal = LinearGradient(
        colors: [brandPurple, brandBlue],
        startPoint: .leading,
        endPoint: .trailing
    )

    /// Brand gradient colors array for use in custom gradients
    static let brandGradientColors: [Color] = [brandPurple, brandBlue]

    /// Subtle brand gradient (with opacity) for backgrounds
    static let brandGradientSubtle = LinearGradient(
        colors: [brandPurple.opacity(0.15), brandBlue.opacity(0.15)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // MARK: - Role Colors

    static func roleColor(_ role: UserRole) -> Color {
        switch role {
        case .student: brandPurple
        case .teacher: .orange
        case .parent: .green
        case .admin: brandBlue
        case .superAdmin: brandPurple
        }
    }

    // MARK: - Semantic Colors

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
        case "pink": .mint
        case "indigo": .indigo
        case "teal": .teal
        case "mint": .mint
        case "cyan": .cyan
        case "yellow": .yellow
        case "brown": .brown
        case "gray": .gray
        default: .blue
        }
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
