import Foundation
import Supabase

/// Errors that can occur during file upload operations.
nonisolated enum FileUploadError: LocalizedError, Sendable {
    case fileTooLarge(maxMB: Int)
    case fileNotFound
    case uploadFailed(String)
    case deleteFailed(String)
    case invalidFileData

    var errorDescription: String? {
        switch self {
        case .fileTooLarge(let maxMB):
            "File exceeds the maximum size of \(maxMB) MB."
        case .fileNotFound:
            "The selected file could not be found."
        case .uploadFailed(let reason):
            "Upload failed: \(reason)"
        case .deleteFailed(let reason):
            "Delete failed: \(reason)"
        case .invalidFileData:
            "The file data could not be read."
        }
    }
}

/// Service for uploading, deleting, and retrieving files from Supabase Storage.
/// Uses the global `supabaseClient` defined in SupabaseService.swift.
nonisolated struct FileUploadService: Sendable {

    /// Maximum allowed file size in bytes (10 MB).
    static let maxFileSize: Int64 = 10 * 1024 * 1024

    /// Maximum allowed file size in megabytes (for error messages).
    static let maxFileSizeMB: Int = 10

    /// Predefined bucket names used in the LMS.
    nonisolated enum Bucket: Sendable {
        static let assignmentSubmissions = "assignment-submissions"
        static let lessonMaterials = "lesson-materials"
    }

    // MARK: - Upload

    /// Uploads a file to the specified Supabase Storage bucket.
    ///
    /// - Parameters:
    ///   - bucket: The storage bucket name (e.g. `Bucket.assignmentSubmissions`).
    ///   - path: The path within the bucket where the file will be stored
    ///           (e.g. "userId/assignmentId/filename.pdf").
    ///   - fileURL: The local file URL to upload.
    /// - Returns: The public URL string of the uploaded file.
    /// - Throws: `FileUploadError` if validation or upload fails.
    func uploadFile(bucket: String, path: String, fileURL: URL) async throws -> String {
        // Verify the file exists
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw FileUploadError.fileNotFound
        }

        // Check file size
        let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
        let fileSize = attributes[.size] as? Int64 ?? 0
        guard fileSize <= FileUploadService.maxFileSize else {
            throw FileUploadError.fileTooLarge(maxMB: FileUploadService.maxFileSizeMB)
        }

        // Read file data
        guard let fileData = try? Data(contentsOf: fileURL) else {
            throw FileUploadError.invalidFileData
        }

        // Determine MIME type from file extension
        let contentType = mimeType(for: fileURL.pathExtension)

        // Upload to Supabase Storage
        do {
            try await supabaseClient.storage
                .from(bucket)
                .upload(
                    path: path,
                    file: fileData,
                    options: FileOptions(
                        cacheControl: "3600",
                        contentType: contentType,
                        upsert: true
                    )
                )
        } catch {
            throw FileUploadError.uploadFailed(error.localizedDescription)
        }

        // Return the public URL
        if let publicURL = getPublicURL(bucket: bucket, path: path) {
            return publicURL.absoluteString
        }

        // Fallback: construct URL manually
        return "\(Config.SUPABASE_URL)/storage/v1/object/public/\(bucket)/\(path)"
    }

    // MARK: - Delete

    /// Deletes a file from the specified Supabase Storage bucket.
    ///
    /// - Parameters:
    ///   - bucket: The storage bucket name.
    ///   - path: The path within the bucket of the file to delete.
    /// - Throws: `FileUploadError` if deletion fails.
    func deleteFile(bucket: String, path: String) async throws {
        do {
            try await supabaseClient.storage
                .from(bucket)
                .remove(paths: [path])
        } catch {
            throw FileUploadError.deleteFailed(error.localizedDescription)
        }
    }

    // MARK: - Public URL

    /// Retrieves the public URL for a file in a Supabase Storage bucket.
    ///
    /// - Parameters:
    ///   - bucket: The storage bucket name.
    ///   - path: The path within the bucket.
    /// - Returns: The public `URL`, or `nil` if it could not be constructed.
    func getPublicURL(bucket: String, path: String) -> URL? {
        try? supabaseClient.storage
            .from(bucket)
            .getPublicURL(path: path)
    }

    // MARK: - Helpers

    /// Maps a file extension to a MIME type string.
    private func mimeType(for pathExtension: String) -> String {
        switch pathExtension.lowercased() {
        case "pdf":
            return "application/pdf"
        case "jpg", "jpeg":
            return "image/jpeg"
        case "png":
            return "image/png"
        case "heic", "heif":
            return "image/heic"
        case "gif":
            return "image/gif"
        case "webp":
            return "image/webp"
        case "doc":
            return "application/msword"
        case "docx":
            return "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
        case "txt":
            return "text/plain"
        case "rtf":
            return "application/rtf"
        default:
            return "application/octet-stream"
        }
    }
}
