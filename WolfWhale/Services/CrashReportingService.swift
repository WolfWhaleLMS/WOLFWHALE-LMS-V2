import Foundation
import os
import Supabase

/// DTO for inserting crash/error reports into the audit_logs table.
private nonisolated struct CrashLogInsertDTO: Encodable, Sendable {
    let action: String
    let details: String
    let timestamp: String

    enum CodingKeys: String, CodingKey {
        case action, details, timestamp
    }
}

/// Lightweight crash & error reporting service
/// Logs critical errors to Supabase audit_logs table for monitoring
@MainActor @Observable
final class CrashReportingService {

    static let shared = CrashReportingService()

    private nonisolated static let logger = Logger(subsystem: "com.wolfwhale.lms", category: "CrashReporting")

    /// Key for persisting failed crash reports to disk so they survive app restarts.
    private nonisolated static let failedReportsKey = "com.wolfwhale.failedCrashReports"

    private var errorBuffer: [(date: Date, error: String, context: String)] = []
    private let maxBufferSize = 50
    private var flushTask: Task<Void, Never>?

    // MARK: - Error Severity
    enum Severity: String, Sendable {
        case info = "info"
        case warning = "warning"
        case error = "error"
        case critical = "critical"
        case fatal = "fatal"
    }

    // MARK: - Report Error
    nonisolated func report(
        _ error: Error,
        severity: Severity = .error,
        context: String = #function,
        file: String = #file,
        line: Int = #line
    ) {
        let errorDescription = String(describing: error)
        let fileName = (file as NSString).lastPathComponent
        let logEntry = "[\(severity.rawValue.uppercased())] \(fileName):\(line) \(context) — \(errorDescription)"

        #if DEBUG
        print("CrashReport: \(logEntry)")
        #endif

        Task { @MainActor in
            self.bufferError(logEntry, context: context)
        }
    }

    // MARK: - Report with Message
    nonisolated func report(
        message: String,
        severity: Severity = .warning,
        context: String = #function,
        file: String = #file,
        line: Int = #line
    ) {
        let fileName = (file as NSString).lastPathComponent
        let logEntry = "[\(severity.rawValue.uppercased())] \(fileName):\(line) \(context) — \(message)"

        #if DEBUG
        print("CrashReport: \(logEntry)")
        #endif

        Task { @MainActor in
            self.bufferError(logEntry, context: context)
        }
    }

    // MARK: - Buffer & Flush
    private func bufferError(_ error: String, context: String) {
        errorBuffer.append((date: Date(), error: error, context: context))

        if errorBuffer.count >= maxBufferSize {
            flush()
        } else if flushTask == nil {
            // Auto-flush after 30 seconds
            flushTask = Task {
                try? await Task.sleep(for: .seconds(30))
                guard !Task.isCancelled else { return }
                flush()
            }
        }
    }

    func flush() {
        guard !errorBuffer.isEmpty else { return }
        let errors = errorBuffer
        errorBuffer.removeAll()
        flushTask?.cancel()
        flushTask = nil

        Task.detached(priority: .utility) {
            var failedEntries: [[String: String]] = []

            for entry in errors {
                let dto = CrashLogInsertDTO(
                    action: "error_report",
                    details: "[\(entry.context)] \(entry.error)",
                    timestamp: ISO8601DateFormatter().string(from: entry.date)
                )
                do {
                    try await supabaseClient
                        .from("audit_logs")
                        .insert(dto)
                        .execute()
                } catch {
                    Self.logger.error("[CrashReporting] Failed to upload crash report: \(error.localizedDescription, privacy: .public)")
                    #if DEBUG
                    print("[CrashReporting] Failed to upload crash report: \(error)")
                    #endif
                    // Persist failed entry for later retry
                    failedEntries.append([
                        "context": entry.context,
                        "error": entry.error,
                        "timestamp": ISO8601DateFormatter().string(from: entry.date)
                    ])
                }
            }

            // Persist any failed reports to disk so they can be retried later
            if !failedEntries.isEmpty {
                Self.persistFailedReports(failedEntries)
            }
        }
    }

    // MARK: - Failed Report Persistence

    /// Persists failed crash report entries to UserDefaults for retry on next flush.
    private nonisolated static func persistFailedReports(_ newEntries: [[String: String]]) {
        var existing = UserDefaults.standard.array(forKey: failedReportsKey) as? [[String: String]] ?? []
        existing.append(contentsOf: newEntries)
        // Cap stored reports at 200 to prevent unbounded growth
        if existing.count > 200 {
            existing = Array(existing.suffix(200))
        }
        UserDefaults.standard.set(existing, forKey: failedReportsKey)
    }

    /// Retries uploading any previously failed crash reports.
    /// Call this on app launch or when connectivity is restored.
    func retryFailedReports() {
        let stored = UserDefaults.standard.array(forKey: Self.failedReportsKey) as? [[String: String]] ?? []
        guard !stored.isEmpty else { return }

        // Clear the stored reports immediately to avoid duplicate retries
        UserDefaults.standard.removeObject(forKey: Self.failedReportsKey)

        Task.detached(priority: .utility) {
            var stillFailed: [[String: String]] = []

            for entry in stored {
                let dto = CrashLogInsertDTO(
                    action: "error_report",
                    details: "[\(entry["context"] ?? "unknown")] \(entry["error"] ?? "")",
                    timestamp: entry["timestamp"] ?? ISO8601DateFormatter().string(from: Date())
                )
                do {
                    try await supabaseClient
                        .from("audit_logs")
                        .insert(dto)
                        .execute()
                } catch {
                    Self.logger.error("[CrashReporting] Retry upload failed: \(error.localizedDescription, privacy: .public)")
                    stillFailed.append(entry)
                }
            }

            if !stillFailed.isEmpty {
                Self.persistFailedReports(stillFailed)
            }
        }
    }

    // MARK: - Setup Signal Handlers
    func setupCrashHandlers() {
        NSSetUncaughtExceptionHandler { exception in
            let stackTrace = exception.callStackSymbols.joined(separator: "\n")
            let message = "UNCAUGHT EXCEPTION: \(exception.name.rawValue) — \(exception.reason ?? "unknown")\n\(stackTrace)"
            UserDefaults.standard.set(message, forKey: "com.wolfwhale.lastCrash")
        }

        // Check for previous crash on launch
        if let lastCrash = UserDefaults.standard.string(forKey: "com.wolfwhale.lastCrash") {
            report(message: lastCrash, severity: .fatal, context: "previousSessionCrash")
            UserDefaults.standard.removeObject(forKey: "com.wolfwhale.lastCrash")
        }
    }
}
