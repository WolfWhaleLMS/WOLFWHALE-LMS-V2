import SwiftUI

struct WhatsNewView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var appeared = false
    @State private var hapticTrigger = false

    /// The version string shown in the header. Defaults to the current bundle version.
    private let version: String

    /// Feature entries to display. Each entry has an icon, color, title, and description.
    private let features: [WhatsNewFeature]

    // MARK: - Init

    init() {
        self.version = OnboardingManager.currentAppVersion
        self.features = Self.currentFeatures
    }

    var body: some View {
        ZStack {
            #if canImport(UIKit)
            Color(UIColor.systemGroupedBackground)
                .ignoresSafeArea()
            #endif

            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 28) {
                        // Header
                        headerSection
                            .padding(.top, 40)

                        // Feature list
                        VStack(spacing: 16) {
                            ForEach(Array(features.enumerated()), id: \.element.id) { index, feature in
                                featureRow(feature: feature)
                                    .opacity(appeared ? 1 : 0)
                                    .offset(y: appeared ? 0 : 20)
                                    .animation(
                                        .spring(duration: 0.5).delay(Double(index) * 0.1),
                                        value: appeared
                                    )
                            }
                        }
                        .padding(.horizontal, 24)
                    }
                }

                // Continue button
                VStack(spacing: 0) {
                    Divider()
                        .opacity(0.3)

                    Button {
                        hapticTrigger.toggle()
                        OnboardingManager.markVersionSeen()
                        dismiss()
                    } label: {
                        Text("Continue")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.indigo)
                    .clipShape(.rect(cornerRadius: 16))
                    .padding(.horizontal, 32)
                    .padding(.vertical, 16)
                    .shadow(color: .indigo.opacity(0.3), radius: 12, y: 6)
                    .sensoryFeedback(.impact(weight: .medium), trigger: hapticTrigger)
                }
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.4)) {
                appeared = true
            }
        }
        .interactiveDismissDisabled()
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.indigo.opacity(0.2), .purple.opacity(0.15)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)

                Image(systemName: "sparkles")
                    .font(.system(size: 36))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.indigo, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            VStack(spacing: 6) {
                Text("What's New")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(.primary)

                Text("in Version \(version)")
                    .font(.title3.weight(.medium))
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Feature Row

    private func featureRow(feature: WhatsNewFeature) -> some View {
        HStack(spacing: 16) {
            Image(systemName: feature.icon)
                .font(.title2)
                .foregroundStyle(feature.color)
                .frame(width: 48, height: 48)
                .background(feature.color.opacity(0.12), in: .rect(cornerRadius: 14))

            VStack(alignment: .leading, spacing: 4) {
                Text(feature.title)
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)

                Text(feature.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(.regularMaterial)
        }
    }

    // MARK: - Feature Definitions

    /// The features shown for the current app version.
    /// Update this list when releasing new versions.
    private static var currentFeatures: [WhatsNewFeature] {
        [
            WhatsNewFeature(
                icon: "graduationcap.fill",
                color: .indigo,
                title: "Enhanced Onboarding",
                description: "A brand-new multi-step onboarding flow to help you get started quickly with notifications and biometric security."
            ),
            WhatsNewFeature(
                icon: "bell.badge.fill",
                color: .purple,
                title: "Smarter Notifications",
                description: "Receive timely reminders for upcoming assignments, grade updates, and important school announcements."
            ),
            WhatsNewFeature(
                icon: "faceid",
                color: .cyan,
                title: "Biometric Security",
                description: "Protect your account with Face ID or Touch ID for quick, secure access to your learning data."
            ),
            WhatsNewFeature(
                icon: "chart.line.uptrend.xyaxis",
                color: .green,
                title: "Performance Insights",
                description: "Deeper analytics and progress tracking to help you understand your learning journey."
            ),
            WhatsNewFeature(
                icon: "paintbrush.fill",
                color: .orange,
                title: "Refreshed Design",
                description: "Updated visuals with glass effects and smooth animations for a more polished experience."
            ),
        ]
    }
}

// MARK: - WhatsNewFeature Model

struct WhatsNewFeature: Identifiable {
    let id = UUID()
    let icon: String
    let color: Color
    let title: String
    let description: String
}

// MARK: - View Extension for What's New

extension View {
    /// Presents the What's New sheet when the stored version differs from the current bundle version.
    /// Typically applied to the root content view.
    func whatsNewSheet() -> some View {
        self.sheet(isPresented: .init(
            get: { OnboardingManager.shouldShowWhatsNew },
            set: { if !$0 { OnboardingManager.markVersionSeen() } }
        )) {
            WhatsNewView()
        }
    }
}

#Preview {
    WhatsNewView()
}
