import Foundation
import os.log

/// Centralized logging with os_log for production diagnostics
enum AppLogger {

    private static let subsystem = "ca.wolfwhale.lms"

    // MARK: - Category Loggers
    static let auth = Logger(subsystem: subsystem, category: "auth")
    static let network = Logger(subsystem: subsystem, category: "network")
    static let data = Logger(subsystem: subsystem, category: "data")
    static let sync = Logger(subsystem: subsystem, category: "sync")
    static let ui = Logger(subsystem: subsystem, category: "ui")
    static let push = Logger(subsystem: subsystem, category: "push")
    static let cache = Logger(subsystem: subsystem, category: "cache")
    static let security = Logger(subsystem: subsystem, category: "security")
    static let grades = Logger(subsystem: subsystem, category: "grades")
    static let realtime = Logger(subsystem: subsystem, category: "realtime")
}
