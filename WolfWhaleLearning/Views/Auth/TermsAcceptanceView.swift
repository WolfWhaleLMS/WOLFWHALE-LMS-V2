import SwiftUI

struct TermsAcceptanceView: View {
    @Binding var acceptedTerms: Bool
    @Binding var acceptedPrivacy: Bool

    @State private var showTermsSheet = false
    @State private var showPrivacySheet = false
    @State private var hapticTrigger = false

    private var bothAccepted: Bool {
        acceptedTerms && acceptedPrivacy
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            headerSection

            termsCheckbox

            privacyCheckbox

            disclaimerText
        }
        .padding(.horizontal, 24)
        .sheet(isPresented: $showTermsSheet) {
            TermsOfServiceView()
        }
        .sheet(isPresented: $showPrivacySheet) {
            PrivacyPolicyView()
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.seal.fill")
                .font(.title3)
                .foregroundStyle(
                    Theme.brandGradient
                )

            Text("Legal Agreements")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
        }
    }

    // MARK: - Terms Checkbox

    private var termsCheckbox: some View {
        HStack(alignment: .top, spacing: 14) {
            Button {
                hapticTrigger.toggle()
                acceptedTerms.toggle()
            } label: {
                Image(systemName: acceptedTerms ? "checkmark.square.fill" : "square")
                    .font(.title3)
                    .foregroundStyle(acceptedTerms ? Color.purple : Color.gray.opacity(0.5))
            }
            .buttonStyle(.plain)
            .sensoryFeedback(.selection, trigger: hapticTrigger)
            .accessibilityLabel(acceptedTerms ? "Terms of Service accepted" : "Terms of Service not accepted")
            .accessibilityHint("Double tap to toggle acceptance of Terms of Service")

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 0) {
                    Text("I agree to the ")
                        .font(.subheadline)
                        .foregroundStyle(.primary)

                    Button {
                        showTermsSheet = true
                    } label: {
                        Text("Terms of Service")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.purple)
                            .underline()
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("View Terms of Service")
                    .accessibilityHint("Double tap to read the full Terms of Service")
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            acceptedTerms
                ? Color.purple.opacity(0.06)
                : Color.clear,
            in: .rect(cornerRadius: 12)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(
                    acceptedTerms
                        ? Color.purple.opacity(0.3)
                        : Color.gray.opacity(0.2),
                    lineWidth: 1
                )
        )
    }

    // MARK: - Privacy Checkbox

    private var privacyCheckbox: some View {
        HStack(alignment: .top, spacing: 14) {
            Button {
                hapticTrigger.toggle()
                acceptedPrivacy.toggle()
            } label: {
                Image(systemName: acceptedPrivacy ? "checkmark.square.fill" : "square")
                    .font(.title3)
                    .foregroundStyle(acceptedPrivacy ? Color.purple : Color.gray.opacity(0.5))
            }
            .buttonStyle(.plain)
            .sensoryFeedback(.selection, trigger: hapticTrigger)
            .accessibilityLabel(acceptedPrivacy ? "Privacy Policy accepted" : "Privacy Policy not accepted")
            .accessibilityHint("Double tap to toggle acceptance of Privacy Policy")

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 0) {
                    Text("I agree to the ")
                        .font(.subheadline)
                        .foregroundStyle(.primary)

                    Button {
                        showPrivacySheet = true
                    } label: {
                        Text("Privacy Policy")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.purple)
                            .underline()
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("View Privacy Policy")
                    .accessibilityHint("Double tap to read the full Privacy Policy")
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            acceptedPrivacy
                ? Color.purple.opacity(0.06)
                : Color.clear,
            in: .rect(cornerRadius: 12)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(
                    acceptedPrivacy
                        ? Color.purple.opacity(0.3)
                        : Color.gray.opacity(0.2),
                    lineWidth: 1
                )
        )
    }

    // MARK: - Disclaimer

    private var disclaimerText: some View {
        HStack(spacing: 8) {
            Image(systemName: "info.circle")
                .font(.caption)
                .foregroundStyle(.tertiary)

            Text("By creating an account, you agree to our terms and acknowledge that you have read our privacy policy.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineSpacing(2)
        }
        .padding(.horizontal, 4)
    }
}

#Preview {
    @Previewable @State var terms = false
    @Previewable @State var privacy = false

    VStack {
        TermsAcceptanceView(
            acceptedTerms: $terms,
            acceptedPrivacy: $privacy
        )

        Spacer()

        Text("Terms: \(terms ? "Yes" : "No") | Privacy: \(privacy ? "Yes" : "No")")
            .font(.caption.monospaced())
            .foregroundStyle(.secondary)
    }
    .padding(.top, 40)
    .background(Color(.systemGroupedBackground))
}
