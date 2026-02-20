import Foundation
import SwiftUI
import UniformTypeIdentifiers

// MARK: - LMSFile Model

/// Represents a file stored locally in the LMS documents directory.
struct LMSFile: Identifiable, Hashable, Sendable {
    let id: UUID
    let name: String
    let courseId: String
    let courseName: String
    let fileSize: Int64
    let dateAdded: Date
    let fileURL: URL
    let fileType: FileType

    /// Human-readable file size (e.g. "2.4 MB").
    var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: fileSize)
    }

    nonisolated enum FileType: String, Sendable, CaseIterable {
        case pdf
        case doc
        case image
        case spreadsheet
        case presentation
        case other

        /// Determines file type from a file extension string.
        static func from(extension ext: String) -> FileType {
            switch ext.lowercased() {
            case "pdf":
                return .pdf
            case "doc", "docx", "txt", "rtf", "pages", "odt":
                return .doc
            case "jpg", "jpeg", "png", "heic", "heif", "gif", "webp", "tiff", "bmp", "svg":
                return .image
            case "xls", "xlsx", "csv", "numbers", "ods":
                return .spreadsheet
            case "ppt", "pptx", "key", "odp":
                return .presentation
            default:
                return .other
            }
        }
    }
}

// MARK: - FileManagerService

/// Service for managing locally stored LMS documents, organized by course.
/// Stores files in the app's Documents/LMS/{courseId}/ directory structure.
@Observable
@MainActor
final class FileManagerService {

    // MARK: - Properties

    /// Files grouped by course ID.
    var courseFiles: [String: [LMSFile]] = [:]

    /// Whether a file operation is in progress.
    var isLoading = false

    /// Total storage used by all LMS files, as a formatted string.
    var totalStorageUsed: String = "0 KB"

    /// Error message from the most recent operation, if any.
    var error: String?

    /// The root directory for all LMS file storage.
    private let lmsRootDirectory: URL

    /// File manager reference.
    private let fm = FileManager.default

    // MARK: - Init

    init() {
        let documentsURL = fm.urls(for: .documentDirectory, in: .userDomainMask).first!
        lmsRootDirectory = documentsURL.appendingPathComponent("LMS", isDirectory: true)

        // Ensure root directory exists
        try? fm.createDirectory(at: lmsRootDirectory, withIntermediateDirectories: true)

        // Scan existing files on launch
        scanExistingFiles()
    }

    // MARK: - Import

    /// Imports a file from the given URL into the LMS directory for the specified course.
    ///
    /// - Parameters:
    ///   - sourceURL: The source file URL (e.g. from document picker).
    ///   - courseId: The course identifier used for directory organization.
    ///   - courseName: The human-readable course name stored with the file metadata.
    /// - Returns: The newly created `LMSFile`, or `nil` if the import failed.
    @discardableResult
    func importFile(from sourceURL: URL, courseId: String, courseName: String) -> LMSFile? {
        isLoading = true
        defer { isLoading = false }

        let courseDirectory = lmsRootDirectory.appendingPathComponent(courseId, isDirectory: true)

        // Ensure the course directory exists
        do {
            try fm.createDirectory(at: courseDirectory, withIntermediateDirectories: true)
        } catch {
            self.error = "Could not create course directory: \(error.localizedDescription)"
            return nil
        }

        let fileName = sourceURL.lastPathComponent
        var destinationURL = courseDirectory.appendingPathComponent(fileName)

        // Handle duplicate file names by appending a counter
        if fm.fileExists(atPath: destinationURL.path) {
            let nameWithoutExtension = sourceURL.deletingPathExtension().lastPathComponent
            let ext = sourceURL.pathExtension
            var counter = 1
            repeat {
                let newName = "\(nameWithoutExtension) (\(counter)).\(ext)"
                destinationURL = courseDirectory.appendingPathComponent(newName)
                counter += 1
            } while fm.fileExists(atPath: destinationURL.path)
        }

        // Start secure access for files from outside the sandbox (e.g. Files app)
        let didStartAccess = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if didStartAccess {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        do {
            try fm.copyItem(at: sourceURL, to: destinationURL)
        } catch {
            self.error = "Failed to copy file: \(error.localizedDescription)"
            return nil
        }

        // Read file attributes
        let attributes = try? fm.attributesOfItem(atPath: destinationURL.path)
        let fileSize = attributes?[.size] as? Int64 ?? 0
        let dateAdded = Date()

        let lmsFile = LMSFile(
            id: UUID(),
            name: destinationURL.lastPathComponent,
            courseId: courseId,
            courseName: courseName,
            fileSize: fileSize,
            dateAdded: dateAdded,
            fileURL: destinationURL,
            fileType: LMSFile.FileType.from(extension: destinationURL.pathExtension)
        )

        // Add to the in-memory dictionary
        courseFiles[courseId, default: []].append(lmsFile)

        // Sort by date descending within the course
        courseFiles[courseId]?.sort { $0.dateAdded > $1.dateAdded }

        // Update storage calculation
        totalStorageUsed = calculateStorageUsed()

        return lmsFile
    }

    // MARK: - Delete

    /// Deletes the given file from disk and removes it from the in-memory index.
    func deleteFile(_ file: LMSFile) {
        do {
            if fm.fileExists(atPath: file.fileURL.path) {
                try fm.removeItem(at: file.fileURL)
            }
        } catch {
            self.error = "Failed to delete file: \(error.localizedDescription)"
            return
        }

        // Remove from in-memory dictionary
        courseFiles[file.courseId]?.removeAll { $0.id == file.id }

        // Remove the course key if no files remain
        if courseFiles[file.courseId]?.isEmpty == true {
            courseFiles.removeValue(forKey: file.courseId)
        }

        // Clean up empty course directory
        let courseDirectory = lmsRootDirectory.appendingPathComponent(file.courseId, isDirectory: true)
        let contents = (try? fm.contentsOfDirectory(atPath: courseDirectory.path)) ?? []
        if contents.isEmpty {
            try? fm.removeItem(at: courseDirectory)
        }

        totalStorageUsed = calculateStorageUsed()
    }

    // MARK: - Query

    /// Returns all files for a specific course, sorted by date added (newest first).
    func getFiles(for courseId: String) -> [LMSFile] {
        courseFiles[courseId] ?? []
    }

    /// Returns all files across all courses, sorted by date added (newest first).
    func getAllFiles() -> [LMSFile] {
        courseFiles.values
            .flatMap { $0 }
            .sorted { $0.dateAdded > $1.dateAdded }
    }

    // MARK: - Export / Share

    /// Presents UIActivityViewController to share/export a file to the Files app or other destinations.
    func exportToFilesApp(_ file: LMSFile) {
        guard fm.fileExists(atPath: file.fileURL.path) else {
            error = "File not found on disk."
            return
        }

        let activityVC = UIActivityViewController(
            activityItems: [file.fileURL],
            applicationActivities: nil
        )

        // Find the topmost presented view controller to present from
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController else {
            error = "Could not present share sheet."
            return
        }

        var presenter = rootVC
        while let presented = presenter.presentedViewController {
            presenter = presented
        }

        // iPad popover anchor
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = presenter.view
            popover.sourceRect = CGRect(
                x: presenter.view.bounds.midX,
                y: presenter.view.bounds.midY,
                width: 0, height: 0
            )
            popover.permittedArrowDirections = []
        }

        presenter.present(activityVC, animated: true)
    }

