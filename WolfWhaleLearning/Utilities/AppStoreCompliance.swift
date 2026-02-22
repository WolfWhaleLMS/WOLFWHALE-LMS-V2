import Foundation

/// Centralized App Store compliance utilities for COPPA, terms acceptance,
/// export compliance, and version information.
nonisolated enum AppStoreCompliance {

    // MARK: - COPPA Age Verification

    /// Returns `true` if the user is under 13 years old based on their date of birth.
    static func isUnder13(dateOfBirth: Date) -> Bool {
        let age = Calendar.current.dateComponents([.year], from: dateOfBirth, to: Date()).year ?? 0
        return age < 13
    }

    /// Returns `true` if verifiable parental consent is required (COPPA).
    static func requiresParentalConsent(dateOfBirth: Date) -> Bool {
        isUnder13(dateOfBirth: dateOfBirth)
    }

    /// Returns the calculated age in years from a date of birth.
    static func age(from dateOfBirth: Date) -> Int {
        Calendar.current.dateComponents([.year], from: dateOfBirth, to: Date()).year ?? 0
    }

    /// Minimum allowed age for the platform (school LMS).
    static let minimumAge: Int = 5

    /// Returns `true` if the user meets the minimum age requirement.
    static func meetsMinimumAge(dateOfBirth: Date) -> Bool {
        age(from: dateOfBirth) >= minimumAge
    }

    // MARK: - Terms Acceptance

    /// Whether the user has accepted the Terms of Service.
    static var hasAcceptedTerms: Bool {
        get { UserDefaults.standard.bool(forKey: "wolfwhale_accepted_terms") }
        set { UserDefaults.standard.set(newValue, forKey: "wolfwhale_accepted_terms") }
    }

    /// Whether the user has accepted the Privacy Policy.
    static var hasAcceptedPrivacy: Bool {
        get { UserDefaults.standard.bool(forKey: "wolfwhale_accepted_privacy") }
        set { UserDefaults.standard.set(newValue, forKey: "wolfwhale_accepted_privacy") }
    }

    /// The date when terms were last accepted.
    static var termsAcceptedDate: Date? {
        get { UserDefaults.standard.object(forKey: "wolfwhale_terms_date") as? Date }
        set { UserDefaults.standard.set(newValue, forKey: "wolfwhale_terms_date") }
    }

    /// The app version when terms were last accepted.
    static var termsAcceptedVersion: String? {
        get { UserDefaults.standard.string(forKey: "wolfwhale_terms_version") }
        set { UserDefaults.standard.set(newValue, forKey: "wolfwhale_terms_version") }
    }

    /// Records that the user accepted both Terms of Service and Privacy Policy right now.
    static func recordTermsAcceptance() {
        hasAcceptedTerms = true
        hasAcceptedPrivacy = true
        termsAcceptedDate = Date()
        termsAcceptedVersion = appVersion
    }

    /// Clears all stored terms acceptance (e.g. on logout or account deletion).
    static func clearTermsAcceptance() {
        hasAcceptedTerms = false
        hasAcceptedPrivacy = false
        termsAcceptedDate = nil
        termsAcceptedVersion = nil
    }

    /// Whether the user needs to re-accept terms (e.g. after a terms update).
    /// Returns `true` if terms have never been accepted, or if accepted on a previous version.
    static var needsTermsReAcceptance: Bool {
        guard hasAcceptedTerms, hasAcceptedPrivacy else { return true }
        // If the terms were accepted on an older version, require re-acceptance.
        // Update this constant whenever the terms are materially changed.
        let currentTermsVersion = "1.0"
        return termsAcceptedVersion != currentTermsVersion
    }

    // MARK: - Version Info

    /// The app's marketing version (CFBundleShortVersionString).
    static var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    /// The app's build number (CFBundleVersion).
    static var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    /// Formatted version string for display (e.g. "1.0 (42)").
    static var formattedVersion: String {
        "\(appVersion) (\(buildNumber))"
    }

    // MARK: - Export Compliance

    /// Whether the app uses encryption that requires export compliance documentation.
    /// WolfWhale LMS uses HTTPS (TLS) for network communication, which qualifies
    /// for the standard encryption exemption (ECCN 5D002 / TSU exception).
    static let usesEncryption: Bool = true

    /// Whether the app qualifies for the standard encryption exemption.
    /// Apps using only HTTPS/TLS for communication qualify for the exemption.
    static let qualifiesForEncryptionExemption: Bool = true

    // MARK: - Privacy Nutrition Label Categories

    /// Categories of data collected by the app, for App Store privacy label reference.
    enum DataCollectionCategory: String, CaseIterable {
        case contactInfo = "Contact Info"
        case identifiers = "Identifiers"
        case usageData = "Usage Data"
        case healthAndFitness = "Health & Fitness"
        case location = "Location"

        var description: String {
            switch self {
            case .contactInfo:
                return "Name, email address, school affiliation"
            case .identifiers:
                return "User ID, device ID"
            case .usageData:
                return "App interactions, page views, session data"
            case .healthAndFitness:
                return "Steps, activity data (optional, HealthKit)"
            case .location:
                return "Campus geofencing only (optional)"
            }
        }

        var isOptional: Bool {
            switch self {
            case .contactInfo, .identifiers:
                return false
            case .usageData, .healthAndFitness, .location:
                return true
            }
        }

        var linkedToIdentity: Bool {
            switch self {
            case .contactInfo, .identifiers:
                return true
            case .usageData, .healthAndFitness, .location:
                return false
            }
        }

        var usedForTracking: Bool {
            false
        }
    }
}
