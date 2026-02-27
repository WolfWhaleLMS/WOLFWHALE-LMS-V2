import Foundation
import os
import Supabase

/// Centralized App Store compliance utilities for COPPA, terms acceptance,
/// export compliance, and version information.
nonisolated enum AppStoreCompliance {

    private static let logger = Logger(subsystem: "com.wolfwhale.lms", category: "AppStoreCompliance")

    // MARK: - COPPA Age Verification

    /// A calendar configured with the user's current timezone for accurate age calculations.
    private static var localCalendar: Calendar {
        var cal = Calendar.current
        cal.timeZone = TimeZone.current
        return cal
    }

    /// Returns `true` if the user is under 13 years old based on their date of birth.
    static func isUnder13(dateOfBirth: Date) -> Bool {
        let age = localCalendar.dateComponents([.year], from: dateOfBirth, to: Date()).year ?? 0
        return age < 13
    }

    /// Returns `true` if verifiable parental consent is required (COPPA).
    static func requiresParentalConsent(dateOfBirth: Date) -> Bool {
        isUnder13(dateOfBirth: dateOfBirth)
    }

    /// Returns the calculated age in years from a date of birth.
    static func age(from dateOfBirth: Date) -> Int {
        localCalendar.dateComponents([.year], from: dateOfBirth, to: Date()).year ?? 0
    }

    /// Minimum allowed age for the platform (school LMS).
    static let minimumAge: Int = 5

    /// Returns `true` if the user meets the minimum age requirement.
    static func meetsMinimumAge(dateOfBirth: Date) -> Bool {
        age(from: dateOfBirth) >= minimumAge
    }

    // MARK: - Server-Synced Consent

    // MARK: - Consent Sync Retry Flag

    /// Key used to persist the retry flag when consent sync fails.
    private static func consentSyncPendingKey(for userId: UUID) -> String {
        "wolfwhale_coppa_consent_sync_pending_\(userId.uuidString)"
    }

    /// Returns `true` if a previous consent sync failed and needs to be retried.
    static func isConsentSyncPending(for userId: UUID) -> Bool {
        UserDefaults.standard.bool(forKey: consentSyncPendingKey(for: userId))
    }

    /// Syncs the COPPA consent status to the server (Supabase) so that
    /// server-side data is the source of truth, not local UserDefaults.
    ///
    /// On failure the error is logged and a retry flag is persisted so the app
    /// can call this again on next launch or connectivity change.
    static func syncConsentToServer(
        userId: UUID,
        hasParentalConsent: Bool,
        parentEmail: String? = nil,
        dateOfBirth: Date? = nil
    ) async {
        var params: [String: String] = [
            "user_id": userId.uuidString,
            "has_parental_consent": hasParentalConsent ? "true" : "false"
        ]
        if let parentEmail {
            params["parent_email"] = parentEmail
        }
        if let dateOfBirth {
            let formatter = ISO8601DateFormatter()
            params["date_of_birth"] = formatter.string(from: dateOfBirth)
        }
        params["consent_recorded_at"] = ISO8601DateFormatter().string(from: Date())

        // Update server -- this is the source of truth.
        // COPPA consent MUST reach the server for legal compliance, so failures
        // are logged and a retry flag is set.
        do {
            _ = try await supabaseClient
                .from("profiles")
                .update([
                    "coppa_consent": hasParentalConsent ? "granted" : "pending",
                    "coppa_parent_email": parentEmail ?? "",
                    "coppa_consent_date": ISO8601DateFormatter().string(from: Date())
                ])
                .eq("id", value: userId.uuidString)
                .execute()

            // Sync succeeded — clear any pending retry flag
            UserDefaults.standard.set(false, forKey: consentSyncPendingKey(for: userId))
        } catch {
            // Sync failed — set retry flag so the app can attempt again later
            UserDefaults.standard.set(true, forKey: consentSyncPendingKey(for: userId))
            logger.error("[AppStoreCompliance] COPPA consent sync failed for user \(userId.uuidString, privacy: .public): \(error.localizedDescription, privacy: .public)")
            #if DEBUG
            print("[AppStoreCompliance] COPPA consent sync failed: \(error)")
            #endif
        }

        // Cache locally for offline access
        UserDefaults.standard.set(hasParentalConsent, forKey: "wolfwhale_coppa_consent_\(userId.uuidString)")
    }

    /// Reads the locally cached COPPA consent status. This is a cache only --
    /// the server value is the source of truth.
    static func cachedConsentStatus(for userId: UUID) -> Bool {
        UserDefaults.standard.bool(forKey: "wolfwhale_coppa_consent_\(userId.uuidString)")
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