    // MARK: - Storage Calculation

    /// Calculates the total storage used by all LMS files and returns a formatted string.
    func calculateStorageUsed() -> String {
        let totalBytes = getAllFiles().reduce(Int64(0)) { $0 + $1.fileSize }
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: totalBytes)
    }

    // MARK: - File Icon & Color

    /// Returns the SF Symbol name appropriate for the given file type.
    func fileIcon(for fileType: LMSFile.FileType) -> String {
        switch fileType {
        case .pdf:
            return "doc.fill"
        case .doc:
            return "doc.text.fill"
        case .image:
            return "photo.fill"
        case .spreadsheet:
            return "tablecells.fill"
        case .presentation:
            return "rectangle.on.rectangle.angled.fill"
        case .other:
            return "doc.fill"
        }
    }

    /// Returns the tint color appropriate for the given file type.
    func fileColor(for fileType: LMSFile.FileType) -> Color {
        switch fileType {
        case .pdf:
            return .red
        case .doc:
            return .blue
        case .image:
            return .purple
        case .spreadsheet:
            return .green
        case .presentation:
            return .orange
        case .other:
            return .gray
        }
    }

    // MARK: - Scan Existing Files

    /// Scans the LMS root directory and rebuilds the in-memory file index.
    private func scanExistingFiles() {
        courseFiles.removeAll()

        guard let courseDirectories = try? fm.contentsOfDirectory(
            at: lmsRootDirectory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            totalStorageUsed = calculateStorageUsed()
            return
        }

        for courseDir in courseDirectories {
            var isDirectory: ObjCBool = false
            guard fm.fileExists(atPath: courseDir.path, isDirectory: &isDirectory),
                  isDirectory.boolValue else { continue }

            let courseId = courseDir.lastPathComponent

            guard let files = try? fm.contentsOfDirectory(
                at: courseDir,
                includingPropertiesForKeys: [.fileSizeKey, .creationDateKey],
                options: [.skipsHiddenFiles]
            ) else { continue }

            for fileURL in files {
                let attributes = try? fm.attributesOfItem(atPath: fileURL.path)
                let fileSize = attributes?[.size] as? Int64 ?? 0
                let dateAdded = attributes?[.creationDate] as? Date ?? Date()

                let lmsFile = LMSFile(
                    id: UUID(),
                    name: fileURL.lastPathComponent,
                    courseId: courseId,
                    courseName: courseId, // Best effort; real name can be updated later
                    fileSize: fileSize,
                    dateAdded: dateAdded,
                    fileURL: fileURL,
                    fileType: LMSFile.FileType.from(extension: fileURL.pathExtension)
                )

                courseFiles[courseId, default: []].append(lmsFile)
            }

            // Sort each course's files by date descending
            courseFiles[courseId]?.sort { $0.dateAdded > $1.dateAdded }
        }

        totalStorageUsed = calculateStorageUsed()
    }

    /// Rescans the file system and refreshes the in-memory index.
    func refresh() {
        isLoading = true
        scanExistingFiles()
        isLoading = false
    }
}
