import Foundation

/// Centralized localization strings for the app.
/// Supports English (default) and French.
///
/// Usage:
///   Text(L10n.login)          // "Log In" or "Se connecter"
///   L10n.setLanguage("fr")    // switch to French
@MainActor enum L10n {

    // MARK: - Current Language

    /// The two-letter language code currently in effect ("en" or "fr").
    static var currentLanguage: String {
        UserDefaults.standard.string(forKey: "wolfwhale_app_language") ?? "en"
    }

    /// Persist the chosen language.
    static func setLanguage(_ code: String) {
        UserDefaults.standard.set(code, forKey: "wolfwhale_app_language")
    }

    /// All language codes the app supports.
    static let supportedLanguages: [(code: String, name: String)] = [
        ("en", "English"),
        ("fr", "Français")
    ]

    // MARK: - Lookup

    /// Returns the translated string for `key` in the current language,
    /// falling back to English, then returning the raw key.
    static func localized(_ key: String) -> String {
        let translations: [String: [String: String]] = [
            "en": englishStrings,
            "fr": frenchStrings
        ]
        return translations[currentLanguage]?[key]
            ?? translations["en"]?[key]
            ?? key
    }

    // MARK: - Common

    static var appName: String { localized("app.name") }
    static var ok: String { localized("common.ok") }
    static var cancel: String { localized("common.cancel") }
    static var save: String { localized("common.save") }
    static var delete: String { localized("common.delete") }
    static var edit: String { localized("common.edit") }
    static var done: String { localized("common.done") }
    static var search: String { localized("common.search") }
    static var loading: String { localized("common.loading") }
    static var error: String { localized("common.error") }
    static var retry: String { localized("common.retry") }
    static var submit: String { localized("common.submit") }
    static var back: String { localized("common.back") }
    static var next: String { localized("common.next") }
    static var previous: String { localized("common.previous") }

    // MARK: - Auth

    static var login: String { localized("auth.login") }
    static var signUp: String { localized("auth.signup") }
    static var logout: String { localized("auth.logout") }
    static var email: String { localized("auth.email") }
    static var password: String { localized("auth.password") }
    static var forgotPassword: String { localized("auth.forgot_password") }
    static var createAccount: String { localized("auth.create_account") }
    static var welcomeBack: String { localized("auth.welcome_back") }

    // MARK: - Tabs

    static var dashboard: String { localized("tabs.dashboard") }
    static var courses: String { localized("tabs.courses") }
    static var assignments: String { localized("tabs.assignments") }
    static var grades: String { localized("tabs.grades") }
    static var messages: String { localized("tabs.messages") }
    static var settings: String { localized("tabs.settings") }
    static var attendance: String { localized("tabs.attendance") }
    static var tools: String { localized("tabs.tools") }
    static var tabHome: String { localized("tabs.home") }
    static var tabProfile: String { localized("tabs.profile") }
    static var tabResources: String { localized("tabs.resources") }
    static var tabConsole: String { localized("tabs.console") }
    static var tabTenants: String { localized("tabs.tenants") }
    static var tabUsers: String { localized("tabs.users") }
    static var tabAnnounce: String { localized("tabs.announce") }

    // MARK: - Dashboard

    static var welcomeStudent: String { localized("dashboard.welcome_student") }
    static var upcomingAssignments: String { localized("dashboard.upcoming_assignments") }
    static var recentGrades: String { localized("dashboard.recent_grades") }
    static var todaySchedule: String { localized("dashboard.today_schedule") }
    static var noUpcomingAssignments: String { localized("dashboard.no_upcoming") }
    static var viewAll: String { localized("dashboard.view_all") }

    // MARK: - Courses

    static var myCourses: String { localized("courses.my_courses") }
    static var courseCatalog: String { localized("courses.catalog") }
    static var enroll: String { localized("courses.enroll") }
    static var dropCourse: String { localized("courses.drop") }
    static var enrolled: String { localized("courses.enrolled") }
    static var noCourses: String { localized("courses.no_courses") }

    // MARK: - Assignments

    static var dueDate: String { localized("assignments.due_date") }
    static var submitAssignment: String { localized("assignments.submit") }
    static var submitted: String { localized("assignments.submitted") }
    static var late: String { localized("assignments.late") }
    static var noAssignments: String { localized("assignments.no_assignments") }

    // MARK: - Grades

    static var gpa: String { localized("grades.gpa") }
    static var letterGrade: String { localized("grades.letter_grade") }
    static var noGrades: String { localized("grades.no_grades") }
    static var reportCard: String { localized("grades.report_card") }

    // MARK: - Messages

    static var newMessage: String { localized("messages.new_message") }
    static var noMessages: String { localized("messages.no_messages") }
    static var typeMessage: String { localized("messages.type_message") }
    static var send: String { localized("messages.send") }

    // MARK: - Settings

    static var profile: String { localized("settings.profile") }
    static var notifications: String { localized("settings.notifications") }
    static var appearance: String { localized("settings.appearance") }
    static var language: String { localized("settings.language") }
    static var privacy: String { localized("settings.privacy") }
    static var deleteAccount: String { localized("settings.delete_account") }

    // MARK: - Empty States

    static var allCaughtUp: String { localized("empty.all_caught_up") }
    static var nothingHere: String { localized("empty.nothing_here") }

    // MARK: - Errors

    static var networkError: String { localized("error.network") }
    static var tryAgain: String { localized("error.try_again") }
    static var somethingWentWrong: String { localized("error.something_wrong") }
}
