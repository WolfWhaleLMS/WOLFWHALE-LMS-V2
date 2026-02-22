import SwiftUI

struct LoadingOverlay: View {
    let message: String

    @State private var appeared = false
    @State private var pulseScale: CGFloat = 1.0

    var body: some View {
        ZStack {
            // Full-screen dimming material
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()
                .opacity(appeared ? 1 : 0)

            // Centered loading card
            VStack(spacing: 20) {
                ZStack {
                    // Pulsing background ring
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.indigo.opacity(0.15), .purple.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 72, height: 72)
                        .scaleEffect(pulseScale)

                    ProgressView()
                        .controlSize(.large)
                        .tint(.indigo)
                }

                Text(message)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .padding(32)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(
                        LinearGradient(
                            colors: [.indigo.opacity(0.2), .purple.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: .black.opacity(0.08), radius: 20, y: 10)
            .scaleEffect(appeared ? 1 : 0.85)
            .opacity(appeared ? 1 : 0)
        }
        .onAppear {
            withAnimation(.spring(duration: 0.5, bounce: 0.2)) {
                appeared = true
            }
            withAnimation(
                .easeInOut(duration: 1.2)
                .repeatForever(autoreverses: true)
            ) {
                pulseScale = 1.15
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Loading. \(message)")
        .accessibilityAddTraits(.updatesFrequently)
    }
}

// MARK: - View Extension

extension View {
    /// Overlays a loading indicator with a message on top of the current view.
    /// - Parameters:
    ///   - isPresented: Binding controlling the overlay visibility.
    ///   - message: The message displayed beneath the spinner.
    func loadingOverlay(isPresented: Bool, message: String = "Loading...") -> some View {
        ZStack {
            self

            if isPresented {
                LoadingOverlay(message: message)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .animation(.spring(duration: 0.4, bounce: 0.15), value: isPresented)
    }
}

// MARK: - Previews

#Preview("Loading Overlay") {
    ZStack {
        #if canImport(UIKit)
        Color(UIColor.systemGroupedBackground).ignoresSafeArea()
        #endif

        VStack {
            Text("Background Content")
                .font(.title)
            Text("This is behind the overlay")
                .foregroundStyle(.secondary)
        }

        LoadingOverlay(message: "Loading your courses...")
    }
}

#Preview("Overlay Modifier") {
    List {
        ForEach(0..<10, id: \.self) { i in
            Text("Item \(i)")
        }
    }
    .loadingOverlay(isPresented: true, message: "Syncing data...")
}
