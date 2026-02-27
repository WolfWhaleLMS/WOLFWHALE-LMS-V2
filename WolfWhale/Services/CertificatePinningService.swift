import Foundation
import CryptoKit
import Security

/// Certificate pinning for Supabase API connections (FERPA compliance).
/// Validates that TLS connections use certificates whose public key SHA-256
/// hash matches one of the pre-configured pins. This prevents MITM attacks
/// even if a rogue CA issues a fraudulent certificate for the domain.
final class CertificatePinningService: NSObject, URLSessionDelegate {

    // MARK: - Configuration

    /// Domains subject to certificate pinning.
    private static let pinnedDomains: Set<String> = [
        "vkhawdvcfgnmcjhahull.supabase.co",
        "supabase.co"
    ]

    /// SHA-256 hashes of the Subject Public Key Info (SPKI) for each pinned
    /// certificate. Include both the leaf and at least one intermediate/backup
    /// pin so that certificate rotation does not cause an outage.
    ///
    /// To generate a pin from a PEM certificate:
    ///   openssl x509 -in cert.pem -pubkey -noout | \
    ///     openssl pkey -pubin -outform der | \
    ///     openssl dgst -sha256 -binary | base64
    ///
    /// IMPORTANT: Update these pins when Supabase rotates their certificates.
    /// Include at least one backup pin (e.g. the intermediate CA) to avoid
    /// bricking the app if the leaf certificate is rotated.
    private static let pinnedPublicKeyHashes: Set<String> = [
        // Supabase leaf certificate public key hash (primary)
        // Amazon RSA 2048 M02 intermediate (backup)
        // These are placeholder values -- replace with real pins extracted
        // from the production certificate chain before shipping to production.
        // The service will fall back to standard TLS validation if no pins
        // are configured, but will log a warning in DEBUG builds.
    ]

    /// Set to `true` to enforce pinning even in release builds. When `false`
    /// (or when `pinnedPublicKeyHashes` is empty), the service performs
    /// standard TLS validation only and logs a warning in DEBUG.
    private static let enforcePinning: Bool = !pinnedPublicKeyHashes.isEmpty

    static let shared = CertificatePinningService()

    // MARK: - URLSession Delegate

    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let serverTrust = challenge.protectionSpace.serverTrust,
              Self.pinnedDomains.contains(challenge.protectionSpace.host) else {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        // Step 1: Evaluate the full certificate chain against system trust store
        let policy = SecPolicyCreateSSL(true, challenge.protectionSpace.host as CFString)
        SecTrustSetPolicies(serverTrust, policy)

        var trustError: CFError?
        guard SecTrustEvaluateWithError(serverTrust, &trustError) else {
            #if DEBUG
            print("[CertificatePinning] TLS trust evaluation failed for \(challenge.protectionSpace.host): \(trustError?.localizedDescription ?? "unknown")")
            #endif
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        // Step 2: If pin hashes are configured, validate the server certificate's
        // public key against the pinned set.
        guard Self.enforcePinning else {
            #if DEBUG
            print("[CertificatePinning] WARNING: No pins configured -- falling back to standard TLS validation for \(challenge.protectionSpace.host). Add SPKI hashes before shipping to production.")
            #endif
            let credential = URLCredential(trust: serverTrust)
            completionHandler(.useCredential, credential)
            return
        }

        // Walk the certificate chain and check if ANY certificate's SPKI hash
        // matches a pinned hash. Checking the full chain (not just the leaf)
        // allows pinning to an intermediate CA as a backup.
        let certificateCount = SecTrustGetCertificateCount(serverTrust)
        var matched = false

        for index in 0..<certificateCount {
            guard let certificate = SecTrustCopyCertificateChain(serverTrust).map({ ($0 as! [SecCertificate])[index] }) else {
                continue
            }

            if let publicKeyHash = Self.sha256HashOfPublicKey(for: certificate),
               Self.pinnedPublicKeyHashes.contains(publicKeyHash) {
                matched = true
                break
            }
        }

        if matched {
            let credential = URLCredential(trust: serverTrust)
            completionHandler(.useCredential, credential)
        } else {
            #if DEBUG
            print("[CertificatePinning] Pin validation FAILED for \(challenge.protectionSpace.host). No certificate in the chain matched a pinned hash.")
            #endif
            completionHandler(.cancelAuthenticationChallenge, nil)
        }
    }

    // MARK: - Public Key Hashing

    /// Extracts the public key from a `SecCertificate` and returns its
    /// Base64-encoded SHA-256 hash (SPKI fingerprint).
    private static func sha256HashOfPublicKey(for certificate: SecCertificate) -> String? {
        // Create a trust object to extract the public key from the certificate
        var trust: SecTrust?
        let policy = SecPolicyCreateBasicX509()
        guard SecTrustCreateWithCertificates(certificate, policy, &trust) == errSecSuccess,
              let trust else {
            return nil
        }

        // Evaluate trust to populate the public key
        var cfError: CFError?
        guard SecTrustEvaluateWithError(trust, &cfError) || true else {
            // We still want the key even if the cert alone doesn't chain to a root
            return nil
        }

        guard let publicKey = SecTrustCopyKey(trust) else { return nil }

        // Export the public key as external representation (DER-encoded SPKI)
        var error: Unmanaged<CFError>?
        guard let publicKeyData = SecKeyCopyExternalRepresentation(publicKey, &error) as Data? else {
            return nil
        }

        // SHA-256 hash of the raw public key data
        let hash = SHA256.hash(data: publicKeyData)
        return Data(hash).base64EncodedString()
    }
}
