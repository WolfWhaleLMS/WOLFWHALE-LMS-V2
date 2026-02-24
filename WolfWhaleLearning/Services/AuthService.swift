import Foundation
import Supabase

@MainActor @Observable
final class AuthService {
    var error: String?
    var isLoading = false
    var requiresEmailVerification = false
    var passwordResetSent = false

    // MARK: - Password Reset

    /// Sends a password reset email to the given address.
    /// Returns `true` on success, sets `error` on failure.
    func sendPasswordReset(email: String) async -> Bool {
        isLoading = true
        error = nil
        passwordResetSent = false
        defer { isLoading = false }

        do {
            try await supabaseClient.auth.resetPasswordForEmail(email)
            passwordResetSent = true
            return true
        } catch {
            self.error = mapError(error)
            return false
        }
    }

    // MARK: - Handle Reset Callback (deep link from email)

    /// Parses the URL for Supabase auth callback tokens.
    /// Returns `true` if the URL is a recognized password reset callback.
    func handlePasswordResetCallback(url: URL) -> Bool {
        // Supabase sends callbacks like:
        //   yourapp://callback#access_token=...&refresh_token=...&type=recovery
        // Or as a query parameter URL:
        //   yourapp://callback?type=recovery&access_token=...
        let urlString = url.absoluteString

        // Check fragment-based tokens (hash-style)
        if let fragment = url.fragment, fragment.contains("type=recovery") {
            return true
        }

        // Check query-based tokens
        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let typeItem = components.queryItems?.first(where: { $0.name == "type" }),
           typeItem.value == "recovery" {
            return true
        }

        // Also check if the whole string contains the recovery marker
        if urlString.contains("type=recovery") {
            return true
        }

        return false
    }

    // MARK: - Set New Password (after reset callback)

