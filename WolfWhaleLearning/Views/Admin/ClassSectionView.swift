import SwiftUI

struct ClassSectionView: View {
    let viewModel: AppViewModel
    @State private var hapticTrigger = false
    @State private var selectedCourse: Course?
    @State private var showCreateSection = false
    @State private var showTransferStudent = false
    @State private var searchText = ""

    /// All unique base course names (grouping sections together).
    private var courseGroups: [CourseGroup] {
        let allCourses = viewModel.courses + viewModel.allAvailableCourses
        var groups: [String: [Course]] = [:]

        for course in allCourses {
            let baseName = sectionBaseName(for: course)
            groups[baseName, default: []].append(course)
        }

        return groups.map { CourseGroup(baseName: $0.key, sections: $0.value.sorted { ($0.sectionNumber ?? 0) < ($1.sectionNumber ?? 0) }) }
            .sorted { $0.baseName < $1.baseName }
            .filter { group in
                searchText.isEmpty || group.baseName.localizedStandardContains(searchText)
            }
    }

    var body: some View {
        NavigationStack {
            Group {
                if courseGroups.isEmpty && searchText.isEmpty {
                    ContentUnavailableView(
                        "No Courses Yet",
                        systemImage: "rectangle.on.rectangle.slash",
                        description: Text("Create courses to manage sections and enrollment")
                    )
                } else if courseGroups.isEmpty {
                    ContentUnavailableView(
                        "No Matching Courses",
                        systemImage: "magnifyingglass",
                        description: Text("No courses match \"\(searchText)\"")
                    )
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(courseGroups) { group in
                                courseGroupCard(group)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)
                        .padding(.bottom, 20)
                    }
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Class Sections")
            .searchable(text: $searchText, prompt: "Search courses")
            .sheet(isPresented: $showCreateSection) {
                if let course = selectedCourse {
                    CreateSectionSheet(viewModel: viewModel, sourceCourse: course)
                }
            }
            .sheet(isPresented: $showTransferStudent) {
                if let course = selectedCourse {
                    TransferStudentSheet(viewModel: viewModel, course: course)
                }
            }
            .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
        }
    }

    // MARK: - Course Group Card

    private func courseGroupCard(_ group: CourseGroup) -> some View {
        let accentColor = Theme.courseColor(group.sections.first?.colorName ?? "purple")

        return VStack(alignment: .leading, spacing: 12) {
            // Group header
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(accentColor.opacity(0.15))
                        .frame(width: 40, height: 40)
                    Image(systemName: group.sections.first?.iconSystemName ?? "book.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(accentColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(group.baseName)
                        .font(.headline)
                        .foregroundStyle(Color(.label))
                        .lineLimit(1)

                    Text("\(group.sections.count) section\(group.sections.count == 1 ? "" : "s") | \(group.totalEnrollment) total students")
                        .font(.caption)
                        .foregroundStyle(Color(.secondaryLabel))
                }

                Spacer()

                Button {
                    hapticTrigger.toggle()
                    selectedCourse = group.sections.first
                    showCreateSection = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(accentColor)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Add new section for \(group.baseName)")
            }

            // Section rows
            ForEach(group.sections) { section in
                sectionRow(section, accentColor: accentColor)
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(accentColor.opacity(0.2), lineWidth: 1)
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(group.baseName), \(group.sections.count) sections, \(group.totalEnrollment) total students")
    }

    // MARK: - Section Row

    private func sectionRow(_ section: Course, accentColor: Color) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                // Section badge
                VStack(spacing: 2) {
                    if let num = section.sectionNumber {
                        Text("S\(num)")
                            .font(.caption.bold())
                            .foregroundStyle(.white)
                            .frame(width: 32, height: 24)
                            .background(accentColor.gradient, in: .rect(cornerRadius: 6))
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        if let label = section.sectionLabel {
                            Text(label)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(Color(.label))
                        } else {
                            Text(section.title)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(Color(.label))
                                .lineLimit(1)
                        }
                    }

                    Text(section.teacherName)
                        .font(.caption)
                        .foregroundStyle(Color(.secondaryLabel))
                }

                Spacer()

                // Enrollment badge
                enrollmentBadge(current: section.enrolledStudentCount, max: section.maxCapacity)

                // Transfer button
                Button {
                    hapticTrigger.toggle()
                    selectedCourse = section
                    showTransferStudent = true
                } label: {
                    Image(systemName: "arrow.left.arrow.right")
                        .font(.caption)
                        .foregroundStyle(accentColor)
                        .padding(6)
                        .background(accentColor.opacity(0.1), in: .circle)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Transfer student from \(section.sectionLabel ?? section.title)")
            }

            // Capacity bar
            EnrollmentCapacityBar(
                current: section.enrolledStudentCount,
                max: section.maxCapacity
            )
        }
        .padding(10)
        .background(Color(.tertiarySystemFill), in: .rect(cornerRadius: 12))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(section.sectionLabel ?? section.title), \(section.teacherName), \(section.enrolledStudentCount) of \(section.maxCapacity) students")
    }

    // MARK: - Enrollment Badge

    private func enrollmentBadge(current: Int, max: Int) -> some View {
        let percentage = max > 0 ? Double(current) / Double(max) * 100 : 0
        let color: Color = percentage >= 95 ? .red : percentage >= 80 ? .orange : .green

        return Text("\(current)/\(max)")
            .font(.caption2.bold())
            .monospacedDigit()
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(.capsule)
            .accessibilityLabel("\(current) of \(max) students enrolled")
    }

    // MARK: - Helpers

    private func sectionBaseName(for course: Course) -> String {
        guard course.sectionNumber != nil else { return course.title }
        var name = course.title
        if let range = name.range(of: " - Section \\d+", options: .regularExpression) {
            name = String(name[name.startIndex..<range.lowerBound])
        }
        if let range = name.range(of: " \\(Period \\d+\\)", options: .regularExpression) {
            name = String(name[name.startIndex..<range.lowerBound])
        }
        return name
    }
}

// MARK: - Course Group Model

private struct CourseGroup: Identifiable {
    let baseName: String
    let sections: [Course]

