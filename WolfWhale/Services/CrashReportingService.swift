import Foundation
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
            for entry in errors {
                let dto = CrashLogInsertDTO(
                    action: "error_report",
                    details: "[\(entry.context)] \(entry.error)",
                    timestamp: ISO8601DateFormatter().string(from: entry.date)
                )
                try? await supabaseClient
                    .from("audit_logs")
                    .insert(dto)
                    .execute()
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
