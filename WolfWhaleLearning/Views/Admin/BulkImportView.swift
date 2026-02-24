import SwiftUI
import UniformTypeIdentifiers

struct BulkImportView: View {
    let viewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showFilePicker = false
    @State private var parsedRows: [CSVUserRow] = []
    @State private var validationErrors: [CSVValidationError] = []
    @State private var isImporting = false
    @State private var importProgress = 0
    @State private var importTotal = 0
    @State private var importResults: ImportResults?
    @State private var rawCSVText = ""
    @State private var hapticTrigger = false
    @State private var showManualEntry = false

    private var hasValidRows: Bool {
        parsedRows.contains { $0.isValid }
    }

    private var validRowCount: Int {
        parsedRows.filter(\.isValid).count
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 16) {
                    if let results = importResults {
                        summarySection(results)
                    } else if isImporting {
                        importingSection
                    } else if !parsedRows.isEmpty {
                        previewSection
                    } else {
                        uploadSection
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Import Users")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        hapticTrigger.toggle()
                        dismiss()
                    }
                    .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
                }
                if !parsedRows.isEmpty && importResults == nil && !isImporting {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Clear") {
                            hapticTrigger.toggle()
                            resetState()
                        }
                        .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
                    }
                }
            }
            .fileImporter(
                isPresented: $showFilePicker,
                allowedContentTypes: [UTType.commaSeparatedText],
                allowsMultipleSelection: false
            ) { result in
                handleFileImport(result)
            }
        }
        .requireRole(.admin, .superAdmin, currentRole: viewModel.currentUser?.role)
    }

    // MARK: - Upload Section

    private var uploadSection: some View {
        VStack(spacing: 20) {
            // Remaining slots banner
            slotsRemainingBanner

            // File picker card
            VStack(spacing: 16) {
                Image(systemName: "doc.text.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.blue)

                Text("Import Users from CSV")
                    .font(.title3.bold())
                    .foregroundStyle(Color(.label))

                Text("Upload a CSV file with columns:\nfirstName, lastName, email, role")
                    .font(.subheadline)
                    .foregroundStyle(Color(.secondaryLabel))
                    .multilineTextAlignment(.center)

                Button {
                    hapticTrigger.toggle()
                    showFilePicker = true
                } label: {
                    Label("Choose CSV File", systemImage: "folder.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(.blue)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .sensoryFeedback(.impact(weight: .medium), trigger: hapticTrigger)
            }
            .padding(24)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))

            // Manual paste card
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "text.alignleft")
                        .foregroundStyle(.orange)
                    Text("Or paste CSV text")
                        .font(.subheadline.bold())
                        .foregroundStyle(Color(.label))
                    Spacer()
                    Button {
                        hapticTrigger.toggle()
                        showManualEntry.toggle()
                    } label: {
                        Image(systemName: showManualEntry ? "chevron.up" : "chevron.down")
                            .foregroundStyle(Color(.secondaryLabel))
                    }
                    .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
                }

                if showManualEntry {
                    TextEditor(text: $rawCSVText)
                        .font(.system(.caption, design: .monospaced))
                        .frame(height: 120)
                        .scrollContentBackground(.hidden)
                        .padding(8)
                        .background(Color(.tertiarySystemFill))
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                    Button {
                        hapticTrigger.toggle()
                        parseCSVText(rawCSVText)
                    } label: {
                        Label("Parse CSV", systemImage: "arrow.right.circle.fill")
                            .font(.subheadline.bold())
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(.orange)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .disabled(rawCSVText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .sensoryFeedback(.impact(weight: .medium), trigger: hapticTrigger)
                }
            }
            .padding(16)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))

            // CSV format example
            csvFormatExample
        }
    }

    // MARK: - Slots Remaining Banner

    private var slotsRemainingBanner: some View {
        let remaining = viewModel.remainingUserSlots
        let total = viewModel.currentUser?.userSlotsTotal ?? 0

        return HStack(spacing: 10) {
            Image(systemName: "person.2.fill")
                .foregroundStyle(remaining <= 5 ? .orange : .blue)
            VStack(alignment: .leading, spacing: 2) {
                Text("User Seats")
                    .font(.subheadline.bold())
                    .foregroundStyle(Color(.label))
                Text("\(remaining) of \(total) remaining")
                    .font(.caption)
                    .foregroundStyle(Color(.secondaryLabel))
            }
            Spacer()
            if remaining <= 0 {
                Label("Full", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption.bold())
                    .foregroundStyle(.red)
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - CSV Format Example

    private var csvFormatExample: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("CSV Format Example", systemImage: "info.circle.fill")
                .font(.subheadline.bold())
                .foregroundStyle(.blue)

            Text("firstName,lastName,email,role\nJohn,Doe,john@school.edu,Student\nJane,Smith,jane@school.edu,Teacher\nBob,Parent,bob@email.com,Parent")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(Color(.secondaryLabel))
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.tertiarySystemFill))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            Text("Valid roles: Student, Teacher, Parent, Admin")
                .font(.caption)
                .foregroundStyle(Color(.tertiaryLabel))
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Preview Section

    private var previewSection: some View {
        VStack(spacing: 16) {
            // Validation summary
            if !validationErrors.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Label("\(validationErrors.count) Validation Error\(validationErrors.count == 1 ? "" : "s")", systemImage: "exclamationmark.triangle.fill")
                        .font(.subheadline.bold())
                        .foregroundStyle(.orange)

                    ForEach(validationErrors, id: \.row) { error in
                        HStack(spacing: 8) {
                            Text("Row \(error.row + 1)")
                                .font(.caption.bold())
                                .foregroundStyle(.orange)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.orange.opacity(0.12), in: Capsule())
                            Text(error.message)
                                .font(.caption)
                                .foregroundStyle(Color(.secondaryLabel))
                        }
                    }
                }
                .padding(14)
                .background(Color.orange.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.orange.opacity(0.3), lineWidth: 1)
                )
            }

            // Preview header
            HStack {
                Text("\(parsedRows.count) rows parsed")
                    .font(.subheadline.bold())
                    .foregroundStyle(Color(.label))
                Spacer()
                Text("\(validRowCount) valid")
                    .font(.caption.bold())
                    .foregroundStyle(.green)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.12), in: Capsule())
            }

            // Preview rows
            VStack(spacing: 0) {
                ForEach(Array(parsedRows.enumerated()), id: \.offset) { index, row in
                    csvRowPreview(row: row, index: index)
                    if index < parsedRows.count - 1 {
                        Divider()
                    }
                }
            }
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            // Import button
            Button {
                hapticTrigger.toggle()
                startImport()
            } label: {
                Label("Import \(validRowCount) User\(validRowCount == 1 ? "" : "s")", systemImage: "arrow.down.circle.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(hasValidRows ? .blue : Color(.tertiarySystemFill))
                    .foregroundStyle(hasValidRows ? .white : .secondary)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(!hasValidRows || viewModel.remainingUserSlots <= 0)
            .sensoryFeedback(.impact(weight: .medium), trigger: hapticTrigger)

            if viewModel.remainingUserSlots <= 0 {
                Label("No seats remaining. Upgrade your plan to import users.", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
            } else if validRowCount > viewModel.remainingUserSlots {
                Label("Only \(viewModel.remainingUserSlots) seat\(viewModel.remainingUserSlots == 1 ? "" : "s") remaining. Some imports will fail.", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
    }

    private func csvRowPreview(row: CSVUserRow, index: Int) -> some View {
        let role = UserRole.from(row.role)

        return HStack(spacing: 12) {
            // Status indicator
            Circle()
                .fill(row.isValid ? .green : .red)
                .frame(width: 8, height: 8)

            // Role icon
            if let role {
                Image(systemName: role.iconName)
                    .font(.caption)
                    .foregroundStyle(Theme.roleColor(role))
                    .frame(width: 24)
            } else {
                Image(systemName: "questionmark.circle")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .frame(width: 24)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("\(row.firstName) \(row.lastName)")
                    .font(.subheadline.bold())
                    .foregroundStyle(Color(.label))
                Text(row.email)
                    .font(.caption)
                    .foregroundStyle(Color(.secondaryLabel))
            }

            Spacer()

            if row.isValid {
                Text(row.role)
                    .font(.caption.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background((role.map { Theme.roleColor($0) } ?? .gray).opacity(0.12), in: Capsule())
                    .foregroundStyle(role.map { Theme.roleColor($0) } ?? .gray)
            } else {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.red)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Row \(index + 1): \(row.firstName) \(row.lastName), \(row.email), \(row.role), \(row.isValid ? "valid" : "invalid")")
    }

    // MARK: - Importing Section

    private var importingSection: some View {
        VStack(spacing: 20) {
            Image(systemName: "arrow.down.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.blue)
                .symbolEffect(.pulse, isActive: isImporting)

            Text("Importing Users...")
                .font(.title3.bold())
                .foregroundStyle(Color(.label))

            Text("\(importProgress) of \(importTotal)")
                .font(.subheadline)
                .foregroundStyle(Color(.secondaryLabel))

            ProgressView(value: Double(importProgress), total: Double(max(importTotal, 1)))
                .tint(.blue)
                .scaleEffect(y: 2)
                .padding(.horizontal, 40)

            Text("Please wait while accounts are being created...")
                .font(.caption)
                .foregroundStyle(Color(.tertiaryLabel))
        }
        .padding(32)
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Summary Section

    private func summarySection(_ results: ImportResults) -> some View {
        VStack(spacing: 16) {
            // Success banner
            VStack(spacing: 12) {
                Image(systemName: results.failedRows.isEmpty ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(results.failedRows.isEmpty ? .green : .orange)

                Text("Import Complete")
                    .font(.title3.bold())
                    .foregroundStyle(Color(.label))

                // Build summary text
                let summaryText = buildSummaryText(results)
                Text(summaryText)
                    .font(.subheadline)
                    .foregroundStyle(Color(.secondaryLabel))
                    .multilineTextAlignment(.center)
            }
            .padding(24)
            .frame(maxWidth: .infinity)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))

            // Breakdown by role
            if !results.successByRole.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Imported by Role")
                        .font(.subheadline.bold())
                        .foregroundStyle(Color(.label))

                    ForEach(Array(results.successByRole.keys.sorted()), id: \.self) { role in
                        let count = results.successByRole[role] ?? 0
                        let userRole = UserRole.from(role)
                        HStack(spacing: 10) {
                            Image(systemName: userRole?.iconName ?? "person.fill")
                                .foregroundStyle(userRole.map { Theme.roleColor($0) } ?? .gray)
                                .frame(width: 24)
                            Text("\(count) \(role)\(count == 1 ? "" : "s")")
                                .font(.subheadline)
                                .foregroundStyle(Color(.label))
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        }
                    }
                }
                .padding(16)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            // Failed rows
            if !results.failedRows.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Label("\(results.failedRows.count) Failed", systemImage: "xmark.circle.fill")
                        .font(.subheadline.bold())
                        .foregroundStyle(.red)

                    ForEach(results.failedRows, id: \.row) { failure in
                        HStack(spacing: 8) {
                            Text("Row \(failure.row + 1)")
                                .font(.caption.bold())
                                .foregroundStyle(.red)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.red.opacity(0.12), in: Capsule())
                            VStack(alignment: .leading, spacing: 2) {
                                Text(failure.name)
                                    .font(.caption.bold())
                                    .foregroundStyle(Color(.label))
                                Text(failure.reason)
                                    .font(.caption)
                                    .foregroundStyle(Color(.secondaryLabel))
                            }
                            Spacer()
                        }
                    }
                }
                .padding(16)
                .background(Color.red.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.red.opacity(0.2), lineWidth: 1)
                )
            }

            // Done button
            Button {
                hapticTrigger.toggle()
                dismiss()
            } label: {
                Text("Done")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(.blue)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .sensoryFeedback(.impact(weight: .medium), trigger: hapticTrigger)
        }
    }

    // MARK: - CSV Parsing

    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            guard url.startAccessingSecurityScopedResource() else { return }
            defer { url.stopAccessingSecurityScopedResource() }

            do {
                let csvString = try String(contentsOf: url, encoding: .utf8)
                parseCSVText(csvString)
            } catch {
                validationErrors = [CSVValidationError(row: 0, message: "Could not read file: \(error.localizedDescription)")]
            }
        case .failure(let error):
            validationErrors = [CSVValidationError(row: 0, message: "File picker error: \(error.localizedDescription)")]
        }
    }

    private func parseCSVText(_ text: String) {
        var rows: [CSVUserRow] = []
        var errors: [CSVValidationError] = []
        var seenEmails: Set<String> = []

        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        guard !lines.isEmpty else {
            validationErrors = [CSVValidationError(row: 0, message: "CSV file is empty")]
            return
        }

        // Detect if first line is a header
        let firstLine = lines[0].lowercased()
        let startIndex = (firstLine.contains("firstname") || firstLine.contains("first_name") || firstLine.contains("email")) ? 1 : 0

        for (lineIndex, line) in lines.enumerated() {
            if lineIndex < startIndex { continue }

            let columns = parseCSVLine(line)
            let rowIndex = lineIndex - startIndex

            guard columns.count >= 4 else {
                errors.append(CSVValidationError(row: rowIndex, message: "Expected 4 columns (firstName, lastName, email, role), found \(columns.count)"))
                rows.append(CSVUserRow(firstName: columns.first ?? "", lastName: columns.count > 1 ? columns[1] : "", email: columns.count > 2 ? columns[2] : "", role: columns.count > 3 ? columns[3] : "", isValid: false))
                continue
            }

            let firstName = columns[0].trimmingCharacters(in: .whitespaces)
            let lastName = columns[1].trimmingCharacters(in: .whitespaces)
            let email = columns[2].trimmingCharacters(in: .whitespaces).lowercased()
            let role = columns[3].trimmingCharacters(in: .whitespaces)

            var rowValid = true

            // Validate first name
            if firstName.isEmpty {
                errors.append(CSVValidationError(row: rowIndex, message: "Missing first name"))
                rowValid = false
            }

            // Validate last name
            if lastName.isEmpty {
                errors.append(CSVValidationError(row: rowIndex, message: "Missing last name"))
                rowValid = false
            }

            // Validate email
            let emailRegex = #"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
            if email.isEmpty {
                errors.append(CSVValidationError(row: rowIndex, message: "Missing email"))
                rowValid = false
            } else if email.range(of: emailRegex, options: .regularExpression) == nil {
                errors.append(CSVValidationError(row: rowIndex, message: "Invalid email format: \(email)"))
                rowValid = false
            } else if seenEmails.contains(email) {
                errors.append(CSVValidationError(row: rowIndex, message: "Duplicate email: \(email)"))
                rowValid = false
            }
            seenEmails.insert(email)

            // Validate role
            if UserRole.from(role) == nil {
                errors.append(CSVValidationError(row: rowIndex, message: "Invalid role: \"\(role)\". Use Student, Teacher, Parent, or Admin"))
                rowValid = false
            }

            rows.append(CSVUserRow(firstName: firstName, lastName: lastName, email: email, role: role, isValid: rowValid))
        }

        parsedRows = rows
        validationErrors = errors
    }

    /// Parses a single CSV line respecting quoted fields.
    private func parseCSVLine(_ line: String) -> [String] {
        var fields: [String] = []
        var current = ""
        var inQuotes = false

        for char in line {
            if char == "\"" {
                inQuotes.toggle()
            } else if char == "," && !inQuotes {
                fields.append(current)
                current = ""
            } else {
                current.append(char)
            }
        }
        fields.append(current)
        return fields
    }

    // MARK: - Import Logic

    private func startImport() {
        let validRows = parsedRows.filter(\.isValid)
        guard !validRows.isEmpty else { return }

        isImporting = true
        importTotal = validRows.count
        importProgress = 0

        Task {
            var successByRole: [String: Int] = [:]
            var failedRows: [ImportFailure] = []

            for (index, row) in validRows.enumerated() {
                guard let role = UserRole.from(row.role) else {
                    failedRows.append(ImportFailure(
                        row: index,
                        name: "\(row.firstName) \(row.lastName)",
                        reason: "Invalid role"
                    ))
                    importProgress = index + 1
                    continue
                }

                // Check remaining slots
                if viewModel.remainingUserSlots <= 0 {
                    failedRows.append(ImportFailure(
                        row: index,
                        name: "\(row.firstName) \(row.lastName)",
                        reason: "No seats remaining"
                    ))
                    importProgress = index + 1
                    continue
                }

                // Generate a temporary password
                let tempPassword = generateTempPassword()

                do {
                    try await viewModel.createUser(
                        firstName: row.firstName,
                        lastName: row.lastName,
                        email: row.email,
                        password: tempPassword,
                        role: role
                    )
                    successByRole[row.role, default: 0] += 1
                } catch {
                    let reason = mapImportError(error)
                    failedRows.append(ImportFailure(
                        row: index,
                        name: "\(row.firstName) \(row.lastName)",
                        reason: reason
                    ))
                }

                importProgress = index + 1
            }

            let totalSuccess = successByRole.values.reduce(0, +)
            importResults = ImportResults(
                totalImported: totalSuccess,
                totalFailed: failedRows.count,
                successByRole: successByRole,
                failedRows: failedRows
            )
            isImporting = false
        }
    }

    private func generateTempPassword() -> String {
        let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
        let digits = "0123456789"
        let specials = "!@#$%"
        var password = String((0..<6).map { _ in letters.randomElement()! })
        password += String((0..<2).map { _ in digits.randomElement()! })
        password += String(specials.randomElement()!)
        return password
    }

    private func mapImportError(_ error: Error) -> String {
        let message = error.localizedDescription.lowercased()
        if message.contains("duplicate") || message.contains("already registered") || message.contains("already been registered") {
            return "Email already exists (duplicate)"
        } else if message.contains("slot") || message.contains("seats") {
            return "No seats remaining"
        } else if message.contains("unauthorized") {
            return "Unauthorized"
        }
        return error.localizedDescription
    }

    private func buildSummaryText(_ results: ImportResults) -> String {
        var parts: [String] = []
        for role in results.successByRole.keys.sorted() {
            let count = results.successByRole[role] ?? 0
            parts.append("\(count) \(role.lowercased())\(count == 1 ? "" : "s")")
        }
        var text = "Successfully imported \(parts.joined(separator: ", "))."
        if results.totalFailed > 0 {
            text += " \(results.totalFailed) failed."
        }
        return text
    }

    private func resetState() {
        parsedRows = []
        validationErrors = []
        importResults = nil
        importProgress = 0
        importTotal = 0
        isImporting = false
        rawCSVText = ""
    }
}

// MARK: - Supporting Types

struct CSVUserRow: Sendable {
    let firstName: String
    let lastName: String
    let email: String
    let role: String
    let isValid: Bool
}

struct CSVValidationError: Sendable {
    let row: Int
    let message: String
}

struct ImportResults: Sendable {
    let totalImported: Int
    let totalFailed: Int
    let successByRole: [String: Int]
    let failedRows: [ImportFailure]
}

struct ImportFailure: Sendable {
    let row: Int
    let name: String
    let reason: String
}
