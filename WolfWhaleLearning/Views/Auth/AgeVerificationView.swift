import SwiftUI

struct AgeVerificationView: View {
    @Binding var dateOfBirth: Date
    @Binding var parentEmail: String
    @Binding var isUnder13: Bool
    var onContinue: () -> Void

    @State private var hasSelectedDate = false
    @State private var parentalConsentChecked = false
    @State private var hapticTrigger = false
    @State private var showDatePicker = false

    // Minimum date: 5 years old (school LMS) — no one younger than 5
    private var minimumDate: Date {
        Calendar.current.date(byAdding: .year, value: -100, to: Date()) ?? Date()
    }

    private var maximumDate: Date {
        Calendar.current.date(byAdding: .year, value: -5, to: Date()) ?? Date()
    }

    private var defaultDate: Date {
        Calendar.current.date(byAdding: .year, value: -13, to: Date()) ?? Date()
    }

    private var calculatedAge: Int {
        Calendar.current.dateComponents([.year], from: dateOfBirth, to: Date()).year ?? 0
    }

    private var isTooYoung: Bool {
        calculatedAge < 5
    }

    private var canContinue: Bool {
        guard hasSelectedDate, !isTooYoung else { return false }
        if isUnder13 {
            return isValidParentEmail && parentalConsentChecked
        }
        return true
    }

    private var isValidParentEmail: Bool {
        let pattern = #"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        return parentEmail.range(of: pattern, options: .regularExpression) != nil
    }

    var body: some View {
        VStack(spacing: 0) {
            headerSection

            Spacer().frame(height: 28)

            datePickerSection

            if hasSelectedDate {
                Spacer().frame(height: 20)

                ageStatusSection
                    .transition(.opacity.combined(with: .move(edge: .top)))

                if isUnder13 && !isTooYoung {
                    Spacer().frame(height: 20)

                    parentConsentSection
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }

            Spacer().frame(height: 32)

            continueButton
        }
        .padding(.horizontal, 24)
        .animation(.smooth, value: hasSelectedDate)
        .animation(.smooth, value: isUnder13)
        .onChange(of: dateOfBirth) { _, _ in
            if hasSelectedDate {
                isUnder13 = AppStoreCompliance.isUnder13(dateOfBirth: dateOfBirth)
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.purple.opacity(0.15), Color.cyan.opacity(0.15)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 72, height: 72)

                Image(systemName: "person.badge.clock.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.purple, .cyan],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            Text("Age Verification")
                .font(.system(size: 24, weight: .black, design: .serif))
                .tracking(1)
                .foregroundStyle(.primary)

            Text("We need your date of birth to comply with child safety regulations (COPPA).")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)
        }
    }

    // MARK: - Date Picker

    private var datePickerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Date of Birth")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)

            DatePicker(
                "Date of Birth",
                selection: $dateOfBirth,
                in: minimumDate...maximumDate,
                displayedComponents: .date
            )
            .datePickerStyle(.compact)
            .labelsHidden()
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                #if canImport(UIKit)
                Color(UIColor.systemBackground)
                #else
                Color.white
                #endif
                , in: .rect(cornerRadius: 12)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.purple.opacity(0.4), lineWidth: 1)
            )
            .onChange(of: dateOfBirth) { _, _ in
                if !hasSelectedDate {
                    hasSelectedDate = true
                }
                isUnder13 = AppStoreCompliance.isUnder13(dateOfBirth: dateOfBirth)
            }
            .accessibilityLabel("Select your date of birth")
        }
        .onAppear {
            dateOfBirth = defaultDate
        }
    }

    // MARK: - Age Status

    private var ageStatusSection: some View {
        HStack(spacing: 12) {
            Image(systemName: statusIcon)
                .font(.title3)
                .foregroundStyle(statusColor)

            VStack(alignment: .leading, spacing: 2) {
                Text(statusTitle)
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)

                Text(statusMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineSpacing(2)
            }

            Spacer()
        }
        .padding(14)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 12))
    }

    private var statusIcon: String {
        if isTooYoung {
            return "exclamationmark.triangle.fill"
        } else if isUnder13 {
            return "figure.and.child.holdinghands"
        } else {
            return "checkmark.circle.fill"
        }
    }

    private var statusColor: Color {
        if isTooYoung {
            return .red
        } else if isUnder13 {
            return .orange
        } else {
            return .green
        }
    }

    private var statusTitle: String {
        if isTooYoung {
            return "Age Requirement Not Met"
        } else if isUnder13 {
            return "Parental Consent Required"
        } else {
            return "Age Verified"
        }
    }

    private var statusMessage: String {
        if isTooYoung {
            return "You must be at least 5 years old to use this platform."
        } else if isUnder13 {
            return "A parent or guardian must consent for users under 13 (COPPA). Please provide a parent or guardian email below."
        } else {
            return "You are \(calculatedAge) years old. No additional verification is needed."
        }
    }

    // MARK: - Parent Consent

    private var parentConsentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Parent / Guardian Information")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                Image(systemName: "envelope.fill")
                    .foregroundStyle(.tertiary)
                    .frame(width: 20)
                    .accessibilityHidden(true)
                TextField("Parent or guardian email", text: $parentEmail)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .accessibilityLabel("Parent or guardian email address")
                    .accessibilityHint("Enter the email address of a parent or guardian for consent")
            }
            .padding(14)
            .background(
                #if canImport(UIKit)
                Color(UIColor.systemBackground)
                #else
                Color.white
                #endif
                , in: .rect(cornerRadius: 12)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(
                        !parentEmail.isEmpty && !isValidParentEmail
                            ? Color.red.opacity(0.5)
                            : Color.gray.opacity(0.3),
                        lineWidth: 1
                    )
            )

            if !parentEmail.isEmpty && !isValidParentEmail {
                Text("Enter a valid email address")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.leading, 4)
            }

            Toggle(isOn: $parentalConsentChecked) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Parental Consent")
                        .font(.subheadline.bold())
                    Text("I confirm that my parent or guardian has consented to my use of this educational platform and acknowledges the Privacy Policy.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineSpacing(2)
                }
            }
            .tint(.purple)
            .sensoryFeedback(.selection, trigger: parentalConsentChecked)
            .accessibilityLabel("Parental consent acknowledgment")
            .accessibilityHint("Toggle to confirm parental consent has been provided")
        }
        .padding(16)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 14))
    }

    // MARK: - Continue Button

    private var continueButton: some View {
        Button {
            hapticTrigger.toggle()
            onContinue()
        } label: {
            HStack(spacing: 8) {
                Text("Continue")
                    .font(.headline)
                Image(systemName: "arrow.right")
                    .font(.subheadline.bold())
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
        }
        .buttonStyle(.borderedProminent)
        .tint(Color.purple)
        .clipShape(.rect(cornerRadius: 12))
        .disabled(!canContinue)
        .sensoryFeedback(.impact(weight: .medium), trigger: hapticTrigger)
        .accessibilityLabel("Continue to next step")
        .accessibilityHint(canContinue ? "Double tap to proceed" : "Complete all required fields to continue")
    }
}

#Preview {
    @Previewable @State var dob = Date()
    @Previewable @State var parentEmail = ""
    @Previewable @State var isUnder13 = false

    ScrollView {
        AgeVerificationView(
            dateOfBirth: $dob,
            parentEmail: $parentEmail,
            isUnder13: $isUnder13,
            onContinue: {}
        )
    }
    .background(Color(.systemGroupedBackground))
}