    var id: String { baseName }

    var totalEnrollment: Int {
        sections.reduce(0) { $0 + $1.enrolledStudentCount }
    }

    var totalCapacity: Int {
        sections.reduce(0) { $0 + $1.maxCapacity }
    }
}

// MARK: - Create Section Sheet

private struct CreateSectionSheet: View {
    let viewModel: AppViewModel
    let sourceCourse: Course
    @Environment(\.dismiss) private var dismiss

    @State private var sectionNumber: Int = 1
    @State private var sectionLabel = ""
    @State private var maxCapacity: Int = 30
    @State private var teacherName = ""
    @State private var hapticTrigger = false

    private var accentColor: Color {
        Theme.courseColor(sourceCourse.colorName)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Source course info
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(accentColor.opacity(0.15))
                                .frame(width: 40, height: 40)
                            Image(systemName: sourceCourse.iconSystemName)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(accentColor)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("New Section of")
                                .font(.caption)
                                .foregroundStyle(Color(.secondaryLabel))
                            Text(sourceCourse.title)
                                .font(.headline)
                                .foregroundStyle(Color(.label))
                                .lineLimit(1)
                        }

                        Spacer()
                    }
                    .padding(14)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                    // Section details
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Section Details", systemImage: "rectangle.on.rectangle")
                            .font(.headline)

