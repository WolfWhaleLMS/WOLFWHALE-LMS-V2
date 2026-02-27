import LocalAuthentication

@Observable
@MainActor
class BiometricAuthService {
    var isBiometricAvailable: Bool = false
    var biometricType: LABiometryType = .none

    /// Auth state is read-only externally. Only `authenticate()` and `lock()` / `resetUnlockState()` can change it.
    private(set) var isUnlocked: Bool = false

    /// Optional reference to AuthService for refreshing the Supabase session
    /// after a successful biometric unlock. Injected by the caller (e.g. AppViewModel).
    var authService: AuthService?

    // MARK: - App-Level Failed Attempt Tracking

    /// Consecutive failed biometric attempts at the app level (defense-in-depth
    /// on top of iOS's built-in lockout after 5 failed attempts).
    private(set) var failedAttemptCount: Int = 0

    /// Maximum failed biometric attempts before the app locks out biometric
    /// auth and requires the password fallback.
    private let maxFailedAttempts: Int = 5

    /// When `true`, the app has exceeded its own failed-attempt threshold and
    /// requires password authentication instead of biometrics.
    var isAppLevelLockout: Bool {
        failedAttemptCount >= maxFailedAttempts
    }

    init() {
        checkBiometricAvailability()
    }

    /// Queries the device for Face ID / Touch ID support and updates published properties.
    func checkBiometricAvailability() {
        let context = LAContext()
        var error: NSError?
        let available = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
        isBiometricAvailable = available
        biometricType = context.biometryType
    }

    /// A human-readable label for the current biometric type ("Face ID", "Touch ID", or "Biometrics").
    var biometricName: String {
        switch biometricType {
        case .none:
            return "Biometrics"
        case .faceID:
            return "Face ID"
        case .touchID:
            return "Touch ID"
        case .opticID:
            return "Optic ID"
        @unknown default:
            return "Biometrics"
        }
    }

    /// The SF Symbol that represents the current biometric type.
    var biometricSystemImage: String {
        switch biometricType {
        case .none:
            return "lock.shield"
        case .faceID:
            return "faceid"
        case .touchID:
            return "touchid"
        case .opticID:
            return "opticid"
        @unknown default:
            return "lock.shield"
        }
    }

    /// Triggers the biometric prompt. Returns `true` on success.
    /// Throws `BiometricError` on failure so callers can react to specific cases.
    /// Automatically times out after 30 seconds to prevent hanging indefinitely.
    ///
    /// If the app-level lockout threshold has been exceeded, this method throws
    /// `.lockout` immediately without prompting biometrics -- callers must use
    /// the password fallback to unlock and call `resetFailedAttempts()` on success.
    @discardableResult
    func authenticate() async throws -> Bool {
        // App-level lockout: require password fallback
        guard !isAppLevelLockout else {
            throw BiometricError.lockout
        }

        let context = LAContext()
        context.localizedCancelTitle = "Cancel"

        // Disable the system fallback button so the user must use our own
        // password fallback (which has its own rate limiting).
        context.localizedFallbackTitle = ""

        var evalError: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &evalError) else {
            throw mapLAError(evalError)
        }

        do {
            let success = try await withThrowingTaskGroup(of: Bool.self) { group in
                group.addTask {
                    try await context.evaluatePolicy(
                        .deviceOwnerAuthenticationWithBiometrics,
                        localizedReason: "Unlock WolfWhale"
                    )
                }
                group.addTask {
                    try await Task.sleep(for: .seconds(30))
                    throw BiometricError.timeout
                }
                guard let result = try await group.next() else {
                    throw BiometricError.unknown("No result from biometric evaluation.")
                }
                group.cancelAll()
                return result
            }
            if success {
                isUnlocked = true
                failedAttemptCount = 0
                // Refresh the Supabase session after biometric success to ensure
                // the backend token is still valid. This prevents a stale JWT from
                // causing silent 401s on the next API call.
                if let authService {
                    let refreshed = await authService.refreshSession()
                    #if DEBUG
                    if !refreshed {
                        print("[BiometricAuth] Supabase session refresh failed after biometric unlock")
                    }
                    #endif
                }
            }
            return success
        } catch let error as BiometricError {
            if case .timeout = error { failedAttemptCount += 1 }
            throw error
        } catch let error as LAError {
            // Track authentication failures but not user-initiated cancellations
            if error.code == .authenticationFailed {
                failedAttemptCount += 1
            }
            throw mapLAError(error)
        } catch {
            failedAttemptCount += 1
            throw BiometricError.unknown(error.localizedDescription)
        }
    }

    // MARK: - State Management

    /// Locks the biometric state. Called when the app enters the background or
    /// the user explicitly locks the app.
    func lock() {
        isUnlocked = false
    }

    /// Marks the app as unlocked after a successful password verification.
    /// Only call this after the caller has independently verified the user's
    /// password against the authentication backend.
    func markUnlockedAfterPasswordVerification() {
        isUnlocked = true
        failedAttemptCount = 0
    }

    /// Resets the app-level failed attempt counter. Called after a successful
    /// password-based re-authentication so the user can attempt biometrics again.
    func resetFailedAttempts() {
        failedAttemptCount = 0
    }

    // MARK: - Error Mapping

    private func mapLAError(_ error: NSError?) -> BiometricError {
        guard let error else { return .notAvailable }
        return mapLAError(LAError(LAError.Code(rawValue: error.code) ?? .appCancel))
    }

    private func mapLAError(_ error: LAError) -> BiometricError {
        switch error.code {
        case .biometryNotAvailable:
            return .notAvailable
        case .biometryNotEnrolled:
            return .notEnrolled
        case .biometryLockout:
            return .lockout
        case .userCancel, .appCancel, .systemCancel:
            return .cancelled
        case .userFallback:
            return .userFallback
        case .authenticationFailed:
            return .authenticationFailed
        case .passcodeNotSet:
            return .passcodeNotSet
        default:
            return .unknown(error.localizedDescription)
        }
    }
}

// MARK: - BiometricError

enum BiometricError: LocalizedError, Sendable {
    case notAvailable
    case notEnrolled
    case lockout
    case cancelled
    case userFallback
    case authenticationFailed
    case passcodeNotSet
    case timeout
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "Biometric authentication is not available on this device."
        case .notEnrolled:
            return "No biometric data is enrolled. Please set up Face ID or Touch ID in Settings."
        case .lockout:
            return "Biometric authentication is locked. Please use your password to unlock."
        case .cancelled:
            return "Authentication was cancelled."
        case .userFallback:
            return "User chose to enter a password instead."
        case .authenticationFailed:
            return "Biometric authentication failed. Please try again."
        case .passcodeNotSet:
            return "A device passcode is required to use biometric authentication."
        case .timeout:
            return "Biometric authentication timed out. Please try again."
        case .unknown(let message):
            return message
        }
    }
}
