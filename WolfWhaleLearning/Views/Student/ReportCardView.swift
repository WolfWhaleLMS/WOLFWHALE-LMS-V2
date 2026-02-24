import SwiftUI
import UIKit

struct ReportCardView: View {
    @Bindable var viewModel: AppViewModel
    @State private var pdfURL: URL?
    @State private var isGenerating = false
    @State private var showShareSheet = false
    @State private var hapticTrigger = false

    private var studentName: String {
        viewModel.currentUser?.fullName ?? "Student"
    }

    private var gpa: Double {
        guard !viewModel.grades.isEmpty else { return 0 }
        return viewModel.grades.reduce(0) { $0 + $1.numericGrade } / Double(viewModel.grades.count)
    }

    private var gpaLetterGrade: String {
        switch gpa {
        case 93...: return "A"
        case 90..<93: return "A-"
        case 87..<90: return "B+"
        case 83..<87: return "B"
        case 80..<83: return "B-"
        case 77..<80: return "C+"
        case 73..<77: return "C"
        case 70..<73: return "C-"
        case 67..<70: return "D+"
        case 60..<67: return "D"
        default: return "F"
        }
    }

    private var presentCount: Int {
        viewModel.attendance.filter { $0.status == .present }.count
    }

    private var absentCount: Int {
        viewModel.attendance.filter { $0.status == .absent }.count
    }

    private var tardyCount: Int {
        viewModel.attendance.filter { $0.status == .tardy }.count
    }

    private var excusedCount: Int {
        viewModel.attendance.filter { $0.status == .excused }.count
    }

    private var attendanceRate: Double {
        let total = viewModel.attendance.count
        guard total > 0 else { return 100 }
        return Double(presentCount + excusedCount) / Double(total) * 100
    }

    private var feedbackItems: [(courseName: String, assignmentTitle: String, feedback: String)] {
        viewModel.assignments.compactMap { assignment in
            guard let feedback = assignment.feedback, !feedback.isEmpty else { return nil }
            return (courseName: assignment.courseName, assignmentTitle: assignment.title, feedback: feedback)
        }
    }

