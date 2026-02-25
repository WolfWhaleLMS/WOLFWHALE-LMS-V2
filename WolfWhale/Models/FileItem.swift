import Foundation

nonisolated struct FileItem: Identifiable, Hashable, Sendable {
    let id: UUID
    let fileName: String
    let fileExtension: String
    let fileSize: Int64
    let uploadDate: Date
    let courseId: UUID?
    let courseName: String?
    let assignmentId: UUID?
    let assignmentName: String?
    let storageURL: String
    let uploaderId: UUID

    // MARK: - Computed Properties

    var iconName: String {
        switch fileType {
        case .pdf:
            return "doc.richtext.fill"
        case .image:
            return "photo.fill"
        case .document:
            return "doc.fill"
        case .spreadsheet:
            return "tablecells.fill"
        case .presentation:
            return "rectangle.on.rectangle.angled.fill"
        case .text:
            return "doc.text.fill"
        case .other:
            return "doc.badge.ellipsis"
        }
    }

    var formattedSize: String {
        let bytes = Double(fileSize)
        if bytes < 1024 {
            return "\(fileSize) B"
        } else if bytes < 1024 * 1024 {
            return String(format: "%.1f KB", bytes / 1024)
        } else if bytes < 1024 * 1024 * 1024 {
            return String(format: "%.1f MB", bytes / (1024 * 1024))
        } else {
            return String(format: "%.1f GB", bytes / (1024 * 1024 * 1024))
        }
    }

    var fileType: FileType {
        switch fileExtension.lowercased() {
        case "pdf":
            return .pdf
        case "jpg", "jpeg", "png", "heic", "heif", "gif", "webp", "bmp", "tiff":
            return .image
        case "doc", "docx", "rtf", "odt":
            return .document
        case "xls", "xlsx", "csv", "numbers":
            return .spreadsheet
        case "ppt", "pptx", "key":
            return .presentation
        case "txt", "md", "swift", "py", "js", "html", "css", "json", "xml":
            return .text
        default:
            return .other
        }
    }

    nonisolated enum FileType: String, Sendable {
        case pdf
        case image
        case document
        case spreadsheet
        case presentation
        case text
        case other
    }
}
