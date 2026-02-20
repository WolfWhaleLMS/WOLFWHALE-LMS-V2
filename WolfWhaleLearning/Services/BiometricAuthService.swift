import LocalAuthentication

@Observable
@MainActor
class BiometricAuthService {
    var isBiometricAvailable: Bool = false
    var biometricType: LABiometryType = .none
    var isUnlocked: Bool = false

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
    @discardableResult
    func authenticate() async throws -> Bool {
        let context = LAContext()
        context.localizedCancelTitle = "Cancel"

        var evalError: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &evalError) else {
            throw mapLAError(evalError)
        }

        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: "Unlock WolfWhale"
            )
            if success {
                isUnlocked = true
            }
            return success
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
        case .unknown(let message):
            return message
        }
    }
}
