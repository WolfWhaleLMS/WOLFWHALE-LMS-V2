import LocalAuthentication

@Observable
@MainActor
class BiometricAuthService {
    var isBiometricAvailable: Bool = false
    var biometricType: LABiometryType = .none
    var isUnlocked: Bool = false

    /// Optional reference to AuthService for refreshing the Supabase session
    /// after a successful biometric unlock. Injected by the caller (e.g. AppViewModel).
    var authService: AuthService?

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
    @discardableResult
    func authenticate() async throws -> Bool {
        let context = LAContext()
        context.localizedCancelTitle = "Cancel"

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
                // Refresh the Supabase session after biometric success to ensure
                // the backend token is still valid. This prevents a stale JWT from
                // causing silent 401s on the next API call.
                // TODO: Refresh Supabase session after biometric success
                // Once AuthService is injected, uncomment the following:
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
            throw error
        } catch let error as LAError {
            throw mapLAError(error)
        } catch {
            throw BiometricError.unknown(error.localizedDescription)
        }
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
            return "Biometric authentication is locked. Please use your device passcode to unlock."
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
