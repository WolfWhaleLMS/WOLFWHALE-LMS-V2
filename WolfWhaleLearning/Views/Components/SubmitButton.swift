import SwiftUI

// MARK: - SubmitButton

struct SubmitButton: View {
    let title: String
    let icon: String?
    var style: SubmitButtonStyle = .primary
    var isEnabled: Bool = true
    let action: () async -> Void

    @State private var isSubmitting = false
    @State private var hapticTrigger = false

    // MARK: - Style

    enum SubmitButtonStyle {
        case primary      // indigo filled
        case secondary    // indigo outline
        case destructive  // red filled
    }

    // MARK: - Body

    var body: some View {
        Button {
            guard !isSubmitting else { return }
            isSubmitting = true
            hapticTrigger.toggle()
            Task {
                await action()
                isSubmitting = false
            }
        } label: {
            HStack(spacing: 8) {
                if isSubmitting {
                    ProgressView()
                        .tint(foregroundForStyle)
                } else if let icon {
                    Image(systemName: icon)
                }
                Text(isSubmitting ? "Submitting..." : title)
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(backgroundForStyle)
            .foregroundStyle(foregroundForStyle)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay {
                if style == .secondary {
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(.indigo, lineWidth: 1.5)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled || isSubmitting)
        .opacity(isEnabled && !isSubmitting ? 1.0 : 0.6)
        .sensoryFeedback(.impact(weight: .medium), trigger: hapticTrigger)
        .accessibilityLabel(isSubmitting ? "Submitting" : title)
        .accessibilityAddTraits(.isButton)
    }

    // MARK: - Style Helpers

    @ViewBuilder
    private var backgroundForStyle: some View {
        switch style {
        case .primary:
            LinearGradient(
                colors: [.indigo, .purple],
                startPoint: .leading,
                endPoint: .trailing
            )
        case .secondary:
            Color.clear
        case .destructive:
            Color.red
        }
    }

    private var foregroundForStyle: Color {
        switch style {
        case .primary:
            .white
        case .secondary:
            .indigo
        case .destructive:
            .white
        }
    }
}

// MARK: - Convenience Initializers

extension SubmitButton {
    /// Creates a submit button without an icon.
    init(
        _ title: String,
        style: SubmitButtonStyle = .primary,
        isEnabled: Bool = true,
        action: @escaping () async -> Void
    ) {
        self.title = title
        self.icon = nil
        self.style = style
        self.isEnabled = isEnabled
        self.action = action
    }
}

// MARK: - Previews

#Preview("Primary") {
    ZStack {
        #if canImport(UIKit)
        Color(UIColor.systemGroupedBackground).ignoresSafeArea()
        #endif
        VStack(spacing: 16) {
            SubmitButton(
                title: "Submit Assignment",
                icon: "paperplane.fill",
                style: .primary,
                action: {
                    try? await Task.sleep(for: .seconds(2))
                }
            )

            SubmitButton(
                title: "Save Draft",
                icon: "square.and.arrow.down",
                style: .secondary,
                action: {
                    try? await Task.sleep(for: .seconds(2))
                }
            )

            SubmitButton(
                title: "Delete Course",
                icon: "trash",
                style: .destructive,
                action: {
                    try? await Task.sleep(for: .seconds(2))
                }
            )

            SubmitButton(
                title: "Disabled Button",
                icon: "lock.fill",
                style: .primary,
                isEnabled: false,
                action: { }
            )
        }
        .padding()
    }
}
