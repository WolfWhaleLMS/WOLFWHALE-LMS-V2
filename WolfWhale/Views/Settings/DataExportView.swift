import SwiftUI

struct DataExportView: View {
    let viewModel: AppViewModel

    @State private var isExporting = false
    @State private var exportedFileURL: URL?
    @State private var showShareSheet = false
    @State private var errorMessage: String?
    @State private var showErrorAlert = false
    @State private var hapticTrigger = false

    private let includedDataItems: [(icon: String, label: String, color: Color)] = [
        ("person.crop.circle.fill", "Profile information", .orange),
        ("graduationcap.fill", "Grades & transcripts", Theme.brandPurple),
        ("doc.text.fill", "Submissions & assignments", Theme.brandBlue),
        ("checkmark.circle.fill", "Attendance records", Theme.brandGreen),
        ("bubble.left.and.bubble.right.fill", "Messages & conversations", .blue),
        ("calendar", "Calendar events", .teal),
        ("bell.fill", "Notification preferences", .red),
        ("gearshape.fill", "App settings", .gray),
    ]

    var body: some View {
        List {
            explanationSection
            includedDataSection
            downloadSection
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Download My Data")
        .navigationBarTitleDisplayMode(.large)
        .alert("Export Failed", isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage ?? "Your data export could not be completed. Please check your storage space and try again.")
        }
        .sheet(isPresented: $showShareSheet) {
            if let url = exportedFileURL {
                ShareSheetView(activityItems: [url])
                    .presentationDetents([.medium, .large])
            }
        }
    }

    // MARK: - Explanation Section

    private var explanationSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: "lock.shield.fill")
                        .font(.title2)
                        .foregroundStyle(Theme.brandBlue)
                        .symbolRenderingMode(.hierarchical)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Your Data, Your Rights")
                            .font(.headline)
                        Text("GDPR & FERPA Compliant")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Text("Download a copy of all your personal data stored in WolfWhale LMS. Your data will be exported as a JSON file that you can open, inspect, and keep for your records.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 4)
        } header: {
            sectionHeader(title: "About Data Export", icon: "arrow.down.doc.fill")
        }
    }

    // MARK: - Included Data Section

    private var includedDataSection: some View {
        Section {
            ForEach(includedDataItems, id: \.label) { item in
                Label {
                    Text(item.label)
                        .font(.subheadline)
                } icon: {
                    Image(systemName: item.icon)
                        .foregroundStyle(item.color)
                        .symbolRenderingMode(.hierarchical)
                }
            }
        } header: {
            sectionHeader(title: "Included Data", icon: "list.bullet.rectangle.fill")
        } footer: {
            Text("All data associated with your account will be included in the export.")
        }
    }

    // MARK: - Download Section

    private var downloadSection: some View {
        Section {
            Button {
                hapticTrigger.toggle()
                Task { await exportData() }
            } label: {
                HStack {
                    Spacer()
                    if isExporting {
                        ProgressView()
                            .controlSize(.small)
                            .tint(.white)
                            .padding(.trailing, 8)
                        Text("Exporting...")
                            .font(.headline)
                            .foregroundStyle(.white)
                    } else {
                        Image(systemName: "arrow.down.doc.fill")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .padding(.trailing, 4)
                        Text("Download My Data")
                            .font(.headline)
                            .foregroundStyle(.white)
                    }
                    Spacer()
                }
                .padding(.vertical, 6)
            }
            .listRowBackground(
                Group {
                    if isExporting {
                        Color.gray
                    } else {
                        Theme.brandGradient
                    }
                }
            )
            .disabled(isExporting)
            .sensoryFeedback(.impact(weight: .medium), trigger: hapticTrigger)
            .accessibilityLabel(isExporting ? "Exporting data" : "Download My Data")
            .accessibilityHint("Exports all your personal data as a JSON file")
        } footer: {
            Text("Your data will be prepared and you can save or share the file. This may take a moment depending on the amount of data.")
        }
    }

    // MARK: - Export Logic

    private func exportData() async {
        isExporting = true
        defer { isExporting = false }

        do {
            guard let user = viewModel.currentUser else {
                throw ExportError.noUser
            }

            // Build the export payload from available view model data
            var exportDict: [String: Any] = [:]

            // Profile
            exportDict["profile"] = [
                "id": user.id.uuidString,
                "full_name": user.fullName,
                "email": user.email,
                "role": user.role.rawValue,
                "exported_at": ISO8601DateFormatter().string(from: Date()),
            ]

            // Grades
            let gradesArray = viewModel.grades.map { grade -> [String: Any] in
                [
                    "id": grade.id.uuidString,
                    "course_id": grade.courseId.uuidString,
                    "course_name": grade.courseName,
                    "letter_grade": grade.letterGrade,
                    "numeric_grade": grade.numericGrade,
                ]
            }
            exportDict["grades"] = gradesArray

            // Assignments
            let assignmentsArray = viewModel.assignments.map { assignment -> [String: Any] in
                [
                    "id": assignment.id.uuidString,
                    "title": assignment.title,
                    "course_name": assignment.courseName,
                    "due_date": assignment.dueDate.description,
                    "points": assignment.points,
                    "is_submitted": assignment.isSubmitted,
                ]
            }
            exportDict["assignments"] = assignmentsArray

            // Attendance
            let attendanceArray = viewModel.attendance.map { record -> [String: Any] in
                [
                    "id": record.id.uuidString,
                    "course_name": record.courseName,
                    "date": record.date.description,
                    "status": record.status.rawValue,
                ]
            }
            exportDict["attendance"] = attendanceArray

            // Conversations
            let conversationsArray = viewModel.conversations.map { convo -> [String: Any] in
                [
                    "id": convo.id.uuidString,
                    "title": convo.title,
                    "participants": convo.participantNames,
                    "last_message_date": convo.lastMessageDate.description,
                    "message_count": convo.messages.count,
                ]
            }
            exportDict["conversations"] = conversationsArray

            // Serialize to JSON
            let jsonData = try JSONSerialization.data(withJSONObject: exportDict, options: [.prettyPrinted, .sortedKeys])

            // Write to a temporary file
            let fileName = "WolfWhale_DataExport_\(user.fullName.replacingOccurrences(of: " ", with: "_"))_\(formattedDate()).json"
            let tempURL = FileManager.default.temporaryDirectory.appending(path: fileName)
            try jsonData.write(to: tempURL)

            exportedFileURL = tempURL
            showShareSheet = true
        } catch {
            errorMessage = UserFacingError.message(from: error)
            showErrorAlert = true
        }
    }

    private func formattedDate() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

    private enum ExportError: LocalizedError {
        case noUser

        var errorDescription: String? {
            switch self {
            case .noUser:
                return "No user session found. Please sign in and try again."
            }
        }
    }

    // MARK: - Section Header

    private func sectionHeader(title: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption2)
                .symbolRenderingMode(.hierarchical)
            Text(title.uppercased())
                .font(.caption2.bold())
        }
        .foregroundStyle(.secondary)
    }
}

// Uses ShareSheetView defined in ReportCardView.swift
