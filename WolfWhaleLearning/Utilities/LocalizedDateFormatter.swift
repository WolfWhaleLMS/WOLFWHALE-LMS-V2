import Foundation

/// Locale-aware date formatting that respects the app's language setting.
///
/// All formatters use the `Locale` matching `L10n.currentLanguage`
/// so dates render in the same language as the rest of the UI,
/// regardless of the device's system locale.
nonisolated enum LocalizedDateFormatter {

    // MARK: - Private Helpers

    /// A Foundation `Locale` derived from the app's chosen language.
    private static var currentLocale: Locale {
        Locale(identifier: L10n.currentLanguage)
    }

    /// Reusable date formatter factory. A new instance is created on
    /// every call because the user can change the language at runtime.
    private static func makeFormatter(
        dateStyle: DateFormatter.Style = .none,
        timeStyle: DateFormatter.Style = .none
    ) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = currentLocale
        formatter.dateStyle = dateStyle
        formatter.timeStyle = timeStyle
        return formatter
    }

    // MARK: - Public API

    /// Short numeric date, e.g. "2/21/26" or "21/02/26".
    static func shortDate(_ date: Date) -> String {
        makeFormatter(dateStyle: .short).string(from: date)
    }

    /// Medium date, e.g. "Feb 21, 2026" or "21 f\u{00E9}vr. 2026".
    static func mediumDate(_ date: Date) -> String {
        makeFormatter(dateStyle: .medium).string(from: date)
    }

    /// Short time, e.g. "3:30 PM" or "15:30".
    static func shortTime(_ date: Date) -> String {
        makeFormatter(timeStyle: .short).string(from: date)
    }

    /// Relative description such as "2 hours ago" / "il y a 2 heures",
    /// or "in 3 days" / "dans 3 jours".
    static func relativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = currentLocale
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    /// Full day-of-week name, e.g. "Saturday" / "samedi".
    static func dayOfWeek(_ date: Date) -> String {
        let formatter = makeFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: date)
    }

    /// Medium date + short time, e.g. "Feb 21, 2026 at 3:30 PM".
    static func dateAndTime(_ date: Date) -> String {
        makeFormatter(dateStyle: .medium, timeStyle: .short).string(from: date)
    }
}
