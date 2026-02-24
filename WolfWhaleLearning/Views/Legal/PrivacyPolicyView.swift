import SwiftUI

struct PrivacyPolicyView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var hapticTrigger = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    headerSection
                    informationCollectedSection
                    howWeUseDataSection
                    dataStorageSection
                    dataRetentionSection
                    childrenPrivacySection
                    parentalConsentSection
                    rightToDeletionSection
                    thirdPartySection
                    dataSecuritySection
                    changesToPolicySection
                    contactSection
                }
                .padding(.horizontal)
                .padding(.bottom, 40)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Privacy Policy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        hapticTrigger.toggle()
                        dismiss()
                    }
                    .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
                }
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "hand.raised.fill")
                    .font(.title2)
                    .foregroundStyle(Theme.brandGradient)
                Text("WolfWhale LMS")
                    .font(.title2.bold())
            }

            Text("Last updated: February 20, 2026")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text("Your privacy is critically important to us. WolfWhale LMS is designed to serve educational institutions, and we take the privacy and security of student data very seriously. This Privacy Policy explains how we collect, use, store, and protect your information in compliance with the Children's Online Privacy Protection Act (COPPA), the Family Educational Rights and Privacy Act (FERPA), and other applicable privacy laws.")
                .font(.body)
                .foregroundStyle(.secondary)
                .lineSpacing(4)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

    // MARK: - 1. Information We Collect

    private var informationCollectedSection: some View {
        sectionCard(
            number: "1",
            title: "Information We Collect",
            icon: "doc.text.magnifyingglass",
            color: .blue
        ) {
            VStack(alignment: .leading, spacing: 12) {
                legalParagraph("We collect only the information necessary to provide and improve our educational services:")

                subsectionTitle("Account Information")
                bulletPoint("Full name, email address, and role (Student, Teacher, Parent, or Admin) as provided during account creation by school administrators.")
                bulletPoint("Grade level, class assignments, and institutional affiliation.")

                subsectionTitle("Educational Data")
                bulletPoint("Course enrollment, lesson progress, and module completion status.")
                bulletPoint("Assignment submissions, quiz answers, and grades.")
                bulletPoint("Attendance records entered by teachers.")

                subsectionTitle("Gamification Data")
                bulletPoint("Experience points (XP), level progress, streak counts, and achievement badges.")
                bulletPoint("Leaderboard rankings within classes and the institution.")

                subsectionTitle("Communication Data")
                bulletPoint("Messages sent and received through the platform's built-in messaging system between students, teachers, parents, and administrators.")

                subsectionTitle("Usage Data")
                bulletPoint("Login timestamps, pages viewed, and feature interactions for the purpose of improving the platform experience and ensuring system security.")
                bulletPoint("Device type and operating system version for compatibility and performance optimization.")

                subsectionTitle("Information We Do NOT Collect")
                bulletPoint("We do not collect social security numbers, financial information from students, precise geolocation data, biometric data, or contact lists from user devices.")
            }
        }
    }

    // MARK: - 2. How We Use Your Data

    private var howWeUseDataSection: some View {
        sectionCard(
            number: "2",
            title: "How We Use Your Data",
            icon: "gearshape.2.fill",
            color: .purple
        ) {
            VStack(alignment: .leading, spacing: 12) {
                legalParagraph("We use the information we collect solely for educational purposes:")

                bulletPoint("To provide, operate, and maintain the LMS platform and its features, including courses, assignments, grades, and messaging.")
                bulletPoint("To track academic progress and generate reports for students, parents, teachers, and administrators.")
                bulletPoint("To operate gamification features (XP, levels, streaks, leaderboards) that support student engagement and motivation.")
                bulletPoint("To facilitate communication between students, teachers, parents, and school administrators.")
                bulletPoint("To ensure the security and integrity of the platform, including detecting and preventing unauthorized access.")
                bulletPoint("To improve and optimize the platform's performance and user experience.")
                bulletPoint("To comply with legal obligations and respond to lawful requests from educational institutions and authorities.")

                legalParagraph("We do not use student data for advertising, marketing, or any purpose unrelated to providing educational services.")
            }
        }
    }

    // MARK: - 3. Data Storage

    private var dataStorageSection: some View {
        sectionCard(
            number: "3",
            title: "How Student Data Is Stored",
            icon: "server.rack",
            color: .indigo
        ) {
            VStack(alignment: .leading, spacing: 12) {
                legalParagraph("We use Supabase as our backend infrastructure provider to securely store and manage all platform data:")

                subsectionTitle("Infrastructure")
                bulletPoint("All data is stored on Supabase's cloud infrastructure, which uses enterprise-grade PostgreSQL databases with built-in security features.")
                bulletPoint("Supabase provides row-level security (RLS) policies, ensuring users can only access data they are authorized to view.")

                subsectionTitle("Encryption")
                bulletPoint("All data is encrypted in transit using TLS 1.2 or higher.")
                bulletPoint("All data is encrypted at rest using AES-256 encryption.")
                bulletPoint("Database backups are also encrypted and stored securely.")

                subsectionTitle("Access Controls")
                bulletPoint("Access to the database is restricted through role-based access controls (RBAC). Students, teachers, parents, and administrators each have distinct permission levels.")
                bulletPoint("API keys and database credentials are securely managed and never exposed to client-side code.")
                bulletPoint("Audit logs track administrative access to sensitive data.")

                subsectionTitle("Data Location")
                bulletPoint("Data is stored in secure data centers located within the United States, in compliance with applicable data residency requirements.")
            }
        }
    }

    // MARK: - 4. Data Retention

    private var dataRetentionSection: some View {
        sectionCard(
            number: "4",
            title: "Data Retention Policy",
            icon: "clock.arrow.circlepath",
            color: .orange
        ) {
            VStack(alignment: .leading, spacing: 12) {
                legalParagraph("We retain student and user data only as long as necessary for educational purposes:")

                bulletPoint("Active student records are maintained for the duration of the student's enrollment at the educational institution.")
                bulletPoint("Upon a student's departure from the institution (graduation, transfer, or withdrawal), the institution may request that records be retained for up to seven (7) years in accordance with educational record-keeping requirements, or deleted sooner upon request.")
                bulletPoint("Inactive accounts that have not been accessed for more than two (2) years may be flagged for review and potential deletion, with prior notice to the institution.")
                bulletPoint("Gamification data (XP, streaks, achievements) is retained as long as the associated student account is active.")
                bulletPoint("Messages and communication logs are retained for a maximum of three (3) years after the account becomes inactive, unless a longer period is required by the institution.")
                bulletPoint("Usage and analytics data is aggregated and anonymized after twelve (12) months. Anonymized data may be retained indefinitely for platform improvement purposes.")
                bulletPoint("Backup data is retained for a maximum of ninety (90) days and is securely purged thereafter.")
            }
        }
    }

    // MARK: - 5. Children's Privacy (COPPA)

    private var childrenPrivacySection: some View {
        sectionCard(
            number: "5",
            title: "Children's Privacy (COPPA Compliance)",
            icon: "figure.and.child.holdinghands",
            color: .teal
        ) {
            VStack(alignment: .leading, spacing: 12) {
                legalParagraph("WolfWhale LMS is committed to compliance with the Children's Online Privacy Protection Act (COPPA) for users under the age of 13:")

                bulletPoint("We do not knowingly collect personal information directly from children under 13 without verifiable parental consent or school consent acting in loco parentis (in place of the parent).")
                bulletPoint("In the educational context, schools may consent to the collection of student information on behalf of parents, provided the data is used solely for educational purposes.")
                bulletPoint("We collect only the minimum personal information necessary to provide the educational service.")
                bulletPoint("Children's data is never used for commercial purposes, targeted advertising, or sold to third parties.")
                bulletPoint("Parents have the right to review their child's personal information, request its deletion, and refuse to permit further collection.")
                bulletPoint("We do not condition a child's participation in any activity on the disclosure of more personal information than is reasonably necessary.")
            }
        }
    }

    // MARK: - 6. Parental Consent

    private var parentalConsentSection: some View {
        sectionCard(
            number: "6",
            title: "Parental Consent Requirements",
            icon: "person.2.fill",
            color: .green
        ) {
            VStack(alignment: .leading, spacing: 12) {
                legalParagraph("For students under the age of 13, the following consent mechanisms are in place:")

                subsectionTitle("School-Based Consent")
                bulletPoint("Educational institutions may provide consent on behalf of parents under COPPA's school consent exception, provided the student data is used solely for school-authorized educational purposes.")
                bulletPoint("Schools using WolfWhale LMS are responsible for providing parents with notice about the platform's data collection practices and for obtaining any additional consent required by their policies.")

                subsectionTitle("Direct Parental Consent")
                bulletPoint("Where school consent is not applicable, we require verifiable parental consent before creating an account for a child under 13.")
                bulletPoint("Parents may provide consent through a signed consent form provided by the school, an email verification process, or other verifiable means.")

                subsectionTitle("Parental Rights")
                bulletPoint("Parents may review their child's personal information by requesting access through their school administrator or by contacting WolfWhale support directly.")
                bulletPoint("Parents may revoke consent and request deletion of their child's personal information at any time. Upon such a request, we will delete the data within thirty (30) business days, unless retention is required by the educational institution for legitimate record-keeping purposes.")
                bulletPoint("Parents who are registered as \"Parent\" role users on the platform can view their child's academic progress, grades, and activity directly through the parent dashboard.")
            }
        }
    }

    // MARK: - 7. Right to Deletion

    private var rightToDeletionSection: some View {
        sectionCard(
            number: "7",
            title: "Right to Deletion",
            icon: "trash.fill",
            color: .red
        ) {
            VStack(alignment: .leading, spacing: 12) {
                legalParagraph("Users and institutions have the right to request the deletion of personal data:")

                subsectionTitle("Who Can Request Deletion")
                bulletPoint("Parents or guardians may request deletion of their child's personal data at any time.")
                bulletPoint("Eligible students (18 years or older, or attending a postsecondary institution) may request deletion of their own data.")
                bulletPoint("School administrators may request deletion of student, teacher, or staff data for their institution.")

                subsectionTitle("Deletion Process")
                bulletPoint("Deletion requests should be submitted to the school administrator, who will coordinate with WolfWhale, or directly to WolfWhale support at info@wolfwhale.ca.")
                bulletPoint("We will process deletion requests within thirty (30) business days of receipt.")
                bulletPoint("Upon deletion, the user's personal information, educational records, gamification data, and communication logs will be permanently removed from active systems.")

                subsectionTitle("Exceptions")
                bulletPoint("Certain data may be retained if required by law, regulation, or for legitimate educational record-keeping as directed by the institution.")
                bulletPoint("Anonymized and aggregated data that cannot be used to identify an individual may be retained for analytics purposes.")
                bulletPoint("Data stored in encrypted backups will be purged in accordance with our backup retention schedule (within 90 days).")
            }
        }
    }

    // MARK: - 8. Third-Party Data Sharing

    private var thirdPartySection: some View {
        sectionCard(
            number: "8",
            title: "Third-Party Data Sharing",
            icon: "arrow.triangle.branch",
            color: .orange
        ) {
            VStack(alignment: .leading, spacing: 12) {
                legalParagraph("WolfWhale LMS is committed to minimizing third-party data sharing:")

                subsectionTitle("We Do NOT")
                bulletPoint("Sell student or user data to any third party, under any circumstances.")
                bulletPoint("Share data with advertisers, data brokers, or marketing companies.")
                bulletPoint("Use student data to build advertising profiles or for behavioral targeting.")

                subsectionTitle("Limited Sharing for Platform Operations")
                legalParagraph("We may share limited data with the following categories of service providers, solely for the purpose of operating the platform:")

                bulletPoint("Supabase (database hosting and backend infrastructure) -- processes data under a data processing agreement that requires FERPA and COPPA-compliant handling.")
                bulletPoint("Apple (for App Store distribution and crash reporting) -- receives only anonymized crash and performance data, not student educational records.")

                subsectionTitle("Legal Disclosures")
                bulletPoint("We may disclose data when required by law, such as in response to a valid subpoena, court order, or government request.")
                bulletPoint("We may disclose data to protect the safety of students or others in cases of emergency, as permitted by FERPA.")
                bulletPoint("We will notify the affected institution before disclosing data unless prohibited by law from doing so.")
            }
        }
    }

    // MARK: - 9. Data Security

    private var dataSecuritySection: some View {
        sectionCard(
            number: "9",
            title: "Data Security Measures",
            icon: "lock.fill",
            color: .cyan
        ) {
            VStack(alignment: .leading, spacing: 12) {
                legalParagraph("We implement comprehensive security measures to protect your data:")

                bulletPoint("End-to-end encryption for data in transit (TLS 1.2+) and at rest (AES-256).")
                bulletPoint("Row-level security policies in our database ensuring users can only access data relevant to their role and permissions.")
                bulletPoint("Regular security audits and vulnerability assessments of the platform.")
                bulletPoint("Secure authentication with password hashing using industry-standard algorithms.")
                bulletPoint("Automatic session management and timeout policies.")
                bulletPoint("Incident response procedures in place to promptly address any data breach, including notification to affected institutions and users within seventy-two (72) hours of discovery.")

                legalParagraph("While we take every reasonable precaution to protect your data, no system can guarantee absolute security. We encourage users to maintain strong passwords and report any suspicious activity immediately.")
            }
        }
    }

    // MARK: - 10. Changes to Policy

    private var changesToPolicySection: some View {
        sectionCard(
            number: "10",
            title: "Changes to This Privacy Policy",
            icon: "arrow.triangle.2.circlepath",
            color: .yellow
        ) {
            VStack(alignment: .leading, spacing: 12) {
                legalParagraph("We may update this Privacy Policy from time to time to reflect changes in our practices, technology, or legal requirements. When we make changes:")

                bulletPoint("We will update the \"Last updated\" date at the top of this policy.")
                bulletPoint("For material changes, we will notify institutional administrators and provide prominent notice on the platform.")
                bulletPoint("Where required by law, we will obtain new consent before implementing changes that affect the collection or use of children's data.")
                bulletPoint("We will provide a minimum of thirty (30) days' notice before material changes take effect, except where immediate changes are required for legal compliance or security.")
            }
        }
    }

    // MARK: - Contact

    private var contactSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "envelope.fill")
                    .foregroundStyle(.purple)
                Text("Contact Us")
                    .font(.headline)
            }

            legalParagraph("If you have questions, concerns, or requests regarding this Privacy Policy or your data, please contact:")

            VStack(alignment: .leading, spacing: 6) {
                contactRow(icon: "envelope", text: "info@wolfwhale.ca")
                contactRow(icon: "globe", text: "www.wolfwhale.ca")
                contactRow(icon: "building.2", text: "Your school administrator")
            }

            legalParagraph("For concerns about COPPA or FERPA compliance, you may also contact the U.S. Department of Education's Student Privacy Policy Office.")
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
    PrivacyPolicyView()
}
