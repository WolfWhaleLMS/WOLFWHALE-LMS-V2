import SwiftUI

// MARK: - iMessage Extension Setup Guide
//
// This view documents how to create the iMessage extension targets in Xcode.
// The WolfWhale LMS supports two types of iMessage extensions:
//
// ============================================================================
// TARGET 1: Sticker Pack Extension (Static Stickers)
// ============================================================================
//
// 1. In Xcode: File > New > Target > Sticker Pack Extension
// 2. Product Name: "WolfWhale Stickers"
// 3. Bundle Identifier: com.wolfwhale.lms.WolfWhaleLearning.WolfWhaleStickers
//    (Must be a child of the main app's bundle identifier)
// 4. Embed in Application: WolfWhaleLearning
// 5. After creation, populate the Stickers.xcstickers catalog in the new target
//    with 120x120 @3x PNG images for each sticker defined in StickerPackView.swift.
//
// Sticker image requirements (per Apple guidelines):
//   - Small:  300 x 300 px  (100 x 100 pt @3x)
//   - Medium: 408 x 408 px  (136 x 136 pt @3x)
//   - Large:  618 x 618 px  (206 x 206 pt @3x)
//   - File size: Under 500 KB each
//   - Formats: PNG, APNG, GIF, JPEG (PNG recommended for transparency)
//
// ============================================================================
// TARGET 2: iMessage Extension (Interactive - Chess Mini Game)
// ============================================================================
//
// 1. In Xcode: File > New > Target > iMessage Extension
// 2. Product Name: "WolfWhale Messages"
// 3. Bundle Identifier: com.wolfwhale.lms.WolfWhaleLearning.WolfWhaleMessages
//    (Must be a child of the main app's bundle identifier)
// 4. Embed in Application: WolfWhaleLearning
// 5. This creates a MessagesExtension folder with:
//    - MessagesViewController.swift (subclass of MSMessagesAppViewController)
//    - MainInterface.storyboard (can be replaced with SwiftUI hosting)
//    - Info.plist
//
// Required frameworks:
//   - Messages.framework (automatically linked for iMessage extension targets)
//   - No need to import Messages in main app target views
//
// MSMessagesAppViewController lifecycle:
//   - willBecomeActive(with:)    -> Extension is about to become active
//   - didBecomeActive(with:)     -> Extension is active, set up UI
//   - willResignActive(with:)    -> Extension is about to resign
//   - didResignActive(with:)     -> Extension resigned, clean up
//   - willSelect(_:conversation:) -> User tapped a message in the transcript
//   - didSelect(_:conversation:)  -> Message was selected
//   - willTransition(to:)        -> Presentation style is changing
//   - didTransition(to:)         -> Presentation style changed
//
// Presentation styles:
//   - .compact  -> Keyboard-height strip at bottom
//   - .expanded -> Full screen (user tapped the expand chevron)
//   - .transcript -> Inline in the message bubble
//
// Entitlements:
//   - No special entitlements required for basic iMessage extensions
//   - The extension inherits the app group if configured:
//     group.com.wolfwhale.lms.shared (for sharing data between main app and extension)
//   - If using shared UserDefaults or CoreData, add the App Group entitlement
//     to both the main app target AND the extension target
//
// Sharing code between targets:
//   - Add shared Swift files to both targets (main app + extension)
//   - Or create a shared framework target for common models/utilities
//   - iMessageChessView.swift is designed to compile in both targets
//   - The chess view uses no Messages.framework imports so it works standalone
//
// ============================================================================

