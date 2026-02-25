import SwiftUI
import UniformTypeIdentifiers

/// Result returned when a user picks a file from the document picker.
struct PickedFile: Identifiable, Hashable, Sendable {
    let id: UUID
    let url: URL
    let name: String
    let size: Int64

    init(url: URL, name: String, size: Int64) {
        self.id = UUID()
        self.url = url
        self.name = name
        self.size = size
    }

    /// Human-readable file size string (e.g. "2.4 MB").
    var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }

    /// Returns an SF Symbol name based on the file extension.
    var iconName: String {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "pdf":
            return "doc.fill"
        case "jpg", "jpeg", "png", "heic", "heif", "gif", "webp":
            return "photo.fill"
        case "doc", "docx":
            return "doc.text.fill"
        case "txt", "rtf":
            return "text.page.fill"
        default:
            return "paperclip"
        }
    }

    /// Returns a tint color based on the file extension.
    var iconColor: Color {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "pdf":
            return .red
        case "jpg", "jpeg", "png", "heic", "heif", "gif", "webp":
            return .blue
        case "doc", "docx":
            return .indigo
        case "txt", "rtf":
            return .gray
        default:
            return .orange
        }
    }
}

/// Supported content types for the document picker.
private let supportedTypes: [UTType] = [
    .pdf,
    .jpeg,
    .png,
    .plainText,
    .rtf,
    .image,
    UTType("com.microsoft.word.doc") ?? .data,
    UTType("org.openxmlformats.wordprocessingml.document") ?? .data
]

/// A SwiftUI wrapper around `UIDocumentPickerViewController` for selecting files.
struct FilePickerView: UIViewControllerRepresentable {
    let allowedTypes: [UTType]
    let onPick: @Sendable (PickedFile) -> Void
    let onCancel: @Sendable () -> Void

    init(
        allowedTypes: [UTType] = supportedTypes,
        onPick: @escaping @Sendable (PickedFile) -> Void,
        onCancel: @escaping @Sendable () -> Void = {}
    ) {
        self.allowedTypes = allowedTypes
        self.onPick = onPick
        self.onCancel = onCancel
    }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: allowedTypes, asCopy: true)
        picker.allowsMultipleSelection = false
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick, onCancel: onCancel)
    }

    final class Coordinator: NSObject, UIDocumentPickerDelegate, @unchecked Sendable {
        let onPick: @Sendable (PickedFile) -> Void
        let onCancel: @Sendable () -> Void

        init(
            onPick: @escaping @Sendable (PickedFile) -> Void,
            onCancel: @escaping @Sendable () -> Void
        ) {
            self.onPick = onPick
            self.onCancel = onCancel
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }

            let name = url.lastPathComponent
            var fileSize: Int64 = 0

            if let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
               let size = attributes[.size] as? Int64 {
                fileSize = size
            }

            let pickedFile = PickedFile(url: url, name: name, size: fileSize)
            onPick(pickedFile)
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            onCancel()
        }
    }
}
