import SwiftUI

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    var actionLabel: String? = nil
    var action: (() -> Void)? = nil

    @State private var appeared = false
    @State private var iconBounce = false
    @State private var hapticTrigger = false

    var body: some View {
        VStack(spacing: 20) {
            // Animated SF Symbol icon
            Image(systemName: icon)
                .font(.system(size: 56))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.indigo, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .symbolEffect(.bounce, value: iconBounce)
                .opacity(appeared ? 1 : 0)
                .scaleEffect(appeared ? 1 : 0.6)
                .accessibilityHidden(true)

            VStack(spacing: 8) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)

                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 12)

            if let actionLabel, let action {
                Button {
                    hapticTrigger.toggle()
                    action()
                } label: {
                    Text(actionLabel)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(
                            LinearGradient(
                                colors: [.indigo, .purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            in: Capsule()
                        )
                }
                .buttonStyle(.plain)
                #if canImport(UIKit)
                .hapticFeedback(.impact(weight: .medium), trigger: hapticTrigger)
                #endif
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 16)
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            withAnimation(.spring(duration: 0.8, bounce: 0.3)) {
                appeared = true
            }
            // Trigger icon bounce after the view appears
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                iconBounce.toggle()
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(message)")
    }
}

// MARK: - Previews

#Preview("With Action") {
    ZStack {
        #if canImport(UIKit)
        Color(UIColor.systemGroupedBackground).ignoresSafeArea()
        #endif
        EmptyStateView(
            icon: "book.closed",
            title: "No Courses",
            message: "Browse the course catalog to get started with your learning journey.",
            actionLabel: "Browse Catalog",
            action: { }
        )
    }
}

#Preview("Without Action") {
    ZStack {
        #if canImport(UIKit)
        Color(UIColor.systemGroupedBackground).ignoresSafeArea()
        #endif
        EmptyStateView(
            icon: "tray",
            title: "No Notifications",
            message: "You're all caught up. Check back later for updates."
        )
    }
}