                        VStack(spacing: 12) {
                            Stepper("Section Number: \(sectionNumber)", value: $sectionNumber, in: 1...20)
                                .font(.subheadline)
                                .accessibilityLabel("Section number: \(sectionNumber)")
                                .accessibilityHint("Adjustable, from 1 to 20")

                            Divider()

                            VStack(alignment: .leading, spacing: 8) {
                                Text("Section Label")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                TextField("e.g. Period 1, Block A", text: $sectionLabel)
                                    .textFieldStyle(.roundedBorder)
                                    .accessibilityLabel("Section label")
                            }

                            Divider()

                            Stepper("Max Capacity: \(maxCapacity)", value: $maxCapacity, in: 1...200)
                                .font(.subheadline)
                                .accessibilityLabel("Maximum capacity: \(maxCapacity)")
                                .accessibilityHint("Adjustable, from 1 to 200 students")

                            Divider()

                            VStack(alignment: .leading, spacing: 8) {
                                Text("Teacher (optional)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                TextField("Default: \(sourceCourse.teacherName)", text: $teacherName)
                                    .textFieldStyle(.roundedBorder)
                                    .accessibilityLabel("Teacher name")
                            }
                        }
                    }
                    .padding(14)
                    .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))

                    // Create button
                    Button {
                        hapticTrigger.toggle()
                        let label = sectionLabel.isEmpty ? "Section \(sectionNumber)" : sectionLabel
                        let teacher = teacherName.isEmpty ? nil : teacherName

                        viewModel.createSection(
                            from: sourceCourse,
                            sectionNumber: sectionNumber,
                            sectionLabel: label,
                            maxCapacity: maxCapacity,
                            teacherName: teacher
                        )

                        dismiss()
                    } label: {
                        Label("Create Section", systemImage: "plus.circle.fill")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(accentColor)
                    .sensoryFeedback(.success, trigger: hapticTrigger)
                    .accessibilityLabel("Create section")
                    .accessibilityHint("Double tap to create the new section")
                }
                .padding(.horizontal)
                .padding(.bottom, 30)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("New Section")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Transfer Student Sheet

private struct TransferStudentSheet: View {
    let viewModel: AppViewModel
    let course: Course
    @Environment(\.dismiss) private var dismiss

    @State private var studentName = ""
    @State private var selectedTargetSection: UUID?
    @State private var hapticTrigger = false

    private var accentColor: Color {
        Theme.courseColor(course.colorName)
    }

    /// Other sections of the same course to transfer to.
    private var targetSections: [Course] {
        let baseName = sectionBaseName(for: course)
        let allCourses = viewModel.courses + viewModel.allAvailableCourses
        return allCourses.filter { c in
            c.id != course.id && sectionBaseName(for: c) == baseName && c.sectionNumber != nil
        }
        .sorted { ($0.sectionNumber ?? 0) < ($1.sectionNumber ?? 0) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Source section info
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(accentColor.opacity(0.15))
                                .frame(width: 40, height: 40)
                            Image(systemName: "arrow.left.arrow.right")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(accentColor)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Transfer from")
                                .font(.caption)
                                .foregroundStyle(Color(.secondaryLabel))
                            Text(course.sectionLabel ?? course.title)
                                .font(.headline)
                                .foregroundStyle(Color(.label))
                                .lineLimit(1)
                            Text("\(course.enrolledStudentCount)/\(course.maxCapacity) students")
                                .font(.caption)
                                .foregroundStyle(Color(.secondaryLabel))
                        }

                        Spacer()
                    }
                    .padding(14)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                    // Transfer details
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Transfer Details", systemImage: "person.badge.arrow.right")
                            .font(.headline)

