import SwiftUI

struct TermsOfServiceView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var hapticTrigger = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    headerSection
                    accountResponsibilitiesSection
                    acceptableUseSection
                    studentDataPrivacySection
                    contentOwnershipSection
                    liabilityLimitationsSection
                    terminationSection
                    changesToTermsSection
                    contactSection
                }
                .padding(.horizontal)
                .padding(.bottom, 40)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Terms of Service")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        hapticTrigger.toggle()
                        dismiss()
                    }
                    .hapticFeedback(.impact(weight: .light), trigger: hapticTrigger)
                }
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "doc.text.fill")
                    .font(.title2)
                    .foregroundStyle(Theme.brandGradient)
                Text("WolfWhale LMS")
                    .font(.title2.bold())
            }

            Text("Last updated: February 20, 2026")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text("Please read these Terms of Service carefully before using the WolfWhale Learning Management System. By accessing or using our platform, you agree to be bound by these terms.")
                .font(.body)
                .foregroundStyle(.secondary)
                .lineSpacing(4)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

    // MARK: - 1. Account Responsibilities

    private var accountResponsibilitiesSection: some View {
        sectionCard(
            number: "1",
            title: "Account Responsibilities",
            icon: "person.badge.key.fill",
            color: .indigo
        ) {
            VStack(alignment: .leading, spacing: 12) {
                legalParagraph("By creating an account on WolfWhale LMS, you agree to the following responsibilities:")

                bulletPoint("You must provide accurate, current, and complete information during registration and keep your account information up to date.")
                bulletPoint("You are responsible for maintaining the confidentiality of your login credentials, including your password, and for all activities that occur under your account.")
                bulletPoint("Student accounts may only be created by authorized school administrators or through an approved enrollment process. Students under the age of 13 must have parental or guardian consent.")
                bulletPoint("You must notify a school administrator or WolfWhale support immediately if you become aware of any unauthorized use of your account or any other breach of security.")
                bulletPoint("Account sharing is prohibited. Each user must have their own individual account to access the platform.")
                bulletPoint("WolfWhale reserves the right to suspend or terminate accounts that violate these terms or that remain inactive for an extended period, in accordance with institutional policies.")
            }
        }
    }

    // MARK: - 2. Acceptable Use Policy

    private var acceptableUseSection: some View {
        sectionCard(
            number: "2",
            title: "Acceptable Use Policy",
            icon: "checkmark.shield.fill",
            color: .green
        ) {
            VStack(alignment: .leading, spacing: 12) {
                legalParagraph("WolfWhale LMS is provided for educational purposes. When using the platform, you agree to the following:")

                subsectionTitle("Permitted Uses")
                bulletPoint("Accessing course materials, submitting assignments, participating in discussions, and engaging with educational content assigned to you.")
                bulletPoint("Communicating with instructors, classmates, and school staff through the platform's built-in messaging features for educational purposes.")
                bulletPoint("Using gamification features (XP, streaks, leaderboards) as intended to support your learning journey.")

                subsectionTitle("Prohibited Conduct")
                bulletPoint("Using the platform to harass, bully, threaten, or intimidate any user.")
                bulletPoint("Uploading, sharing, or distributing obscene, offensive, or inappropriate content.")
                bulletPoint("Attempting to gain unauthorized access to other users' accounts, data, or administrative functions.")
                bulletPoint("Using automated tools, bots, or scripts to interact with the platform without express permission.")
                bulletPoint("Engaging in academic dishonesty, including plagiarism, sharing answers, or misrepresenting another's work as your own.")
                bulletPoint("Interfering with or disrupting the platform's services, servers, or networks.")
                bulletPoint("Using the platform for any commercial purpose unrelated to the educational institution's activities.")

                legalParagraph("Violations of this policy may result in disciplinary action, including account suspension or termination, and may be reported to school administration and, where applicable, law enforcement.")
            }
        }
    }

    // MARK: - 3. Student Data Privacy (FERPA)

    private var studentDataPrivacySection: some View {
        sectionCard(
            number: "3",
            title: "Student Data Privacy (FERPA Compliance)",
            icon: "lock.shield.fill",
            color: .blue
        ) {
            VStack(alignment: .leading, spacing: 12) {
                legalParagraph("WolfWhale LMS is committed to protecting student data in compliance with the Family Educational Rights and Privacy Act (FERPA) and other applicable student privacy laws.")

                subsectionTitle("Educational Records")
                bulletPoint("Student educational records, including grades, assignments, attendance, and course progress, are maintained securely on the platform.")
                bulletPoint("Access to student educational records is restricted to authorized personnel, including the student, their parents or guardians (for eligible students), and school officials with a legitimate educational interest.")

                subsectionTitle("Institutional Control")
                bulletPoint("Educational institutions using WolfWhale LMS retain full ownership and control of all student education records stored on the platform.")
                bulletPoint("WolfWhale acts as a \"school official\" under FERPA, processing student data solely on behalf of and under the direction of the educational institution.")

                subsectionTitle("Data Access Rights")
                bulletPoint("Parents and eligible students have the right to inspect and review educational records maintained by the platform.")
                bulletPoint("Requests to amend educational records should be directed to the school administration, who will coordinate with WolfWhale as needed.")
                bulletPoint("Student data will not be disclosed to third parties without proper consent, except as permitted by FERPA (e.g., health or safety emergencies, judicial orders).")

                subsectionTitle("Data Security")
                bulletPoint("All student data is encrypted in transit and at rest using industry-standard encryption protocols.")
                bulletPoint("Access controls and audit logs are maintained to protect against unauthorized access to student records.")
            }
        }
    }

    // MARK: - 4. Content Ownership

    private var contentOwnershipSection: some View {
        sectionCard(
            number: "4",
            title: "Content Ownership",
            icon: "doc.on.doc.fill",
            color: .orange
        ) {
            VStack(alignment: .leading, spacing: 12) {
                subsectionTitle("Platform Content")
                bulletPoint("The WolfWhale LMS platform, including its design, software, features, and branding, is the intellectual property of WolfWhale and is protected by applicable copyright, trademark, and intellectual property laws.")
                bulletPoint("You may not copy, modify, distribute, or create derivative works based on the platform without express written permission.")

                subsectionTitle("Institution Content")
                bulletPoint("Educational content created by teachers and administrators (including course materials, quizzes, lessons, and announcements) remains the intellectual property of the respective creators and/or their educational institution.")
                bulletPoint("By uploading content to the platform, creators grant WolfWhale a limited license to host, display, and distribute the content solely for the purpose of operating the LMS.")

                subsectionTitle("Student Content")
                bulletPoint("Students retain ownership of original work they submit through the platform, including assignments, essays, and other creative works.")
                bulletPoint("By submitting work, students grant the educational institution and WolfWhale a limited license to store, display, and process the content as necessary for grading, academic records, and platform operation.")

                subsectionTitle("Feedback")
                bulletPoint("Any feedback, suggestions, or ideas you provide about the platform may be used by WolfWhale to improve the service without any obligation to you.")
            }
        }
    }

    // MARK: - 5. Liability Limitations

    private var liabilityLimitationsSection: some View {
        sectionCard(
            number: "5",
            title: "Limitation of Liability",
            icon: "exclamationmark.triangle.fill",
            color: .red
        ) {
            VStack(alignment: .leading, spacing: 12) {
                legalParagraph("To the maximum extent permitted by applicable law:")

                bulletPoint("WolfWhale LMS is provided on an \"as is\" and \"as available\" basis. We make no warranties, express or implied, regarding the platform's reliability, accuracy, availability, or fitness for a particular purpose.")
                bulletPoint("WolfWhale shall not be liable for any indirect, incidental, special, consequential, or punitive damages, including but not limited to loss of data, loss of grades or academic records, or interruption of educational services.")
                bulletPoint("Our total liability for any claim arising from or related to the use of the platform shall not exceed the amount paid by your educational institution for the use of WolfWhale LMS during the twelve (12) months preceding the claim.")
                bulletPoint("WolfWhale is not responsible for the accuracy of grades, feedback, or assessments entered by instructors or generated by the platform's tools.")
                bulletPoint("WolfWhale is not liable for any disputes between users, including but not limited to student-teacher, parent-teacher, or administrative disputes conducted through the platform.")

                legalParagraph("Some jurisdictions do not allow the exclusion of certain warranties or limitations of liability. In such cases, the above limitations shall apply to the fullest extent permitted by law.")
            }
        }
    }

    // MARK: - 6. Termination

    private var terminationSection: some View {
        sectionCard(
            number: "6",
            title: "Termination",
            icon: "xmark.circle.fill",
            color: .pink
        ) {
            VStack(alignment: .leading, spacing: 12) {
                bulletPoint("WolfWhale or your educational institution may suspend or terminate your access to the platform at any time for violations of these Terms or for any reason consistent with institutional policies.")
                bulletPoint("Upon termination, your right to use the platform ceases immediately. Data retention following termination will be handled in accordance with institutional data retention policies and applicable law.")
                bulletPoint("Students and parents may request export of their educational records prior to account termination by contacting their school administrator.")
            }
        }
    }

    // MARK: - 7. Changes to Terms

    private var changesToTermsSection: some View {
        sectionCard(
            number: "7",
            title: "Changes to These Terms",
            icon: "arrow.triangle.2.circlepath",
            color: .teal
        ) {
            VStack(alignment: .leading, spacing: 12) {
                legalParagraph("WolfWhale reserves the right to update or modify these Terms of Service at any time. When we make material changes, we will:")

                bulletPoint("Update the \"Last updated\" date at the top of this document.")
                bulletPoint("Notify users and institutional administrators through the platform's announcement system or via email.")
                bulletPoint("Provide a reasonable period for review before changes take effect, except where immediate changes are required by law or to protect the security of the platform.")

                legalParagraph("Your continued use of the platform after changes take effect constitutes acceptance of the revised terms.")
            }
        }
    }

    // MARK: - 8. Contact

    private var contactSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "envelope.fill")
                    .foregroundStyle(.purple)
                Text("Contact Us")
                    .font(.headline)
            }

            legalParagraph("If you have questions or concerns about these Terms of Service, please contact your school administrator or reach out to us at:")

            VStack(alignment: .leading, spacing: 6) {
                contactRow(icon: "envelope", text: "info@wolfwhale.ca")
                contactRow(icon: "globe", text: "www.wolfwhale.ca")
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

    // MARK: - Reusable Components

    private func sectionCard(
        number: String,
        title: String,
        icon: String,
        color: Color,
        @ViewBuilder content: () -> some View
    ) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(color)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Section \(number)")
                        .font(.caption.bold())
                        .foregroundStyle(color)
                    Text(title)
                        .font(.headline)
                }
                Spacer()
            }

            content()
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

    private func legalParagraph(_ text: String) -> some View {
        Text(text)
            .font(.body)
            .foregroundStyle(.secondary)
            .lineSpacing(4)
    }

    private func subsectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.subheadline.bold())
            .padding(.top, 4)
    }

    private func bulletPoint(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\u{2022}")
                .font(.body)
                .foregroundStyle(.tertiary)
            Text(text)
                .font(.body)
                .foregroundStyle(.secondary)
                .lineSpacing(3)
        }
    }

    private func contactRow(icon: String, text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.purple)
                .frame(width: 20)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    TermsOfServiceView()
}