    /// Updates the user's password after they have clicked the reset link in their email.
    /// Requires a valid session from the callback token.
    func updatePassword(newPassword: String) async -> Bool {
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            try await supabaseClient.auth.update(user: .init(password: newPassword))
            return true
        } catch {
            self.error = mapPasswordError(error)
            return false
        }
    }

    // MARK: - Change Password (from settings, requires current password)

    /// Verifies the current password by re-authenticating, then updates to the new password.
    func changePassword(currentPassword: String, newPassword: String) async -> Bool {
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            // Re-authenticate with the current password to verify it
            let session = try await supabaseClient.auth.session
            guard let email = session.user.email else {
                self.error = "Unable to determine your email address."
                return false
            }

            // Verify current password by signing in again
            _ = try await supabaseClient.auth.signIn(email: email, password: currentPassword)

            // Now update to the new password
            try await supabaseClient.auth.update(user: .init(password: newPassword))
            return true
        } catch {
            let message = error.localizedDescription.lowercased()
            if message.contains("invalid") || message.contains("credentials") {
                self.error = "Current password is incorrect."
            } else {
                self.error = mapPasswordError(error)
            }
            return false
        }
    }

    // MARK: - Session Management

    /// Attempts to refresh the current Supabase session.
    /// Returns `false` if refresh fails (token expired, need to re-login).
    func refreshSession() async -> Bool {
        do {
            _ = try await supabaseClient.auth.refreshSession()
            return true
        } catch {
            #if DEBUG
            print("[AuthService] Session refresh failed: \(error)")
            #endif
            return false
        }
    }

    /// Checks if there is a valid session.
    /// If expired, tries `refreshSession()`.
    /// If refresh fails, returns `false` (redirect to login).
    func checkSession() async -> Bool {
        do {
            _ = try await supabaseClient.auth.session
            return true
        } catch {
            // Session might be expired, try to refresh
            return await refreshSession()
        }
    }

    // MARK: - Account Deletion (REQUIRED BY APP STORE)

    /// Deletes all user data from Supabase tables, deletes the auth account, and signs out.
    func deleteAccount(userId: UUID) async -> Bool {
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            // Use the existing RPC function to delete all user data
            try await supabaseClient
                .rpc("delete_user_complete", params: ["target_user_id": userId.uuidString])
                .execute()

            // Sign out after deletion
            do {
                try await supabaseClient.auth.signOut()
            } catch {
                #if DEBUG
                print("[AuthService] Sign out after deletion error: \(error)")
                #endif
                // Still return true — account data was deleted successfully
            }
            return true
        } catch {
            // If the RPC fails (e.g. function not available), attempt a best-effort cleanup
            #if DEBUG
            print("[AuthService] delete_user_complete RPC failed: \(error)")
            #endif

            // Best-effort: delete profile and memberships directly
            do {
                // Delete tenant memberships
                try await supabaseClient
                    .from("tenant_memberships")
                    .delete()
                    .eq("user_id", value: userId.uuidString)
                    .execute()

                // Delete student_xp
                try await supabaseClient
                    .from("student_xp")
                    .delete()
                    .eq("student_id", value: userId.uuidString)
                    .execute()

                // Delete submissions
                try await supabaseClient
                    .from("submissions")
                    .delete()
                    .eq("student_id", value: userId.uuidString)
                    .execute()

                // Delete grades
                try await supabaseClient
                    .from("grades")
                    .delete()
                    .eq("student_id", value: userId.uuidString)
                    .execute()

                // Delete conversation memberships
                try await supabaseClient
                    .from("conversation_members")
                    .delete()
                    .eq("user_id", value: userId.uuidString)
                    .execute()

                // Delete messages
                try await supabaseClient
                    .from("messages")
                    .delete()
                    .eq("sender_id", value: userId.uuidString)
                    .execute()

                // Delete attendance records
                try await supabaseClient
                    .from("attendance_records")
                    .delete()
                    .eq("student_id", value: userId.uuidString)
                    .execute()

                // Delete lesson completions
                try await supabaseClient
                    .from("lesson_completions")
                    .delete()
                    .eq("student_id", value: userId.uuidString)
                    .execute()

                // Delete student achievements
                try await supabaseClient
                    .from("student_achievements")
                    .delete()
                    .eq("student_id", value: userId.uuidString)
                    .execute()

                // Delete profile
                try await supabaseClient
                    .from("profiles")
                    .delete()
                    .eq("id", value: userId.uuidString)
                    .execute()

                // Sign out
                do {
                    try await supabaseClient.auth.signOut()
                } catch {
                    #if DEBUG
                    print("[AuthService] Sign out after cleanup error: \(error)")
                    #endif
                }
                return true
            } catch {
                self.error = "Failed to delete account. Please contact your administrator."
                // Still sign out even if cleanup partially failed
                do {
                    try await supabaseClient.auth.signOut()
                } catch {
                    #if DEBUG
                    print("[AuthService] Sign out after failed cleanup error: \(error)")
                    #endif
                }
                return false
            }
        }
    }

    // MARK: - Email Verification

    /// Checks if the current user's email is verified.
    func checkEmailVerification() async -> Bool {
        do {
            let session = try await supabaseClient.auth.session
            let user = session.user
            // Supabase marks email_confirmed_at when verified
            if user.emailConfirmedAt != nil {
                requiresEmailVerification = false
                return true
            }
            requiresEmailVerification = true
            return false
        } catch {
            #if DEBUG
            print("[AuthService] checkEmailVerification failed: \(error)")
            #endif
            return false
        }
    }

    /// Resends the verification email to the given address.
    func resendVerificationEmail(email: String) async -> Bool {
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            try await supabaseClient.auth.resend(email: email, type: .signup)
            return true
        } catch {
            self.error = mapError(error)
            return false
        }
    }

    // MARK: - Error Mapping

    private func mapError(_ error: Error) -> String {
        let message = error.localizedDescription.lowercased()
        if message.contains("rate") || message.contains("limit") {
            return "Too many requests. Please wait a moment and try again."
        } else if message.contains("network") || message.contains("connection") || message.contains("not connected") {
            return "Network error. Please check your connection."
        } else if message.contains("invalid") && message.contains("email") {
            return "Please enter a valid email address."
        }
        return "An error occurred. Please try again."
    }

    private func mapPasswordError(_ error: Error) -> String {
        let message = error.localizedDescription.lowercased()
        if message.contains("weak") || message.contains("short") {
            return "Password is too weak. Please choose a stronger password."
        } else if message.contains("same") || message.contains("reuse") {
            return "New password cannot be the same as your current password."
        } else if message.contains("session") || message.contains("auth") || message.contains("expired") {
            return "Session expired. Please sign in again."
        } else if message.contains("network") || message.contains("connection") || message.contains("not connected") {
            return "Network error. Please check your connection."
        }
        return "Failed to update password. Please try again."
    }
}
