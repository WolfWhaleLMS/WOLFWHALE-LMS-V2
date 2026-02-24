import SwiftUI

// MARK: - AsyncButton

/// A button that runs an async action and shows a `ProgressView` while the action is in flight.
///
/// Use this for inline async actions (e.g. "Enroll", "Bookmark") where a full-width
/// `SubmitButton` would be too heavy. For form submissions, prefer `SubmitButton`.
///
/// Usage:
/// ```swift
/// AsyncButton {
///     await viewModel.enroll(in: course)
/// } label: {
///     Label("Enroll", systemImage: "plus.circle.fill")
/// }
/// ```
struct AsyncButton<Label: View>: View {
    let action: () async -> Void
    @ViewBuilder let label: () -> Label

    @State private var isRunning = false
    @State private var hapticTrigger = false

    var body: some View {
        Button {
            guard !isRunning else { return }
            isRunning = true
            hapticTrigger.toggle()
            Task {
                await action()
                isRunning = false
            }
        } label: {
            if isRunning {
                ProgressView()
            } else {
                label()
            }
        }
        .disabled(isRunning)
        .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
        .accessibilityLabel(isRunning ? "Loading" : "")
    }
}

// MARK: - Convenience

extension AsyncButton where Label == SwiftUI.Label<Text, Image> {
    /// Creates an `AsyncButton` with a title and SF Symbol icon.
    init(
        _ titleKey: LocalizedStringKey,
        systemImage: String,
        action: @escaping () async -> Void
    ) {
        self.action = action
        self.label = {
            SwiftUI.Label(titleKey, systemImage: systemImage)
        }
    }
}

// MARK: - Previews

#Preview {
    ZStack {
        #if canImport(UIKit)
        Color(UIColor.systemGroupedBackground).ignoresSafeArea()
        #endif
        VStack(spacing: 20) {
            AsyncButton {
                try? await Task.sleep(for: .seconds(2))
            } label: {
                Label("Enroll Now", systemImage: "plus.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(.indigo, in: Capsule())
            }

            AsyncButton("Bookmark", systemImage: "bookmark") {
                try? await Task.sleep(for: .seconds(1))
            }
            .buttonStyle(.bordered)
            .tint(.indigo)
        }
    }
}