    private var schoolYear: String {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: Date())
        let month = calendar.component(.month, from: Date())
        if month >= 8 {
            return "\(year)-\(year + 1)"
        } else {
            return "\(year - 1)-\(year)"
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                headerSection
                courseGradesSection
                gpaSection
                attendanceSection
                if !feedbackItems.isEmpty {
                    commentsSection
                }
                exportButton
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Report Card")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showShareSheet) {
            if let url = pdfURL {
                ShareSheetView(activityItems: [url])
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "graduationcap.fill")
                .font(.system(size: 36))
                .foregroundStyle(.indigo)

            Text("WolfWhale LMS")
                .font(.title2.bold())

            Text("Official Report Card")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Divider()
                .padding(.horizontal, 40)

            VStack(spacing: 6) {
                infoRow(label: "Student", value: studentName)
                infoRow(label: "School Year", value: schoolYear)
                infoRow(label: "Date Generated", value: Date().formatted(date: .long, time: .omitted))
            }
            .padding(.top, 4)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline.bold())
        }
    }

    // MARK: - Course Grades Table

    private var courseGradesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Course Grades", systemImage: "tablecells")
                .font(.headline)

            VStack(spacing: 0) {
                // Table header
                HStack {
                    Text("Course")
                        .font(.caption.bold())
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("Grade")
                        .font(.caption.bold())
                        .frame(width: 50)
                    Text("Percent")
                        .font(.caption.bold())
                        .frame(width: 65)
                    Text("Status")
                        .font(.caption.bold())
                        .frame(width: 65)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.indigo.opacity(0.1))

                if viewModel.grades.isEmpty {
                    Text("No grades available")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                } else {
                    ForEach(Array(viewModel.grades.enumerated()), id: \.element.id) { index, grade in
                        HStack {
                            Text(grade.courseName)
                                .font(.subheadline)
                                .lineLimit(1)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text(grade.letterGrade)
                                .font(.subheadline.bold())
                                .foregroundStyle(Theme.gradeColor(grade.numericGrade))
                                .frame(width: 50)
                            Text(String(format: "%.1f%%", grade.numericGrade))
                                .font(.subheadline)
                                .frame(width: 65)
                            Text(statusForGrade(grade.numericGrade))
                                .font(.caption2)
                                .foregroundStyle(statusColorForGrade(grade.numericGrade))
                                .frame(width: 65)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(index % 2 == 0 ? Color.clear : Color(.systemGray6).opacity(0.5))
                    }
                }
            }
            .clipShape(.rect(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(.systemGray4), lineWidth: 0.5)
            )
        }
        .padding(16)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

    // MARK: - GPA Summary

    private var gpaSection: some View {
        VStack(spacing: 16) {
            Label("GPA Summary", systemImage: "chart.bar.fill")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 24) {
                VStack(spacing: 6) {
                    ZStack {
                        Circle()
                            .stroke(Color(.systemGray4), lineWidth: 8)
                        Circle()
                            .trim(from: 0, to: gpa / 100)
                            .stroke(Theme.gradeColor(gpa), style: StrokeStyle(lineWidth: 8, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        VStack(spacing: 2) {
                            Text(String(format: "%.1f", gpa))
                                .font(.title3.bold())
                            Text(gpaLetterGrade)
                                .font(.caption.bold())
                                .foregroundStyle(Theme.gradeColor(gpa))
                        }
                    }
                    .frame(width: 90, height: 90)
                }

                VStack(alignment: .leading, spacing: 8) {
                    summaryStatRow(label: "Courses", value: "\(viewModel.grades.count)")
                    summaryStatRow(label: "Cumulative GPA", value: String(format: "%.1f%%", gpa))
                    summaryStatRow(label: "Letter Grade", value: gpaLetterGrade)
                    summaryStatRow(label: "Standing", value: standingText)
                }

                Spacer()
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

    private var standingText: String {
        switch gpa {
        case 90...: return "Honor Roll"
        case 80..<90: return "Good Standing"
        case 70..<80: return "Satisfactory"
        default: return "Needs Improvement"
        }
    }

    private func summaryStatRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.caption.bold())
        }
    }

    // MARK: - Attendance Summary

    private var attendanceSection: some View {
        VStack(spacing: 16) {
            Label("Attendance Summary", systemImage: "calendar.badge.checkmark")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 16) {
                attendanceStat(icon: "checkmark.circle.fill", label: "Present", count: presentCount, color: .green)
                attendanceStat(icon: "xmark.circle.fill", label: "Absent", count: absentCount, color: .red)
                attendanceStat(icon: "clock.fill", label: "Tardy", count: tardyCount, color: .orange)
                attendanceStat(icon: "doc.text.fill", label: "Excused", count: excusedCount, color: .blue)
            }

            HStack {
                Text("Attendance Rate")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(String(format: "%.1f%%", attendanceRate))
                    .font(.subheadline.bold())
                    .foregroundStyle(attendanceRate >= 90 ? .green : (attendanceRate >= 80 ? .orange : .red))
            }
            .padding(.top, 4)
        }
        .padding(16)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

    private func attendanceStat(icon: String, label: String, count: Int, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
            Text("\(count)")
                .font(.headline)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Teacher Comments

    private var commentsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Teacher Comments", systemImage: "text.bubble.fill")
                .font(.headline)

            ForEach(Array(feedbackItems.enumerated()), id: \.offset) { _, item in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(item.courseName)
                            .font(.caption.bold())
                            .foregroundStyle(.indigo)
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(item.assignmentTitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Text("\"\(item.feedback)\"")
                        .font(.subheadline)
                        .italic()
                        .foregroundStyle(.primary)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.systemGray6).opacity(0.5), in: .rect(cornerRadius: 10))
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

    // MARK: - Export Button

    private var exportButton: some View {
        Button {
            hapticTrigger.toggle()
            generatePDF()
        } label: {
            HStack(spacing: 8) {
                if isGenerating {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "square.and.arrow.up")
                }
                Text(isGenerating ? "Generating PDF..." : "Export Report Card")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
        }
        .buttonStyle(.borderedProminent)
        .tint(.indigo)
        .disabled(isGenerating)
        .hapticFeedback(.impact(weight: .medium), trigger: hapticTrigger)
        .padding(.top, 4)
    }

    // MARK: - Helpers

    private func statusForGrade(_ grade: Double) -> String {
        switch grade {
        case 90...: return "Excellent"
        case 80..<90: return "Good"
        case 70..<80: return "Fair"
        default: return "At Risk"
        }
    }

    private func statusColorForGrade(_ grade: Double) -> Color {
        switch grade {
        case 90...: return .green
        case 80..<90: return .blue
        case 70..<80: return .orange
        default: return .red
        }
    }

    // MARK: - PDF Generation

    private func generatePDF() {
        isGenerating = true

        let grades = viewModel.grades
        let attendance = viewModel.attendance
        let assignments = viewModel.assignments
        let capturedStudentName = studentName
        let capturedSchoolYear = schoolYear
        let capturedGPA = gpa
        let capturedGPALetterGrade = gpaLetterGrade
        let capturedStandingText = standingText

        Task.detached(priority: .userInitiated) {
            let pageWidth: CGFloat = 612  // US Letter
            let pageHeight: CGFloat = 792
            let margin: CGFloat = 50
            let contentWidth = pageWidth - (margin * 2)

            // Pure helper – avoids implicit self capture inside @Sendable closure
            func pdfStatusForGrade(_ grade: Double) -> String {
                switch grade {
                case 90...: return "Excellent"
                case 80..<90: return "Good"
                case 70..<80: return "Fair"
                default: return "At Risk"
                }
            }

            let format = UIGraphicsPDFRendererFormat()
            let renderer = UIGraphicsPDFRenderer(
                bounds: CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight),
                format: format
            )

            let data = renderer.pdfData { context in
                context.beginPage()
                var yOffset: CGFloat = margin

                // --- School Header ---
                let headerFont = UIFont.systemFont(ofSize: 22, weight: .bold)
                let sectionFont = UIFont.systemFont(ofSize: 14, weight: .bold)
                let bodyFont = UIFont.systemFont(ofSize: 11, weight: .regular)
                let bodyBoldFont = UIFont.systemFont(ofSize: 11, weight: .semibold)
                let smallFont = UIFont.systemFont(ofSize: 9, weight: .regular)

                let headerText = "WolfWhale LMS - Report Card" as NSString
                let headerAttributes: [NSAttributedString.Key: Any] = [
                    .font: headerFont,
                    .foregroundColor: UIColor.systemPink
                ]
                let headerSize = headerText.size(withAttributes: headerAttributes)
                headerText.draw(
                    at: CGPoint(x: (pageWidth - headerSize.width) / 2, y: yOffset),
                    withAttributes: headerAttributes
                )
                yOffset += headerSize.height + 8

                // Divider line
                let lineContext = context.cgContext
                lineContext.setStrokeColor(UIColor.systemPink.cgColor)
                lineContext.setLineWidth(2)
                lineContext.move(to: CGPoint(x: margin, y: yOffset))
                lineContext.addLine(to: CGPoint(x: pageWidth - margin, y: yOffset))
                lineContext.strokePath()
                yOffset += 16

                // Student Info
                let infoAttrs: [NSAttributedString.Key: Any] = [.font: bodyFont, .foregroundColor: UIColor.darkGray]
                let infoBoldAttrs: [NSAttributedString.Key: Any] = [.font: bodyBoldFont, .foregroundColor: UIColor.black]

                func drawInfoRow(_ label: String, _ value: String, at y: CGFloat) -> CGFloat {
                    let labelStr = label as NSString
                    let valueStr = value as NSString
                    labelStr.draw(at: CGPoint(x: margin, y: y), withAttributes: infoAttrs)
                    valueStr.draw(at: CGPoint(x: margin + 140, y: y), withAttributes: infoBoldAttrs)
                    return y + 18
                }

                yOffset = drawInfoRow("Student Name:", capturedStudentName, at: yOffset)
                yOffset = drawInfoRow("School Year:", capturedSchoolYear, at: yOffset)
                yOffset = drawInfoRow("Date Generated:", Date().formatted(date: .long, time: .omitted), at: yOffset)
                yOffset += 16

                // --- Course Grades Table ---
                let sectionAttrs: [NSAttributedString.Key: Any] = [.font: sectionFont, .foregroundColor: UIColor.black]
                ("Course Grades" as NSString).draw(at: CGPoint(x: margin, y: yOffset), withAttributes: sectionAttrs)
                yOffset += 24

                // Table header
                let colCourse: CGFloat = margin
                let colGrade: CGFloat = margin + contentWidth * 0.55
                let colPercent: CGFloat = margin + contentWidth * 0.70
                let colStatus: CGFloat = margin + contentWidth * 0.85
                let tableHeaderAttrs: [NSAttributedString.Key: Any] = [.font: bodyBoldFont, .foregroundColor: UIColor.white]

                let headerRowHeight: CGFloat = 22
                lineContext.setFillColor(UIColor.systemPink.cgColor)
                lineContext.fill(CGRect(x: margin, y: yOffset, width: contentWidth, height: headerRowHeight))

                ("Course" as NSString).draw(at: CGPoint(x: colCourse + 6, y: yOffset + 4), withAttributes: tableHeaderAttrs)
                ("Grade" as NSString).draw(at: CGPoint(x: colGrade + 6, y: yOffset + 4), withAttributes: tableHeaderAttrs)
                ("Percent" as NSString).draw(at: CGPoint(x: colPercent + 6, y: yOffset + 4), withAttributes: tableHeaderAttrs)
                ("Status" as NSString).draw(at: CGPoint(x: colStatus + 6, y: yOffset + 4), withAttributes: tableHeaderAttrs)
                yOffset += headerRowHeight

                // Table rows
                let rowAttrs: [NSAttributedString.Key: Any] = [.font: bodyFont, .foregroundColor: UIColor.darkGray]
                let rowBoldAttrs: [NSAttributedString.Key: Any] = [.font: bodyBoldFont, .foregroundColor: UIColor.black]
                let rowHeight: CGFloat = 22

                for (index, grade) in grades.enumerated() {
                    if index % 2 == 0 {
                        lineContext.setFillColor(UIColor.systemGray6.cgColor)
                        lineContext.fill(CGRect(x: margin, y: yOffset, width: contentWidth, height: rowHeight))
                    }

                    // Table borders
                    lineContext.setStrokeColor(UIColor.systemGray4.cgColor)
                    lineContext.setLineWidth(0.5)
                    lineContext.stroke(CGRect(x: margin, y: yOffset, width: contentWidth, height: rowHeight))

                    (grade.courseName as NSString).draw(at: CGPoint(x: colCourse + 6, y: yOffset + 4), withAttributes: rowAttrs)
                    (grade.letterGrade as NSString).draw(at: CGPoint(x: colGrade + 6, y: yOffset + 4), withAttributes: rowBoldAttrs)
                    (String(format: "%.1f%%", grade.numericGrade) as NSString).draw(at: CGPoint(x: colPercent + 6, y: yOffset + 4), withAttributes: rowAttrs)
                    (pdfStatusForGrade(grade.numericGrade) as NSString).draw(at: CGPoint(x: colStatus + 6, y: yOffset + 4), withAttributes: rowAttrs)

                    yOffset += rowHeight
                }

                // Table bottom border
                lineContext.setStrokeColor(UIColor.systemGray4.cgColor)
                lineContext.setLineWidth(0.5)
                lineContext.move(to: CGPoint(x: margin, y: yOffset))
                lineContext.addLine(to: CGPoint(x: pageWidth - margin, y: yOffset))
                lineContext.strokePath()
                yOffset += 24

                // --- GPA Summary ---
                ("GPA Summary" as NSString).draw(at: CGPoint(x: margin, y: yOffset), withAttributes: sectionAttrs)
                yOffset += 22

                yOffset = drawInfoRow("Cumulative GPA:", String(format: "%.1f%%", capturedGPA), at: yOffset)
                yOffset = drawInfoRow("Letter Grade:", capturedGPALetterGrade, at: yOffset)
                yOffset = drawInfoRow("Academic Standing:", capturedStandingText, at: yOffset)
                yOffset = drawInfoRow("Courses Completed:", "\(grades.count)", at: yOffset)
                yOffset += 16

                // --- Attendance Summary ---
                let presentCnt = attendance.filter { $0.status == .present }.count
                let absentCnt = attendance.filter { $0.status == .absent }.count
                let tardyCnt = attendance.filter { $0.status == .tardy }.count
                let excusedCnt = attendance.filter { $0.status == .excused }.count
                let totalAtt = attendance.count
                let attRate = totalAtt > 0 ? Double(presentCnt + excusedCnt) / Double(totalAtt) * 100 : 100.0

                ("Attendance Summary" as NSString).draw(at: CGPoint(x: margin, y: yOffset), withAttributes: sectionAttrs)
                yOffset += 22

                yOffset = drawInfoRow("Total Days:", "\(totalAtt)", at: yOffset)
                yOffset = drawInfoRow("Present:", "\(presentCnt)", at: yOffset)
                yOffset = drawInfoRow("Absent:", "\(absentCnt)", at: yOffset)
                yOffset = drawInfoRow("Tardy:", "\(tardyCnt)", at: yOffset)
                yOffset = drawInfoRow("Excused:", "\(excusedCnt)", at: yOffset)
                yOffset = drawInfoRow("Attendance Rate:", String(format: "%.1f%%", attRate), at: yOffset)
                yOffset += 16

                // --- Teacher Comments ---
                let feedbackList = assignments.compactMap { a -> (String, String, String)? in
                    guard let fb = a.feedback, !fb.isEmpty else { return nil }
                    return (a.courseName, a.title, fb)
                }

                if !feedbackList.isEmpty {
                    // Check if we need a new page
                    if yOffset > pageHeight - 150 {
                        context.beginPage()
                        yOffset = margin
                    }

                    ("Teacher Comments" as NSString).draw(at: CGPoint(x: margin, y: yOffset), withAttributes: sectionAttrs)
                    yOffset += 22

                    let feedbackLabelAttrs: [NSAttributedString.Key: Any] = [.font: bodyBoldFont, .foregroundColor: UIColor.systemPink]
                    let feedbackBodyAttrs: [NSAttributedString.Key: Any] = [.font: bodyFont, .foregroundColor: UIColor.darkGray]

                    for item in feedbackList {
                        if yOffset > pageHeight - 80 {
                            context.beginPage()
                            yOffset = margin
                        }

                        let courseLabel = "\(item.0) - \(item.1)" as NSString
                        courseLabel.draw(at: CGPoint(x: margin, y: yOffset), withAttributes: feedbackLabelAttrs)
                        yOffset += 16

                        let feedbackText = "\"\(item.2)\"" as NSString
                        let feedbackRect = CGRect(x: margin + 10, y: yOffset, width: contentWidth - 20, height: 60)
                        feedbackText.draw(with: feedbackRect, options: .usesLineFragmentOrigin, attributes: feedbackBodyAttrs, context: nil)
                        let feedbackSize = feedbackText.boundingRect(with: CGSize(width: contentWidth - 20, height: .greatestFiniteMagnitude), options: .usesLineFragmentOrigin, attributes: feedbackBodyAttrs, context: nil)
                        yOffset += feedbackSize.height + 12
                    }
                }

                // --- Footer ---
                let footerAttrs: [NSAttributedString.Key: Any] = [.font: smallFont, .foregroundColor: UIColor.gray]
                let footerLine = "Generated by WolfWhale LMS on \(Date().formatted(date: .long, time: .shortened))" as NSString
                let footerSize = footerLine.size(withAttributes: footerAttrs)
                footerLine.draw(
                    at: CGPoint(x: (pageWidth - footerSize.width) / 2, y: pageHeight - margin + 10),
                    withAttributes: footerAttrs
                )

                // Footer divider
                lineContext.setStrokeColor(UIColor.systemGray4.cgColor)
                lineContext.setLineWidth(0.5)
                lineContext.move(to: CGPoint(x: margin, y: pageHeight - margin + 4))
                lineContext.addLine(to: CGPoint(x: pageWidth - margin, y: pageHeight - margin + 4))
                lineContext.strokePath()
            }

            // Save to temp file
            let tempDir = FileManager.default.temporaryDirectory
            let fileName = "ReportCard_\(capturedStudentName.replacingOccurrences(of: " ", with: "_"))_\(Date().formatted(.iso8601.year().month().day())).pdf"
            let fileURL = tempDir.appendingPathComponent(fileName)

            try? data.write(to: fileURL)

            Task { @MainActor in
                self.pdfURL = fileURL
                self.isGenerating = false
                self.showShareSheet = true
            }
        }
    }
}

// MARK: - Share Sheet (UIActivityViewController wrapper)

struct ShareSheetView: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
