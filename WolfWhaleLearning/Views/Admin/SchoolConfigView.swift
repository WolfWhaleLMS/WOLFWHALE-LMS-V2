import SwiftUI
import Supabase

struct SchoolConfigView: View {
    let viewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss

    // MARK: - School Info

    @State private var schoolName: String = ""

    // MARK: - Grading Scale

    @State private var gradeAMin: Double = 90
    @State private var gradeBMin: Double = 80
    @State private var gradeCMin: Double = 70
    @State private var gradeDMin: Double = 60

    // MARK: - Semester Dates

    @State private var semesterStart: Date = Date()
    @State private var semesterEnd: Date = Calendar.current.date(byAdding: .month, value: 4, to: Date()) ?? Date()

    // MARK: - Default Grade Weights

    @State private var defaultAssignmentWeight: Double = 0.40
    @State private var defaultQuizWeight: Double = 0.20
    @State private var defaultParticipationWeight: Double = 0.10
    @State private var defaultMidtermWeight: Double = 0.15
    @State private var defaultFinalWeight: Double = 0.15

    // MARK: - UI State

    @State private var hapticTrigger = false
    @State private var showSavedConfirmation = false
    @State private var isSyncingToServer = false
    @State private var syncError: String?

    private var totalWeight: Double {
        defaultAssignmentWeight + defaultQuizWeight + defaultParticipationWeight + defaultMidtermWeight + defaultFinalWeight
    }

    private var weightsValid: Bool {
        abs(totalWeight - 1.0) < 0.01
    }

    private var gradingScaleValid: Bool {
        gradeAMin > gradeBMin && gradeBMin > gradeCMin && gradeCMin > gradeDMin && gradeDMin > 0
    }

    private var semesterDatesValid: Bool {
        semesterEnd > semesterStart
    }

    private var isFormValid: Bool {
        !schoolName.trimmingCharacters(in: .whitespaces).isEmpty
        && gradingScaleValid
        && semesterDatesValid
        && weightsValid
    }

    // MARK: - UserDefaults Keys