struct MessagesExtensionSetupGuide: View {
    @State private var expandedSection: SetupSection?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    headerSection
                    overviewCard
                    stickerExtensionSection
                    messagesExtensionSection
                    sharedCodeSection
                    entitlementsSection
                    nextStepsSection
                }
                .padding(.horizontal)
                .padding(.bottom, 32)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("iMessage Setup")
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24)
                .fill(
                    LinearGradient(
                        colors: [.indigo, .purple, .blue],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(height: 160)

            VStack(spacing: 8) {
                Image(systemName: "message.badge.waveform.fill")
                    .font(.system(size: 36, weight: .medium))
                    .foregroundStyle(.white)
                    .symbolEffect(.pulse, options: .repeating)

                Text("iMessage Extension Setup")
                    .font(.title2.bold())
                    .foregroundStyle(.white)

                Text("Developer guide for Xcode target configuration")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.85))
            }
        }
        .padding(.top, 8)
    }

    // MARK: - Overview Card

    private var overviewCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "info.circle.fill")
                    .foregroundStyle(.blue)
                Text("Overview")
                    .font(.headline)
            }

            Text("WolfWhale LMS includes two iMessage extension capabilities:")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 16) {
                extensionTypeBadge(
                    icon: "face.smiling.fill",
                    title: "Sticker Pack",
                    subtitle: "12 school stickers",
                    color: .purple
                )

                extensionTypeBadge(
                    icon: "gamecontroller.fill",
                    title: "Mini Games",
                    subtitle: "Chess & more",
                    color: .blue
                )
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

    private func extensionTypeBadge(icon: String, title: String, subtitle: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
                .frame(width: 48, height: 48)
                .background(color.opacity(0.12), in: .rect(cornerRadius: 12))

            Text(title)
                .font(.subheadline.bold())

            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(.quaternary.opacity(0.3), in: .rect(cornerRadius: 14))
    }

    // MARK: - Sticker Extension Section

    private var stickerExtensionSection: some View {
        setupSection(
            section: .stickerPack,
            icon: "face.smiling.fill",
            title: "Sticker Pack Extension",
            color: .purple,
            steps: [
                SetupStep(
                    number: 1,
                    title: "Create Target",
                    detail: "File > New > Target > Sticker Pack Extension"
                ),
                SetupStep(
                    number: 2,
                    title: "Product Name",
                    detail: "\"WolfWhale Stickers\""
                ),
                SetupStep(
                    number: 3,
                    title: "Bundle ID",
                    detail: "com.wolfwhale.lms.WolfWhaleLearning.WolfWhaleStickers"
                ),
                SetupStep(
                    number: 4,
                    title: "Add Sticker Images",
                    detail: "Export 120x120 @3x PNGs to the Stickers.xcstickers catalog"
                ),
                SetupStep(
                    number: 5,
                    title: "Build & Test",
                    detail: "Select the sticker extension scheme and run on a device with Messages"
                )
            ]
        )
    }

    // MARK: - Messages Extension Section

    private var messagesExtensionSection: some View {
        setupSection(
            section: .messagesExtension,
            icon: "gamecontroller.fill",
            title: "iMessage Extension (Interactive)",
            color: .blue,
            steps: [
                SetupStep(
                    number: 1,
                    title: "Create Target",
                    detail: "File > New > Target > iMessage Extension"
                ),
                SetupStep(
                    number: 2,
                    title: "Product Name",
                    detail: "\"WolfWhale Messages\""
                ),
                SetupStep(
                    number: 3,
                    title: "Bundle ID",
                    detail: "com.wolfwhale.lms.WolfWhaleLearning.WolfWhaleMessages"
                ),
                SetupStep(
                    number: 4,
                    title: "Host Chess View",
                    detail: "Use UIHostingController to embed iMessageChessView in the MSMessagesAppViewController"
                ),
                SetupStep(
                    number: 5,
                    title: "Encode Board State",
                    detail: "Use boardStateToURL() to embed game state in MSMessage URL components"
                ),
                SetupStep(
                    number: 6,
                    title: "Handle Incoming",
                    detail: "In didSelect(_:conversation:), decode the URL to restore board state with urlToBoardState()"
                )
            ]
        )
    }

    // MARK: - Shared Code Section

    private var sharedCodeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "square.on.square.fill")
                    .foregroundStyle(.green)
                Text("Sharing Code Between Targets")
                    .font(.headline)
            }

            VStack(alignment: .leading, spacing: 8) {
                codeNote(
                    icon: "checkmark.circle.fill",
                    text: "iMessageChessView.swift compiles in both the main app and extension targets",
                    color: .green
                )
                codeNote(
                    icon: "checkmark.circle.fill",
                    text: "No Messages.framework imports in shared views",
                    color: .green
                )
                codeNote(
                    icon: "lightbulb.fill",
                    text: "Consider creating a shared framework for models used by both targets",
                    color: .yellow
                )
                codeNote(
                    icon: "exclamationmark.triangle.fill",
                    text: "Add shared files to both target memberships in Xcode",
                    color: .orange
                )
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

    private func codeNote(icon: String, text: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .font(.subheadline)
                .frame(width: 20)

            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Entitlements Section

    private var entitlementsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "lock.shield.fill")
                    .foregroundStyle(.indigo)
                Text("Entitlements & App Groups")
                    .font(.headline)
            }

            Text("To share data (e.g., user profile, game history) between the main app and iMessage extension:")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 6) {
                entitlementRow("Add App Group to main app target")
                entitlementRow("Add same App Group to extension target")
                entitlementRow("Group ID: group.com.wolfwhale.lms.shared")
                entitlementRow("Use UserDefaults(suiteName:) for shared preferences")
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

    private func entitlementRow(_ text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "chevron.right")
                .font(.caption2.bold())
                .foregroundStyle(.indigo)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Next Steps Section

    private var nextStepsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "arrow.right.circle.fill")
                    .foregroundStyle(.purple)
                Text("Next Steps")
                    .font(.headline)
            }

            VStack(spacing: 10) {
                nextStepRow(number: 1, text: "Create extension targets in Xcode using the steps above")
                nextStepRow(number: 2, text: "Export sticker images from StickerPackView designs")
                nextStepRow(number: 3, text: "Add iMessageChessView.swift to the Messages extension target")
                nextStepRow(number: 4, text: "Implement MSMessagesAppViewController to host the chess view")
                nextStepRow(number: 5, text: "Test in the iOS Simulator Messages app")
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

    private func nextStepRow(number: Int, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.caption.bold())
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(.purple, in: Circle())

            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()
        }
    }

    // MARK: - Reusable Setup Section

    private func setupSection(
        section: SetupSection,
        icon: String,
        title: String,
        color: Color,
        steps: [SetupStep]
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation(.spring(response: 0.3)) {
                    expandedSection = expandedSection == section ? nil : section
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: icon)
                        .foregroundStyle(color)
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.subheadline.bold())
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(expandedSection == section ? 90 : 0))
                }
            }
            .buttonStyle(.plain)

            if expandedSection == section {
                VStack(spacing: 0) {
                    ForEach(steps, id: \.number) { step in
                        HStack(alignment: .top, spacing: 12) {
                            // Step number with connecting line
                            VStack(spacing: 0) {
                                Text("\(step.number)")
                                    .font(.caption2.bold())
                                    .foregroundStyle(.white)
                                    .frame(width: 24, height: 24)
                                    .background(color, in: Circle())

                                if step.number < steps.count {
                                    Rectangle()
                                        .fill(color.opacity(0.3))
                                        .frame(width: 2)
                                        .frame(maxHeight: .infinity)
                                }
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text(step.title)
                                    .font(.subheadline.bold())

                                Text(step.detail)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.bottom, 16)

                            Spacer()
                        }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }
}

// MARK: - Supporting Types

private enum SetupSection: Hashable {
    case stickerPack
    case messagesExtension
}

private struct SetupStep {
    let number: Int
    let title: String
    let detail: String
}

// MARK: - Preview

#Preview {
    MessagesExtensionSetupGuide()
}
