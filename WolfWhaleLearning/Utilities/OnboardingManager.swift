import Foundation

/// Manages onboarding and "What's New" state via UserDefaults.
/// All members are static so no instance is needed — use `OnboardingManager.hasCompletedOnboarding` etc.
nonisolated enum OnboardingManager {

    // MARK: - Onboarding

    static var hasCompletedOnboarding: Bool {
        get { UserDefaults.standard.bool(forKey: "wolfwhale_onboarding_complete") }
        set { UserDefaults.standard.set(newValue, forKey: "wolfwhale_onboarding_complete") }
    }

    // MARK: - What's New

    static var lastSeenVersion: String? {
        get { UserDefaults.standard.string(forKey: "wolfwhale_last_seen_version") }
        set { UserDefaults.standard.set(newValue, forKey: "wolfwhale_last_seen_version") }
    }

    static var currentAppVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    static var shouldShowWhatsNew: Bool {
        guard hasCompletedOnboarding else { return false }
        return lastSeenVersion != currentAppVersion
    }

    // MARK: - Notification Permission

    static var hasRequestedNotifications: Bool {
        get { UserDefaults.standard.bool(forKey: "wolfwhale_requested_notifications") }
        set { UserDefaults.standard.set(newValue, forKey: "wolfwhale_requested_notifications") }
    }

    // MARK: - Biometric Opt-In During Onboarding

    static var hasConfiguredBiometric: Bool {
        get { UserDefaults.standard.bool(forKey: "wolfwhale_configured_biometric") }
        set { UserDefaults.standard.set(newValue, forKey: "wolfwhale_configured_biometric") }
    }

    // MARK: - Actions

    static func markOnboardingComplete() {
        hasCompletedOnboarding = true
        markVersionSeen()
    }

    static func markVersionSeen() {
        lastSeenVersion = currentAppVersion
    }

    /// Resets all onboarding state. Useful for testing.
    static func resetOnboarding() {
        hasCompletedOnboarding = false
        lastSeenVersion = nil
        hasRequestedNotifications = false
        hasConfiguredBiometric = false
    }
}
