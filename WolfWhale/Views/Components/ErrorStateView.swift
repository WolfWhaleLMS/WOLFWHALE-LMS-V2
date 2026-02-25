import SwiftUI

struct ErrorStateView: View {
    let message: String
    var retryAction: (() async -> Void)? = nil

    @State private var appeared = false
    @State private var hapticTrigger = false
    @State private var isRetrying = false
    @State private var iconShake = false

    var body: some View {
        VStack(spacing: 20) {
            // Error icon
            ZStack {
                Circle()
                    .fill(.red.opacity(0.12))
                    .frame(width: 80, height: 80)
                    .scaleEffect(appeared ? 1 : 0.5)

                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.red)
                    .symbolEffect(.bounce, value: iconShake)
            }
            .opacity(appeared ? 1 : 0)
            .accessibilityHidden(true)

            VStack(spacing: 8) {
                Text("Something went wrong")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)

                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(4)
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 12)

            if retryAction != nil {
                Button {
                    hapticTrigger.toggle()
                    performRetry()
                } label: {
                    HStack(spacing: 8) {
                        if isRetrying {
                            ProgressView()
                                .tint(.white)
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "arrow.clockwise")
                                .font(.subheadline.weight(.semibold))
                        }
                        Text(isRetrying ? "Retrying..." : "Try Again")
                            .font(.subheadline.weight(.semibold))
                    }
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
                .disabled(isRetrying)
                .opacity(isRetrying ? 0.7 : 1)
                #if canImport(UIKit)
                .sensoryFeedback(.impact(weight: .medium), trigger: hapticTrigger)
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
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                iconShake.toggle()
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Error: \(message)")
    }

    // MARK: - Retry

    private func performRetry() {
        guard let retryAction, !isRetrying else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            isRetrying = true
        }
        Task {
            await retryAction()
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isRetrying = false
                }
            }
        }
    }
}

// MARK: - Previews

#Preview("With Retry") {
    ZStack {
        #if canImport(UIKit)
        Color(UIColor.systemGroupedBackground).ignoresSafeArea()
        #endif
        ErrorStateView(
            message: "Unable to load your courses. Please check your internet connection and try again.",
            retryAction: {
                try? await Task.sleep(for: .seconds(2))
            }
        )
    }
}

#Preview("Without Retry") {
    ZStack {
        #if canImport(UIKit)
        Color(UIColor.systemGroupedBackground).ignoresSafeArea()
        #endif
        ErrorStateView(
            message: "This content is no longer available."
        )
    }
}
