import SwiftUI

/// Error boundary wrapper that catches task failures and presents recovery UI
/// Usage: ErrorBoundaryView { MyContentView() }
struct ErrorBoundaryView<Content: View>: View {
    let content: () -> Content

    @State private var error: Error?
    @State private var hasError = false

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        Group {
            if hasError, let error {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.orange)
                        .symbolEffect(.pulse)

                    Text("Unable to Load")
                        .font(.title3.bold())

                    Text(UserFacingError.message(from: error))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    Button("Try Again") {
                        hasError = false
                        self.error = nil
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
            } else {
                content()
            }
        }
    }
}
