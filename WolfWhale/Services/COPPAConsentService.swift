import Foundation
import Supabase

// MARK: - Consent Record DTO

/// Maps to the `consent_records` table in Supabase.
nonisolated struct ConsentRecordDTO: Codable, Sendable {
    let id: UUID?
    let studentId: UUID
    let parentId: UUID?
    let tenantId: UUID?
    let consentType: String?
    let status: String?
    let grantedAt: String?
    let expiresAt: Date?
    let revokedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case studentId = "student_id"
        case parentId = "parent_id"
        case tenantId = "tenant_id"
        case consentType = "consent_type"
        case status
        case grantedAt = "granted_at"
        case expiresAt = "expires_at"
        case revokedAt = "revoked_at"
    }
}

// MARK: - COPPA Consent Service

/// COPPA compliance service for verifiable parental consent.
/// Required for users under 13 in K-12 educational settings.
@MainActor @Observable
final class COPPAConsentService {

    // MARK: - Consent Status
    var hasVerifiedParentalConsent: Bool = false
    var consentExpirationDate: Date?

    // MARK: - Age Gate
    /// Determines whether a user requires parental consent based on their date of birth.
    static func requiresParentalConsent(dateOfBirth: Date) -> Bool {
        let age = Calendar.current.dateComponents([.year], from: dateOfBirth, to: Date()).year ?? 0
        return age < 13
    }

    // MARK: - Consent Verification
    /// Verifies that parental consent has been recorded for a student.
    func verifyConsent(studentId: UUID, tenantId: UUID) async throws -> Bool {
        let response: [ConsentRecordDTO] = try await supabaseClient
            .from("consent_records")
            .select()
            .eq("student_id", value: studentId.uuidString)
            .eq("tenant_id", value: tenantId.uuidString)
            .eq("consent_type", value: "coppa_parental")
            .eq("status", value: "granted")
            .execute()
            .value

        guard let consent = response.first else {
            hasVerifiedParentalConsent = false
            return false
        }

        // Check if consent is still valid (annual renewal required by COPPA)
        if let expiresAt = consent.expiresAt, expiresAt < Date() {
            hasVerifiedParentalConsent = false
            return false
        }

        hasVerifiedParentalConsent = true
        consentExpirationDate = consent.expiresAt
        return true
    }

    // MARK: - Data Minimization
    /// Returns only the minimum required fields for a student under 13.
    static let minimizedStudentFields: Set<String> = [
        "id", "full_name", "tenant_id", "role"
    ]

    /// Fields that should NOT be collected for COPPA-protected students.
    static let restrictedFields: Set<String> = [
        "email", "phone", "address", "photo_url", "date_of_birth", "social_media"
    ]
}