                        VStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Student Name")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                TextField("Enter student name", text: $studentName)
                                    .textFieldStyle(.roundedBorder)
                                    .accessibilityLabel("Student name to transfer")
                            }

                            Divider()

                            VStack(alignment: .leading, spacing: 8) {
                                Text("Transfer To")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                if targetSections.isEmpty {
                                    HStack(spacing: 8) {
                                        Image(systemName: "exclamationmark.triangle")
                                            .foregroundStyle(.orange)
                                        Text("No other sections available. Create another section first.")
                                            .font(.caption)
                                            .foregroundStyle(Color(.secondaryLabel))
                                    }
                                    .padding(10)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color.orange.opacity(0.08), in: .rect(cornerRadius: 8))
                                } else {
                                    ForEach(targetSections) { target in
                                        Button {
                                            hapticTrigger.toggle()
                                            withAnimation(.smooth) {
                                                selectedTargetSection = target.id
                                            }
                                        } label: {
                                            HStack(spacing: 10) {
                                                Image(systemName: selectedTargetSection == target.id
                                                    ? "checkmark.circle.fill"
                                                    : "circle")
                                                    .font(.title3)
                                                    .foregroundStyle(
                                                        selectedTargetSection == target.id
                                                            ? accentColor
                                                            : Color(.tertiaryLabel)
                                                    )

                                                VStack(alignment: .leading, spacing: 2) {
                                                    Text(target.sectionLabel ?? "Section \(target.sectionNumber ?? 0)")
                                                        .font(.subheadline)
                                                        .foregroundStyle(Color(.label))
                                                    Text("\(target.teacherName) | \(target.enrolledStudentCount)/\(target.maxCapacity)")
                                                        .font(.caption2)
                                                        .foregroundStyle(Color(.secondaryLabel))
                                                }

                                                Spacer()

                                                if target.isFull {
                                                    Text("Full")
                                                        .font(.caption2.bold())
                                                        .padding(.horizontal, 6)
                                                        .padding(.vertical, 2)
                                                        .background(.red.opacity(0.15))
                                                        .foregroundStyle(.red)
                                                        .clipShape(.capsule)
                                                }
                                            }
                                            .padding(10)
                                            .background(
                                                selectedTargetSection == target.id
                                                    ? accentColor.opacity(0.08)
                                                    : Color(.tertiarySystemFill),
                                                in: .rect(cornerRadius: 10)
                                            )
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 10)
                                                    .strokeBorder(
                                                        selectedTargetSection == target.id
                                                            ? accentColor.opacity(0.3)
                                                            : Color.clear,
                                                        lineWidth: 1
                                                    )
                                            )
                                        }
                                        .buttonStyle(.plain)
                                        .disabled(target.isFull)
                                        .sensoryFeedback(.selection, trigger: hapticTrigger)
                                        .accessibilityLabel("\(target.sectionLabel ?? "Section \(target.sectionNumber ?? 0)"), \(target.enrolledStudentCount) of \(target.maxCapacity) students")
                                    }
                                }
                            }
                        }
                    }
                    .padding(14)
                    .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))

                    // Transfer button
                    Button {
                        hapticTrigger.toggle()
                        guard let targetId = selectedTargetSection,
                              !studentName.trimmingCharacters(in: .whitespaces).isEmpty else { return }

                        viewModel.transferStudent(
                            studentName: studentName.trimmingCharacters(in: .whitespaces),
                            fromSection: course.id,
                            toSection: targetId
                        )

                        dismiss()
                    } label: {
                        Label("Transfer Student", systemImage: "arrow.right.circle.fill")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(accentColor)
                    .disabled(selectedTargetSection == nil || studentName.trimmingCharacters(in: .whitespaces).isEmpty)
                    .sensoryFeedback(.success, trigger: hapticTrigger)
                    .accessibilityLabel("Transfer student")
                    .accessibilityHint(selectedTargetSection == nil ? "Select a target section first" : "Double tap to transfer")
                }
                .padding(.horizontal)
                .padding(.bottom, 30)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Transfer Student")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func sectionBaseName(for course: Course) -> String {
        guard course.sectionNumber != nil else { return course.title }
        var name = course.title
        if let range = name.range(of: " - Section \\d+", options: .regularExpression) {
            name = String(name[name.startIndex..<range.lowerBound])
        }
        if let range = name.range(of: " \\(Period \\d+\\)", options: .regularExpression) {
            name = String(name[name.startIndex..<range.lowerBound])
        }
        return name
    }
}
