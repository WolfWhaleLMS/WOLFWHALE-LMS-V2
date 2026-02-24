import SwiftUI

/// A settings screen that lets the user pick between English and French.
///
/// The view updates all preview strings in real time so the user can
/// see the effect before navigating away. Because `L10n` reads from
/// `UserDefaults` on every access, changing the stored value and
/// bumping a local `@State` counter is enough to force a re-render
/// without a full restart.
struct LanguagePickerView: View {

    // MARK: - State

    /// Tracks the code the user has selected (may differ from persisted
    /// value until they confirm).
    @State private var selectedCode: String = L10n.currentLanguage

    /// Toggled to force SwiftUI to re-evaluate computed strings after
    /// the language is persisted.
    @State private var refreshToken = false

    /// Brief confirmation banner after saving.
    @State private var showSavedBanner = false

    @State private var hapticTrigger = false

    @Environment(\.dismiss) private var dismiss

    // MARK: - Body

    var body: some View {
        List {
            languageSection
            previewSection
            noteSection
        }
        .listStyle(.insetGrouped)
        .navigationTitle(L10n.language)
        .navigationBarTitleDisplayMode(.large)
        .overlay(alignment: .top) {
            if showSavedBanner {
                savedBanner
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.smooth, value: showSavedBanner)
    }

    // MARK: - Language Selection

    private var languageSection: some View {
        Section {
            ForEach(L10n.supportedLanguages, id: \.code) { lang in
                Button {
                    guard selectedCode != lang.code else { return }
                    hapticTrigger.toggle()
                    selectedCode = lang.code
                    L10n.setLanguage(lang.code)
                    refreshToken.toggle()
                    showSavedConfirmation()
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(lang.name)
                                .font(.body)
                                .foregroundStyle(.primary)
                            Text(lang.code.uppercased())
                                .font(.caption2.monospaced())
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        if selectedCode == lang.code {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.title3)
                                .foregroundStyle(.indigo)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .contentShape(Rectangle())
                    .padding(.vertical, 2)
                }
                .hapticFeedback(.selection, trigger: hapticTrigger)
                .accessibilityLabel(lang.name)
                .accessibilityAddTraits(selectedCode == lang.code ? .isSelected : [])
            }
        } header: {
            sectionHeader(title: localizedHeader("Choose Language", "Choisir la langue"), icon: "globe")
        }
        .animation(.smooth, value: selectedCode)
    }

    // MARK: - Live Preview

    private var previewSection: some View {
        Section {
            previewRow(label: localizedHeader("Dashboard", "Tableau de bord"), icon: "square.grid.2x2.fill", color: .indigo)
            previewRow(label: localizedHeader("Courses", "Cours"), icon: "book.fill", color: .purple)
            previewRow(label: localizedHeader("Assignments", "Travaux"), icon: "doc.text.fill", color: .blue)
            previewRow(label: localizedHeader("Grades", "Notes"), icon: "chart.bar.fill", color: .green)
            previewRow(label: localizedHeader("Messages", "Messages"), icon: "bubble.left.and.bubble.right.fill", color: .orange)
            previewRow(label: localizedHeader("Settings", "R\u{00E9}glages"), icon: "gearshape.fill", color: .gray)
        } header: {
            sectionHeader(title: localizedHeader("Preview", "Aper\u{00E7}u"), icon: "eye")
        } footer: {
            Text(localizedHeader(
                "This is how key strings will appear throughout the app.",
                "Voici comment les textes principaux appara\u{00EE}tront dans l\u{2019}application."
            ))
        }
    }

    // MARK: - Info Note

    private var noteSection: some View {
        Section {
            Label {
                Text(localizedHeader(
                    "Changing the language updates all text in the app immediately. No restart is required.",
                    "Le changement de langue met \u{00E0} jour tous les textes de l\u{2019}application imm\u{00E9}diatement. Aucun red\u{00E9}marrage n\u{2019}est n\u{00E9}cessaire."
                ))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            } icon: {
                Image(systemName: "info.circle.fill")
                    .foregroundStyle(.indigo)
            }
        }
    }

    // MARK: - Saved Banner

    private var savedBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.white)
            Text(localizedHeader("Language updated", "Langue mise \u{00E0} jour"))
                .font(.subheadline.bold())
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.indigo, in: .capsule)
        .shadow(color: .indigo.opacity(0.4), radius: 8, y: 4)
        .padding(.top, 8)
    }

    // MARK: - Helpers

    private func previewRow(label: String, icon: String, color: Color) -> some View {
        Label {
            Text(label)
                .contentTransition(.numericText())
        } icon: {
            Image(systemName: icon)
                .foregroundStyle(color)
        }
    }

    /// Returns the English or French literal based on the *selected* code.
    /// This avoids a circular dependency during the preview section where
    /// `L10n` may not yet reflect the tap.
    private func localizedHeader(_ en: String, _ fr: String) -> String {
        // Use refreshToken indirectly so the compiler considers it a dependency.
        _ = refreshToken
        return selectedCode == "fr" ? fr : en
    }

    private func sectionHeader(title: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption2)
            Text(title.uppercased())
                .font(.caption2.bold())
        }
        .foregroundStyle(.secondary)
    }

    private func showSavedConfirmation() {
        showSavedBanner = true
        Task {
            try? await Task.sleep(for: .seconds(2))
            showSavedBanner = false
        }
    }
}

#Preview {
    NavigationStack {
        LanguagePickerView()
    }
}