    private enum Keys {
        static let schoolName = "schoolConfig_schoolName"
        static let gradeAMin = "schoolConfig_gradeAMin"
        static let gradeBMin = "schoolConfig_gradeBMin"
        static let gradeCMin = "schoolConfig_gradeCMin"
        static let gradeDMin = "schoolConfig_gradeDMin"
        static let semesterStart = "schoolConfig_semesterStart"
        static let semesterEnd = "schoolConfig_semesterEnd"
        static let defaultAssignmentWeight = "schoolConfig_defaultAssignmentWeight"
        static let defaultQuizWeight = "schoolConfig_defaultQuizWeight"
        static let defaultParticipationWeight = "schoolConfig_defaultParticipationWeight"
        static let defaultMidtermWeight = "schoolConfig_defaultMidtermWeight"
        static let defaultFinalWeight = "schoolConfig_defaultFinalWeight"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 16) {
                    schoolInfoSection
                    gradingScaleSection
                    semesterDatesSection
                    defaultWeightsSection
                    saveSection
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("School Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        hapticTrigger.toggle()
                        dismiss()
                    }
                    .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
                }
            }
            .task { await loadConfig() }
            .alert("Settings Saved", isPresented: $showSavedConfirmation) {
                Button("OK") { dismiss() }
            } message: {
                Text("School configuration has been saved successfully.")
            }
        }
        .requireRole(.admin, .superAdmin, currentRole: viewModel.currentUser?.role)
    }

    // MARK: - School Info Section

    private var schoolInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("School Information", systemImage: "building.2.fill")
                .font(.headline)
                .foregroundStyle(Color(.label))

            HStack(spacing: 10) {
                Image(systemName: "character.cursor.ibeam")
                    .foregroundStyle(.blue)
                    .frame(width: 24)
                TextField("School Name", text: $schoolName)
                    .textContentType(.organizationName)
                    .autocorrectionDisabled()
            }
            .padding(12)
            .background(Color(.tertiarySystemFill))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Grading Scale Section

    private var gradingScaleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Grading Scale", systemImage: "chart.bar.fill")
                .font(.headline)
                .foregroundStyle(Color(.label))

            Text("Set the minimum percentage for each letter grade.")
                .font(.caption)
                .foregroundStyle(Color(.secondaryLabel))

            VStack(spacing: 0) {
                gradeThresholdRow(letter: "A", color: .green, value: $gradeAMin, range: "& above")
                Divider()
                gradeThresholdRow(letter: "B", color: .blue, value: $gradeBMin, range: "to \(Int(gradeAMin - 1))%")
                Divider()
                gradeThresholdRow(letter: "C", color: .orange, value: $gradeCMin, range: "to \(Int(gradeBMin - 1))%")
                Divider()
                gradeThresholdRow(letter: "D", color: .red, value: $gradeDMin, range: "to \(Int(gradeCMin - 1))%")
                Divider()
                HStack(spacing: 12) {
                    Text("F")
                        .font(.title3.bold())
                        .foregroundStyle(.red)
                        .frame(width: 30)
                    Text("Below \(Int(gradeDMin))%")
                        .font(.subheadline)
                        .foregroundStyle(Color(.secondaryLabel))
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            }
            .background(Color(.tertiarySystemFill))
            .clipShape(RoundedRectangle(cornerRadius: 10))

            if !gradingScaleValid {
                Label("Grade thresholds must be in descending order (A > B > C > D > 0).", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func gradeThresholdRow(letter: String, color: Color, value: Binding<Double>, range: String) -> some View {
        HStack(spacing: 12) {
            Text(letter)
                .font(.title3.bold())
                .foregroundStyle(color)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 2) {
                Text("\(Int(value.wrappedValue))% \(range)")
                    .font(.subheadline)
                    .foregroundStyle(Color(.label))
            }

            Spacer()

            HStack(spacing: 8) {
                Button {
                    hapticTrigger.toggle()
                    if value.wrappedValue > 1 { value.wrappedValue -= 1 }
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .foregroundStyle(color.opacity(0.7))
                }
                .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)

                Text("\(Int(value.wrappedValue))")
                    .font(.subheadline.bold())
                    .foregroundStyle(color)
                    .frame(width: 32)

                Button {
                    hapticTrigger.toggle()
                    if value.wrappedValue < 100 { value.wrappedValue += 1 }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(color.opacity(0.7))
                }
                .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    // MARK: - Semester Dates Section

    private var semesterDatesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Semester Dates", systemImage: "calendar")
                .font(.headline)
                .foregroundStyle(Color(.label))

            VStack(spacing: 0) {
                HStack {
                    Image(systemName: "calendar.badge.plus")
                        .foregroundStyle(.green)
                        .frame(width: 24)
                    Text("Start Date")
                        .font(.subheadline)
                        .foregroundStyle(Color(.label))
                    Spacer()
                    DatePicker("", selection: $semesterStart, displayedComponents: .date)
                        .labelsHidden()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)

                Divider()

                HStack {
                    Image(systemName: "calendar.badge.clock")
                        .foregroundStyle(.red)
                        .frame(width: 24)
                    Text("End Date")
                        .font(.subheadline)
                        .foregroundStyle(Color(.label))
                    Spacer()
                    DatePicker("", selection: $semesterEnd, displayedComponents: .date)
                        .labelsHidden()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            }
            .background(Color(.tertiarySystemFill))
            .clipShape(RoundedRectangle(cornerRadius: 10))

            if !semesterDatesValid {
                Label("End date must be after start date.", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            // Duration info
            if semesterDatesValid {
                let days = Calendar.current.dateComponents([.day], from: semesterStart, to: semesterEnd).day ?? 0
                let weeks = days / 7
                Label("\(weeks) weeks (\(days) days)", systemImage: "clock.fill")
                    .font(.caption)
                    .foregroundStyle(Color(.secondaryLabel))
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Default Weights Section

    private var defaultWeightsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Default Grade Weights", systemImage: "percent")
                .font(.headline)
                .foregroundStyle(Color(.label))

            Text("These weights will be used as the default for new courses.")
                .font(.caption)
                .foregroundStyle(Color(.secondaryLabel))

            weightSlider(label: "Assignments", icon: "doc.text.fill", color: .blue, value: $defaultAssignmentWeight)
            weightSlider(label: "Quizzes", icon: "questionmark.circle.fill", color: .orange, value: $defaultQuizWeight)
            weightSlider(label: "Participation", icon: "hand.raised.fill", color: .green, value: $defaultParticipationWeight)
            weightSlider(label: "Midterm", icon: "pencil.and.outline", color: .purple, value: $defaultMidtermWeight)
            weightSlider(label: "Final Exam", icon: "graduationcap.fill", color: .pink, value: $defaultFinalWeight)

            // Total indicator
            HStack {
                Text("Total")
                    .font(.subheadline.bold())
                    .foregroundStyle(Color(.label))
                Spacer()
                Text(String(format: "%.0f%%", totalWeight * 100))
                    .font(.subheadline.bold())
                    .foregroundStyle(weightsValid ? .green : .red)
            }
            .padding(.top, 4)

            if !weightsValid {
                let diff = totalWeight - 1.0
                Label(
                    diff > 0
                    ? "Weights exceed 100% by \(String(format: "%.0f%%", diff * 100)). Adjust to save."
                    : "Weights are \(String(format: "%.0f%%", abs(diff) * 100)) below 100%. Adjust to save.",
                    systemImage: "exclamationmark.triangle.fill"
                )
                .font(.caption)
                .foregroundStyle(.orange)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func weightSlider(label: String, icon: String, color: Color, value: Binding<Double>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                    .frame(width: 20)
                Text(label)
                    .font(.subheadline)
                    .foregroundStyle(Color(.label))
                Spacer()
                Text(String(format: "%.0f%%", value.wrappedValue * 100))
                    .font(.subheadline.bold())
                    .foregroundStyle(color)
                    .frame(width: 44, alignment: .trailing)
            }

            Slider(value: value, in: 0...1, step: 0.05)
                .tint(color)
        }
    }

    // MARK: - Save Section

    private var saveSection: some View {
        VStack(spacing: 12) {
            Button {
                hapticTrigger.toggle()
                saveToDefaults()
                showSavedConfirmation = true
            } label: {
                Label("Save Settings", systemImage: "square.and.arrow.down")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(isFormValid ? .blue : Color(.tertiarySystemFill))
                    .foregroundStyle(isFormValid ? .white : .secondary)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(!isFormValid)
            .sensoryFeedback(.impact(weight: .medium), trigger: hapticTrigger)

            Button {
                hapticTrigger.toggle()
                resetToDefaults()
            } label: {
                Label("Reset to Defaults", systemImage: "arrow.counterclockwise")
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color(.tertiarySystemFill))
                    .foregroundStyle(Color(.secondaryLabel))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)

            if let syncError {
                Label(syncError, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            } else {
                Label("Settings are saved locally and synced to the server.", systemImage: "info.circle")
                    .font(.caption)
                    .foregroundStyle(Color(.tertiaryLabel))
            }
        }
    }

    // MARK: - Persistence

    private struct SchoolConfigDTO: Codable {
        let schoolName: String
        let gradeAMin: Double
        let gradeBMin: Double
        let gradeCMin: Double
        let gradeDMin: Double
        let semesterStart: Double
        let semesterEnd: Double
        let defaultAssignmentWeight: Double
        let defaultQuizWeight: Double
        let defaultParticipationWeight: Double
        let defaultMidtermWeight: Double
        let defaultFinalWeight: Double

        enum CodingKeys: String, CodingKey {
            case schoolName = "school_name"
            case gradeAMin = "grade_a_min"
            case gradeBMin = "grade_b_min"
            case gradeCMin = "grade_c_min"
            case gradeDMin = "grade_d_min"
            case semesterStart = "semester_start"
            case semesterEnd = "semester_end"
            case defaultAssignmentWeight = "default_assignment_weight"
            case defaultQuizWeight = "default_quiz_weight"
            case defaultParticipationWeight = "default_participation_weight"
            case defaultMidtermWeight = "default_midterm_weight"
            case defaultFinalWeight = "default_final_weight"
        }
    }

    private func saveToDefaults() {
        let defaults = UserDefaults.standard
        defaults.set(schoolName, forKey: Keys.schoolName)
        defaults.set(gradeAMin, forKey: Keys.gradeAMin)
        defaults.set(gradeBMin, forKey: Keys.gradeBMin)
        defaults.set(gradeCMin, forKey: Keys.gradeCMin)
        defaults.set(gradeDMin, forKey: Keys.gradeDMin)
        defaults.set(semesterStart.timeIntervalSince1970, forKey: Keys.semesterStart)
        defaults.set(semesterEnd.timeIntervalSince1970, forKey: Keys.semesterEnd)
        defaults.set(defaultAssignmentWeight, forKey: Keys.defaultAssignmentWeight)
        defaults.set(defaultQuizWeight, forKey: Keys.defaultQuizWeight)
        defaults.set(defaultParticipationWeight, forKey: Keys.defaultParticipationWeight)
        defaults.set(defaultMidtermWeight, forKey: Keys.defaultMidtermWeight)
        defaults.set(defaultFinalWeight, forKey: Keys.defaultFinalWeight)

        // Sync to server
        Task {
            await syncConfigToServer()
        }
    }

    private func syncConfigToServer() async {
        let dto = SchoolConfigDTO(
            schoolName: schoolName,
            gradeAMin: gradeAMin,
            gradeBMin: gradeBMin,
            gradeCMin: gradeCMin,
            gradeDMin: gradeDMin,
            semesterStart: semesterStart.timeIntervalSince1970,
            semesterEnd: semesterEnd.timeIntervalSince1970,
            defaultAssignmentWeight: defaultAssignmentWeight,
            defaultQuizWeight: defaultQuizWeight,
            defaultParticipationWeight: defaultParticipationWeight,
            defaultMidtermWeight: defaultMidtermWeight,
            defaultFinalWeight: defaultFinalWeight
        )
        do {
            try await supabaseClient
                .from("school_config")
                .upsert(dto)
                .execute()
            syncError = nil
        } catch {
            // Local cache is still valid, log the sync failure
            syncError = "Failed to sync to server. Changes saved locally."
            #if DEBUG
            print("[SchoolConfigView] Failed to sync school config: \(error)")
            #endif
        }
    }

    private func loadConfig() async {
        // Try to fetch from Supabase first
        do {
            let dtos: [SchoolConfigDTO] = try await supabaseClient
                .from("school_config")
                .select()
                .limit(1)
                .execute()
                .value

            if let dto = dtos.first {
                schoolName = dto.schoolName
                gradeAMin = dto.gradeAMin
                gradeBMin = dto.gradeBMin
                gradeCMin = dto.gradeCMin
                gradeDMin = dto.gradeDMin
                semesterStart = Date(timeIntervalSince1970: dto.semesterStart)
                semesterEnd = Date(timeIntervalSince1970: dto.semesterEnd)
                defaultAssignmentWeight = dto.defaultAssignmentWeight
                defaultQuizWeight = dto.defaultQuizWeight
                defaultParticipationWeight = dto.defaultParticipationWeight
                defaultMidtermWeight = dto.defaultMidtermWeight
                defaultFinalWeight = dto.defaultFinalWeight
                return
            }
        } catch {
            #if DEBUG
            print("[SchoolConfigView] Failed to fetch config from server, falling back to UserDefaults: \(error)")
            #endif
        }

        // Fall back to UserDefaults cache
        loadFromDefaults()
    }

    private func loadFromDefaults() {
        let defaults = UserDefaults.standard

        if let name = defaults.string(forKey: Keys.schoolName) {
            schoolName = name
        }

        if defaults.object(forKey: Keys.gradeAMin) != nil {
            gradeAMin = defaults.double(forKey: Keys.gradeAMin)
        }
        if defaults.object(forKey: Keys.gradeBMin) != nil {
            gradeBMin = defaults.double(forKey: Keys.gradeBMin)
        }
        if defaults.object(forKey: Keys.gradeCMin) != nil {
            gradeCMin = defaults.double(forKey: Keys.gradeCMin)
        }
        if defaults.object(forKey: Keys.gradeDMin) != nil {
            gradeDMin = defaults.double(forKey: Keys.gradeDMin)
        }

        let startInterval = defaults.double(forKey: Keys.semesterStart)
        if startInterval > 0 {
            semesterStart = Date(timeIntervalSince1970: startInterval)
        }
        let endInterval = defaults.double(forKey: Keys.semesterEnd)
        if endInterval > 0 {
            semesterEnd = Date(timeIntervalSince1970: endInterval)
        }

        if defaults.object(forKey: Keys.defaultAssignmentWeight) != nil {
            defaultAssignmentWeight = defaults.double(forKey: Keys.defaultAssignmentWeight)
        }
        if defaults.object(forKey: Keys.defaultQuizWeight) != nil {
            defaultQuizWeight = defaults.double(forKey: Keys.defaultQuizWeight)
        }
        if defaults.object(forKey: Keys.defaultParticipationWeight) != nil {
            defaultParticipationWeight = defaults.double(forKey: Keys.defaultParticipationWeight)
        }
        if defaults.object(forKey: Keys.defaultMidtermWeight) != nil {
            defaultMidtermWeight = defaults.double(forKey: Keys.defaultMidtermWeight)
        }
        if defaults.object(forKey: Keys.defaultFinalWeight) != nil {
            defaultFinalWeight = defaults.double(forKey: Keys.defaultFinalWeight)
        }
    }

    private func resetToDefaults() {
        schoolName = ""
        gradeAMin = 90
        gradeBMin = 80
        gradeCMin = 70
        gradeDMin = 60
        semesterStart = Date()
        semesterEnd = Calendar.current.date(byAdding: .month, value: 4, to: Date()) ?? Date()
        defaultAssignmentWeight = 0.40
        defaultQuizWeight = 0.20
        defaultParticipationWeight = 0.10
        defaultMidtermWeight = 0.15
        defaultFinalWeight = 0.15
    }
}
