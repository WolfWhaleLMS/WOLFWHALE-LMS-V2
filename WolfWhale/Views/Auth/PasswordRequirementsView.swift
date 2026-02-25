import SwiftUI

struct PasswordRequirementsView: View {
    let password: String
    let confirmPassword: String?

    var meetsMinLength: Bool { password.count >= 8 }
    var hasUppercase: Bool { password.range(of: "[A-Z]", options: .regularExpression) != nil }
    var hasLowercase: Bool { password.range(of: "[a-z]", options: .regularExpression) != nil }
    var hasNumber: Bool { password.range(of: "[0-9]", options: .regularExpression) != nil }

    var passwordsMatch: Bool {
        guard let confirmPassword, !confirmPassword.isEmpty else { return false }
        return password == confirmPassword
    }

    var allMet: Bool {
        let baseMet = meetsMinLength && hasUppercase && hasLowercase && hasNumber
        if confirmPassword != nil {
            return baseMet && passwordsMatch
        }
        return baseMet
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            requirementRow(
                met: meetsMinLength,
                text: "At least 8 characters"
            )
            requirementRow(
                met: hasUppercase,
                text: "Contains uppercase letter"
            )
            requirementRow(
                met: hasLowercase,
                text: "Contains lowercase letter"
            )
            requirementRow(
                met: hasNumber,
                text: "Contains number"
            )
            if confirmPassword != nil {
                requirementRow(
                    met: passwordsMatch,
                    text: "Passwords match"
                )
            }
        }
        .padding(12)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 12))
        .animation(.smooth, value: password)
        .animation(.smooth, value: confirmPassword)
    }

    private func requirementRow(met: Bool, text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: met ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.caption)
                .foregroundStyle(met ? .green : .red.opacity(0.7))
                .contentTransition(.symbolEffect(.replace))

            Text(text)
                .font(.caption)
                .foregroundStyle(met ? .primary : .secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(text): \(met ? "met" : "not met")")
    }
}
