import PhotosUI
import SwiftUI
import Photos
import Supabase

/// Errors that can occur during photo operations.
nonisolated enum PhotoServiceError: LocalizedError, Sendable {
    case loadFailed
    case compressionFailed
    case saveFailed(String)
    case accessDenied
    case uploadFailed(String)

    var errorDescription: String? {
        switch self {
        case .loadFailed:
            "Could not load the selected photo."
        case .compressionFailed:
            "Failed to compress the image."
        case .saveFailed(let reason):
            "Failed to save image: \(reason)"
        case .accessDenied:
            "Photo library access was denied. Please enable it in Settings."
        case .uploadFailed(let reason):
            "Photo upload failed: \(reason)"
        }
    }
}

/// Service for loading, compressing, saving, and uploading photos.
/// Uses PhotosUI for picker integration and Supabase Storage for remote uploads.
@Observable
@MainActor
final class PhotoService {

    // MARK: - Storage Bucket

    /// Supabase Storage bucket for avatar images.
    static let avatarBucket = "avatars"

    /// Supabase Storage bucket for assignment attachment images.
    static let attachmentBucket = "assignment-submissions"

    // MARK: - Load Image from PhotosPicker

    /// Loads a `UIImage` from a `PhotosPickerItem` selected by the user.
    ///
    /// - Parameter item: The `PhotosPickerItem` returned by SwiftUI's `PhotosPicker`.
    /// - Returns: A `UIImage` if loading succeeded, otherwise `nil`.
    func loadImage(from item: PhotosPickerItem) async -> UIImage? {
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                return nil
            }
            return UIImage(data: data)
        } catch {
            #if DEBUG
            print("[PhotoService] Failed to load image: \(error)")
            #endif
            return nil
        }
    }

    // MARK: - Compress Image

    /// Compresses a `UIImage` to JPEG data within the specified maximum size.
    ///
    /// Iteratively lowers JPEG quality until the output is under `maxSizeKB`.
    ///
    /// - Parameters:
    ///   - image: The source `UIImage` to compress.
    ///   - maxSizeKB: Maximum file size in kilobytes. Defaults to 500 KB.
    /// - Returns: Compressed JPEG `Data`, or `nil` if compression failed.
    func compressImage(_ image: UIImage, maxSizeKB: Int = 500) -> Data? {
        let maxBytes = maxSizeKB * 1024
        var quality: CGFloat = 0.9
        var data = image.jpegData(compressionQuality: quality)

        // Iteratively lower quality to meet size target
        while let currentData = data, currentData.count > maxBytes, quality > 0.1 {
            quality -= 0.1
            data = image.jpegData(compressionQuality: quality)
        }

        // If still too large, resize the image down
        if let currentData = data, currentData.count > maxBytes {
            let scale = sqrt(Double(maxBytes) / Double(currentData.count))
            let newSize = CGSize(
                width: image.size.width * scale,
                height: image.size.height * scale
            )
            let renderer = UIGraphicsImageRenderer(size: newSize)
            let resized = renderer.image { _ in
                image.draw(in: CGRect(origin: .zero, size: newSize))
            }
            data = resized.jpegData(compressionQuality: 0.8)
        }

        return data
    }

    // MARK: - Save to Photo Library

    /// Saves a `UIImage` to the user's Photo Library.
    ///
    /// Requests write access if needed before saving.
    ///
    /// - Parameter image: The `UIImage` to save.
    /// - Throws: `PhotoServiceError.saveFailed` if the save operation fails.
    func saveToPhotoLibrary(_ image: UIImage) async throws {
        let hasAccess = await requestPhotoLibraryAccess()
        guard hasAccess else {
            throw PhotoServiceError.accessDenied
        }

        return try await withCheckedThrowingContinuation { continuation in
            PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            } completionHandler: { success, error in
                if success {
                    continuation.resume()
                } else {
                    continuation.resume(
                        throwing: PhotoServiceError.saveFailed(
                            error?.localizedDescription ?? "Unknown error"
                        )
                    )
                }
            }
        }
    }

    // MARK: - Photo Library Access

    /// Requests read/write access to the user's Photo Library.
    ///
    /// - Returns: `true` if access was granted (or already authorized), `false` otherwise.
    func requestPhotoLibraryAccess() async -> Bool {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)

        switch status {
        case .authorized, .limited:
            return true
        case .notDetermined:
            let newStatus = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
            return newStatus == .authorized || newStatus == .limited
        case .denied, .restricted:
            return false
        @unknown default:
            return false
        }
    }

    // MARK: - Upload Avatar to Supabase

    /// Uploads an avatar image to Supabase Storage and returns the public URL.
    ///
    /// - Parameters:
    ///   - image: The `UIImage` to upload.
    ///   - userId: The user's ID, used to namespace the file in storage.
    /// - Returns: The public URL string of the uploaded avatar.
    /// - Throws: `PhotoServiceError` if compression or upload fails.
    func uploadAvatar(_ image: UIImage, userId: UUID) async throws -> String {
        guard let data = compressImage(image, maxSizeKB: 500) else {
            throw PhotoServiceError.compressionFailed
        }

        let fileName = "\(UUID().uuidString).jpg"
        let path = "\(userId.uuidString)/\(fileName)"

        do {
            try await supabaseClient.storage
                .from(PhotoService.avatarBucket)
                .upload(
                    path,
                    data: data,
                    options: FileOptions(
                        cacheControl: "3600",
                        contentType: "image/jpeg",
                        upsert: true
                    )
                )

            let publicURL = try supabaseClient.storage
                .from(PhotoService.avatarBucket)
                .getPublicURL(path: path)

            return publicURL.absoluteString
        } catch {
            throw PhotoServiceError.uploadFailed(error.localizedDescription)
        }
    }

    // MARK: - Upload Attachment Images to Supabase

    /// Uploads multiple assignment attachment images to Supabase Storage.
    ///
    /// - Parameters:
    ///   - images: The array of `UIImage` to upload.
    ///   - userId: The user's ID for namespacing.
    ///   - assignmentId: The assignment ID for organizing uploads.
    /// - Returns: An array of public URL strings for each uploaded image.
    /// - Throws: `PhotoServiceError` if any upload fails.
    func uploadAttachmentImages(
        _ images: [UIImage],
        userId: UUID,
        assignmentId: UUID
    ) async throws -> [String] {
        var urls: [String] = []

        for (index, image) in images.enumerated() {
            guard let data = compressImage(image, maxSizeKB: 500) else {
                throw PhotoServiceError.compressionFailed
            }

            let fileName = "\(UUID().uuidString)_\(index).jpg"
            let path = "\(userId.uuidString)/\(assignmentId.uuidString)/\(fileName)"

            do {
                try await supabaseClient.storage
                    .from(PhotoService.attachmentBucket)
                    .upload(
                        path,
                        data: data,
                        options: FileOptions(
                            cacheControl: "3600",
                            contentType: "image/jpeg",
                            upsert: true
                        )
                    )

                let publicURL = try supabaseClient.storage
                    .from(PhotoService.attachmentBucket)
                    .getPublicURL(path: path)

                urls.append(publicURL.absoluteString)
            } catch {
                throw PhotoServiceError.uploadFailed(
                    "Failed to upload image \(index + 1): \(error.localizedDescription)"
                )
            }
        }

        return urls
    }

    // MARK: - Save Image Locally with FileManager

    /// Saves an image to the app's documents directory when Supabase is unavailable.
    ///
    /// - Parameters:
    ///   - image: The `UIImage` to save.
    ///   - fileName: The file name to use (without path).
    /// - Returns: The local file URL where the image was saved, or `nil` on failure.
    func saveImageLocally(_ image: UIImage, fileName: String) -> URL? {
        guard let data = compressImage(image, maxSizeKB: 500) else { return nil }

        let documentsURL = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first

        guard let directoryURL = documentsURL?.appendingPathComponent("ProfilePhotos") else {
            return nil
        }

        // Create directory if needed
        try? FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )

        let fileURL = directoryURL.appendingPathComponent(fileName)

        do {
            try data.write(to: fileURL)
            return fileURL
        } catch {
            #if DEBUG
            print("[PhotoService] Failed to save image locally: \(error)")
            #endif
            return nil
        }
    }
}
