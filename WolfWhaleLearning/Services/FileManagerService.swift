import Foundation
import Supabase

/// Service for managing uploaded files: listing, downloading, deleting, and previewing.
/// Uses the global `supabaseClient` defined in SupabaseService.swift.
@MainActor @Observable
final class FileManagerService {
    var error: String?
    var isLoading = false
    var files: [FileItem] = []

    private let fileUploadService = FileUploadService()

    // MARK: - Date Parsing

    nonisolated(unsafe) private let iso8601: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    nonisolated(unsafe) private let fallbackFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }()

    private func parseDate(_ str: String?) -> Date {
        guard let str else { return Date() }
        return iso8601.date(from: str)
            ?? fallbackFormatter.date(from: str)
            ?? Date()
    }

    // MARK: - Fetch User Files

    /// Fetches all files uploaded by a user by querying their submissions and extracting
    /// attachment URLs. Also resolves course and assignment names for display.
    func fetchUserFiles(userId: UUID) async {
        isLoading = true
        error = nil

        do {
            // Fetch all submissions by this student
            let submissions: [SubmissionDTO] = try await supabaseClient
                .from("submissions")
                .select()
                .eq("student_id", value: userId.uuidString)
                .order("submitted_at", ascending: false)
                .execute()
                .value

            // Collect assignment IDs to resolve names and course info
            let assignmentIds = Array(Set(submissions.map(\.assignmentId)))
            var assignmentMap: [UUID: AssignmentDTO] = [:]
            if !assignmentIds.isEmpty {
                let assignments: [AssignmentDTO] = try await supabaseClient
                    .from("assignments")
                    .select()
                    .in("id", values: assignmentIds.map(\.uuidString))
                    .execute()
                    .value
                for a in assignments {
                    assignmentMap[a.id] = a
                }
            }

            // Resolve course names
            let courseIds = Array(Set(assignmentMap.values.map(\.courseId)))
            var courseMap: [UUID: String] = [:]
            if !courseIds.isEmpty {
                let courses: [CourseDTO] = try await supabaseClient
                    .from("courses")
                    .select()
                    .in("id", values: courseIds.map(\.uuidString))
                    .execute()
                    .value
                for c in courses {
                    courseMap[c.id] = c.name
                }
            }

            // Parse submissions to extract file items
            var items: [FileItem] = []
            for sub in submissions {
                guard let text = sub.submissionText, text.contains("[Attachments]") else { continue }

                let lines = text.components(separatedBy: "\n")
                let attachmentStartIndex = lines.firstIndex(where: { $0.contains("[Attachments]") })
                guard let startIdx = attachmentStartIndex else { continue }

                let urlLines = lines[(startIdx + 1)...].filter { line in
                    let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                    return !trimmed.isEmpty && (trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://"))
                }

                let assignment = assignmentMap[sub.assignmentId]
                let courseId = assignment?.courseId
                let courseName = courseId.flatMap { courseMap[$0] }

                for urlString in urlLines {
                    let trimmedURL = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
                    let fileName = extractFileName(from: trimmedURL)
                    let ext = (fileName as NSString).pathExtension
                    let nameOnly = (fileName as NSString).deletingPathExtension

                    let item = FileItem(
                        id: UUID(),
                        fileName: nameOnly.isEmpty ? "Unnamed File" : nameOnly,
                        fileExtension: ext.isEmpty ? "bin" : ext,
                        fileSize: 0,
                        uploadDate: parseDate(sub.submittedAt),
                        courseId: courseId,
                        courseName: courseName,
                        assignmentId: sub.assignmentId,
                        assignmentName: assignment?.title,
                        storageURL: trimmedURL,
                        uploaderId: userId
                    )
                    items.append(item)
                }
            }

            files = items
        } catch {
            self.error = "Failed to load files: \(error.localizedDescription)"
        }

        isLoading = false
    }

    // MARK: - Fetch Submission Files

    /// Fetches all submissions for a specific assignment and extracts file attachments.
    func fetchSubmissionFiles(assignmentId: UUID) async {
        isLoading = true
        error = nil

        do {
            let submissions: [SubmissionDTO] = try await supabaseClient
                .from("submissions")
                .select()
                .eq("assignment_id", value: assignmentId.uuidString)
                .order("submitted_at", ascending: false)
                .execute()
                .value

            // Resolve student names
            let studentIds = Array(Set(submissions.map(\.studentId)))
            var studentNames: [UUID: String] = [:]
            if !studentIds.isEmpty {
                let profiles: [ProfileDTO] = try await supabaseClient
                    .from("profiles")
                    .select()
                    .in("id", values: studentIds.map(\.uuidString))
                    .execute()
                    .value
                for p in profiles {
                    studentNames[p.id] = "\(p.firstName ?? "") \(p.lastName ?? "")"
                }
            }

            // Resolve assignment details
            let assignments: [AssignmentDTO] = try await supabaseClient
                .from("assignments")
                .select()
                .eq("id", value: assignmentId.uuidString)
                .limit(1)
                .execute()
                .value
            let assignment = assignments.first
            let courseId = assignment?.courseId

            var courseName: String?
            if let cid = courseId {
                let courses: [CourseDTO] = try await supabaseClient
                    .from("courses")
                    .select()
                    .eq("id", value: cid.uuidString)
                    .limit(1)
                    .execute()
                    .value
                courseName = courses.first?.name
            }

            var items: [FileItem] = []
            for sub in submissions {
                guard let text = sub.submissionText, text.contains("[Attachments]") else { continue }

                let lines = text.components(separatedBy: "\n")
                let attachmentStartIndex = lines.firstIndex(where: { $0.contains("[Attachments]") })
                guard let startIdx = attachmentStartIndex else { continue }

                let urlLines = lines[(startIdx + 1)...].filter { line in
                    let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                    return !trimmed.isEmpty && (trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://"))
                }

                for urlString in urlLines {
                    let trimmedURL = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
                    let fileName = extractFileName(from: trimmedURL)
                    let ext = (fileName as NSString).pathExtension
                    let nameOnly = (fileName as NSString).deletingPathExtension

                    let item = FileItem(
                        id: UUID(),
                        fileName: nameOnly.isEmpty ? (studentNames[sub.studentId] ?? "Unnamed") : nameOnly,
                        fileExtension: ext.isEmpty ? "bin" : ext,
                        fileSize: 0,
                        uploadDate: parseDate(sub.submittedAt),
                        courseId: courseId,
                        courseName: courseName,
                        assignmentId: assignmentId,
                        assignmentName: assignment?.title,
                        storageURL: trimmedURL,
                        uploaderId: sub.studentId
                    )
                    items.append(item)
                }
            }

            files = items
        } catch {
            self.error = "Failed to load submission files: \(error.localizedDescription)"
        }

        isLoading = false
    }

    // MARK: - Download File

    /// Downloads a file from a URL and returns the raw data.
    func downloadFile(url: String) async -> Data? {
        guard let fileURL = URL(string: url) else {
            error = "Invalid file URL."
            return nil
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: fileURL)
            return data
        } catch {
            self.error = "Download failed: \(error.localizedDescription)"
            return nil
        }
    }

    // MARK: - Delete File

    /// Deletes a file from Supabase Storage and removes it from the local list.
    func deleteFile(fileId: UUID, storagePath: String) async -> Bool {
        do {
            try await fileUploadService.deleteFile(
                bucket: FileUploadService.Bucket.assignmentSubmissions,
                path: storagePath
            )
            files.removeAll { $0.id == fileId }
            return true
        } catch {
            self.error = "Failed to delete file: \(error.localizedDescription)"
            return false
        }
    }

    // MARK: - File Preview Data

    /// Downloads file data for preview purposes.
    func getFilePreviewData(for file: FileItem) async -> Data? {
        await downloadFile(url: file.storageURL)
    }

    // MARK: - Helpers

    /// Extracts a file name from a Supabase public URL.
    private func extractFileName(from urlString: String) -> String {
        guard let url = URL(string: urlString) else { return "Unknown" }
        let lastComponent = url.lastPathComponent
        return lastComponent.removingPercentEncoding ?? lastComponent
    }
}
