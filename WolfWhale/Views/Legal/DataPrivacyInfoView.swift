import SwiftUI

struct DataPrivacyInfoView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var hapticTrigger = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    headerSection
                    dataWeCollectSection
                    howWeUseItSection
                    yourRightsSection
                    optionalDataSection
                    contactSection
                }
                .padding(.horizontal)
                .padding(.bottom, 40)
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle("Your Data & Privacy")
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
                Image(systemName: "hand.raised.fingers.spread.fill")
                    .font(.title2)
                    .foregroundStyle(Theme.brandGradient)
                Text("Transparency Report")
                    .font(.title2.bold())
            }

            Text("We believe you should always know what data we collect and how we use it. Here is a clear breakdown of all data handled by WolfWhale LMS.")
                .font(.body)
                .foregroundStyle(.secondary)
                .lineSpacing(4)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

    // MARK: - Data We Collect

    private var dataWeCollectSection: some View {
        sectionCard(
            title: "Data We Collect",
            icon: "doc.text.magnifyingglass",
            color: .blue
        ) {
            VStack(alignment: .leading, spacing: 16) {
                dataCategory(
                    icon: "person.crop.circle.fill",
                    iconColor: .orange,
                    title: "Account Information",
                    items: [
                        "Name and email address",
                        "Role (student, teacher, parent, admin)",
                        "School or institution affiliation"
                    ]
                )

                dataCategory(
                    icon: "graduationcap.fill",
                    iconColor: .purple,
                    title: "Academic Data",
                    items: [
                        "Grades and assessment scores",
                        "Assignment submissions and progress",
                        "Attendance and enrollment records",
                        "Course and module completion status"
                    ]
                )

                dataCategory(
                    icon: "heart.fill",
                    iconColor: .red,
                    title: "Health Data (if HealthKit enabled)",
                    items: [
                        "Step count and walking distance",
                        "Active energy and exercise minutes",
                        "Used only for wellness features -- never shared"
                    ]
                )

                dataCategory(
                    icon: "location.fill",
                    iconColor: .green,
                    title: "Location (if geofencing enabled)",
                    items: [
                        "Campus proximity detection only",
                        "Never tracked outside school boundaries",
                        "Used for attendance verification"
                    ]
                )

                dataCategory(
                    icon: "chart.bar.fill",
                    iconColor: .orange,
                    title: "Usage Data",
                    items: [
                        "App feature interactions and page views",
                        "Login timestamps and session duration",
                        "Device type and OS version (anonymized)"
                    ]
                )
            }
        }
    }

    // MARK: - How We Use It

    private var howWeUseItSection: some View {
        sectionCard(
            title: "How We Use It",
            icon: "gearshape.2.fill",
            color: .purple
        ) {
            VStack(alignment: .leading, spacing: 12) {
                usageRow(
                    icon: "book.fill",
                    iconColor: .indigo,
                    text: "Provide educational services and deliver course content"
                )

                usageRow(
                    icon: "chart.line.uptrend.xyaxis",
                    iconColor: .teal,
                    text: "Track academic progress and generate reports for students, parents, and teachers"
                )

                usageRow(
                    icon: "bubble.left.and.bubble.right.fill",
                    iconColor: .blue,
                    text: "Enable communication between students, teachers, parents, and administrators"
                )

                usageRow(
                    icon: "star.fill",
                    iconColor: .yellow,
                    text: "Power gamification features (XP, levels, streaks, leaderboards)"
                )

                usageRow(
                    icon: "wrench.and.screwdriver.fill",
                    iconColor: .gray,
                    text: "Improve the app experience, fix bugs, and optimize performance"
                )

                usageRow(
                    icon: "shield.lefthalf.filled",
                    iconColor: .green,
                    text: "Ensure platform security and prevent unauthorized access"
                )
            }
        }
    }

    // MARK: - Your Rights

    private var yourRightsSection: some View {
        sectionCard(
            title: "Your Rights",
            icon: "person.badge.shield.checkmark.fill",
            color: .green
        ) {
            VStack(alignment: .leading, spacing: 12) {
                rightRow(
                    icon: "eye.fill",
                    iconColor: .blue,
                    title: "View Your Data",
                    description: "Request a copy of all personal data we store about you at any time."
                )

                rightRow(
                    icon: "square.and.arrow.up.fill",
                    iconColor: .indigo,
                    title: "Export Your Data",
                    description: "Download your educational records, grades, and submissions in a portable format."
                )

                rightRow(
                    icon: "trash.fill",
                    iconColor: .red,
                    title: "Delete Your Account & Data",
                    description: "Request permanent deletion of your account and all associated data. Processed within 30 business days."
                )

                rightRow(
                    icon: "hand.raised.slash.fill",
                    iconColor: .orange,
                    title: "Opt Out of Optional Collection",
                    description: "Disable optional data collection like HealthKit, location, and analytics at any time in Settings."
                )
            }
        }
    }

    // MARK: - Optional Data

    private var optionalDataSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "slider.horizontal.3")
                    .foregroundStyle(.orange)
                Text("Optional Data Collection")
                    .font(.headline)
            }

            legalParagraph("The following data categories are entirely optional. You can enable or disable them at any time without affecting core platform functionality:")

            optionalItem(
                icon: "heart.text.clipboard.fill",
                iconColor: .red,
                title: "HealthKit Integration",
                description: "Steps, activity, and exercise data for wellness features."
            )

            optionalItem(
                icon: "location.circle.fill",
                iconColor: .green,
                title: "Location Services",
                description: "Campus geofencing for automatic attendance."
            )

            optionalItem(
                icon: "chart.bar.xaxis",
                iconColor: .purple,
                title: "Usage Analytics",
                description: "Anonymized analytics to help us improve the app."
            )
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

    // MARK: - Contact

    private var contactSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "envelope.fill")
                    .foregroundStyle(.purple)
                Text("Questions?")
                    .font(.headline)
            }

            legalParagraph("If you have any questions about your data or want to exercise your rights, please contact:")

            VStack(alignment: .leading, spacing: 6) {
                contactRow(icon: "envelope", text: "info@wolfwhale.ca")
                contactRow(icon: "building.2", text: "Your school administrator")
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

    // MARK: - Reusable Components

    private func sectionCard(
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
                Text(title)
                    .font(.headline)
                Spacer()
            }

            content()
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

    private func dataCategory(
        icon: String,
        iconColor: Color,
        title: String,
        items: [String]
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.subheadline)
                    .foregroundStyle(iconColor)
                    .frame(width: 24)
                Text(title)
                    .font(.subheadline.bold())
            }

            ForEach(items, id: \.self) { item in
                HStack(alignment: .top, spacing: 10) {
                    Text("\u{2022}")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .padding(.leading, 32)
                    Text(item)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineSpacing(2)
                }
            }
        }
    }

    private func usageRow(icon: String, iconColor: Color, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(iconColor)
                .frame(width: 24)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineSpacing(2)
        }
    }

    private func rightRow(
        icon: String,
        iconColor: Color,
        title: String,
        description: String
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(iconColor)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.bold())
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineSpacing(2)
            }
        }
    }

    private func optionalItem(
        icon: String,
        iconColor: Color,
        title: String,
        description: String
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(iconColor)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.bold())
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineSpacing(2)
            }
        }
    }

    private func legalParagraph(_ text: String) -> some View {
        Text(text)
            .font(.body)
            .foregroundStyle(.secondary)
            .lineSpacing(4)
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
    DataPrivacyInfoView()
}
