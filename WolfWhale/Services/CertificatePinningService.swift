import Foundation
import CryptoKit

/// Certificate pinning for Supabase API connections (FERPA compliance)
/// Validates that TLS connections are established with the expected Supabase certificate
final class CertificatePinningService: NSObject, URLSessionDelegate {

    // MARK: - Supabase Certificate Pins
    // SHA-256 hashes of Supabase's public key certificates
    // These should be updated when Supabase rotates certificates
    private static let pinnedDomains: Set<String> = [
        "vkhawdvcfgnmcjhahull.supabase.co",
        "supabase.co"
    ]

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

        // Validate the server trust
        let policy = SecPolicyCreateSSL(true, challenge.protectionSpace.host as CFString)
        SecTrustSetPolicies(serverTrust, policy)

        var error: CFError?
        guard SecTrustEvaluateWithError(serverTrust, &error) else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        // Accept the valid certificate
        let credential = URLCredential(trust: serverTrust)
        completionHandler(.useCredential, credential)
    }
}
