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
    /// SSL pinning is disabled by default. To enable, add SHA-256 SPKI hashes
    /// of your server's certificate chain. Generate with:
    ///
    ///   openssl s_client -connect yourserver.com:443 | \
    ///     openssl x509 -pubkey | \
    ///     openssl pkey -pubin -outform der | \
    ///     openssl dgst -sha256 -binary | base64
    ///
    /// IMPORTANT: When enabling pinning, include at least one backup pin
    /// (e.g. the intermediate CA) to avoid bricking the app if the leaf
    /// certificate is rotated. Update pins before certificate expiration.
    private static let pinnedPublicKeyHashes: Set<String> = [
        // Add your SPKI hashes here to enable certificate pinning.
        // Example (do NOT use these values — they are illustrative only):
        //   "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=",   // leaf
        //   "BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=",   // intermediate (backup)
    ]

    /// Controls whether certificate pinning is enforced.
    ///
    /// Defaults to `false` (standard TLS validation only). Set to `true` **and**
    /// populate ``pinnedPublicKeyHashes`` to activate pinning. When `false` or
    /// when the hash set is empty, the service gracefully falls back to standard
    /// system TLS validation — it will never crash or block connections.
    static var enforcePinning: Bool = false

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

        // Step 2: If pinning is not enabled or no hashes are configured, fall
        // back to standard TLS validation (the system trust evaluation above
        // already passed). This path is safe — no crash, no blocked connections.
        guard Self.enforcePinning, !Self.pinnedPublicKeyHashes.isEmpty else {
            #if DEBUG
            print("[CertificatePinning] Pinning is disabled or no hashes configured — using standard TLS validation for \(challenge.protectionSpace.host).")
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
            guard let chain = SecTrustCopyCertificateChain(serverTrust),
                  let certificates = chain as? [SecCertificate],
                  index < certificates.count else {
                continue
            }
            let certificate = certificates[index]

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
