import SwiftUI

/// A reusable `TextEditor` wrapper with a word-count footer, optional character limit,
/// placeholder text, and a toggleable Writing Assistant panel.
struct EnhancedTextEditor: View {
    @Binding var text: String

    /// Optional placeholder shown when the editor is empty.
    var placeholder: String = "Start writing..."
    /// Optional maximum character count. Pass `nil` for no limit.
    var characterLimit: Int? = nil
    /// Minimum height for the editor area.
    var minHeight: CGFloat = 150

    @State private var showAssistant = false
    @State private var writingService = WritingToolsService()

    var body: some View {
        VStack(spacing: 0) {
            editorArea
            footerBar
            if showAssistant {
                WritingAssistantView(text: $text, writingService: writingService)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .onChange(of: text) {
            writingService.analyzeText(text)
            enforceCharacterLimit()
        }
        .onAppear {
            writingService.analyzeText(text)
        }
    }

    // MARK: - Editor Area

    private var editorArea: some View {
        TextEditor(text: $text)
            .frame(minHeight: minHeight)
            .padding(10)
            .scrollContentBackground(.hidden)
            .background(Color(.tertiarySystemFill), in: .rect(cornerRadii: .init(topLeading: 10, topTrailing: 10)))
            .overlay(alignment: .topLeading) {
                if text.isEmpty {
                    Text(placeholder)
                        .font(.body)
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 18)
                        .allowsHitTesting(false)
                }
            }
    }

    // MARK: - Footer Bar

    private var footerBar: some View {
        HStack(spacing: 12) {
            // Word count
            Text("\(writingService.wordCount) word\(writingService.wordCount == 1 ? "" : "s")")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)

            // Character limit indicator
            if let limit = characterLimit {
                let count = text.count
                let pct = Double(count) / Double(limit)
                Text("\(count)/\(limit)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(pct >= 1.0 ? .red : pct >= 0.9 ? .orange : .secondary)
            }

            Spacer()

            // Writing Assistant toggle
            Button {
                withAnimation(.snappy(duration: 0.25)) {
                    showAssistant.toggle()
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "pencil.and.list.clipboard")
                    Text(showAssistant ? "Hide Assistant" : "Writing Assistant")
                }
                .font(.caption.bold())
                .foregroundStyle(.blue)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.tertiarySystemFill))
    }

    // MARK: - Helpers

    private func enforceCharacterLimit() {
        guard let limit = characterLimit, text.count > limit else { return }
        text = String(text.prefix(limit))
    }
}
