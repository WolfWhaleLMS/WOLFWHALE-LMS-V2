import SwiftUI

// MARK: - DebouncedSearchField

struct DebouncedSearchField: View {
    let placeholder: String
    @Binding var text: String
    var delay: Duration = .milliseconds(300)
    var onSearch: ((String) -> Void)?

    @State private var debouncer: Debouncer

    // MARK: - Init

    init(
        placeholder: String = "Search...",
        text: Binding<String>,
        delay: Duration = .milliseconds(300),
        onSearch: ((String) -> Void)? = nil
    ) {
        self.placeholder = placeholder
        self._text = text
        self.delay = delay
        self.onSearch = onSearch
        self._debouncer = State(initialValue: Debouncer(delay: delay))
    }

    // MARK: - Body

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .font(.subheadline.weight(.medium))

            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(.subheadline)
                .onChange(of: text) { _, newValue in
                    let callback = onSearch
                    debouncer.debounce { @MainActor in
                        callback?(newValue)
                    }
                }
                .accessibilityLabel(placeholder)

            if !text.isEmpty {
                Button {
                    text = ""
                    debouncer.cancel()
                    onSearch?("")
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Previews

#Preview {
    @Previewable @State var searchText = ""

    ZStack {
        #if canImport(UIKit)
        Color(UIColor.systemGroupedBackground).ignoresSafeArea()
        #endif
        VStack(spacing: 16) {
            DebouncedSearchField(
                placeholder: "Search courses...",
                text: $searchText,
                onSearch: { query in
                    #if DEBUG
                    print("Searching: \(query)")
                    #endif
                }
            )

            Text("Query: \(searchText)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}
