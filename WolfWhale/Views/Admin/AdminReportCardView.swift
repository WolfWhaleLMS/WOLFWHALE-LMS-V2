import SwiftUI
import UIKit

struct AdminReportCardView: View {
    let viewModel: AppViewModel
    @State private var selectedTermId: UUID?
    @State private var reportCards: [ReportCardEntry] = []
    @State private var previewingCard: ReportCardEntry?
    @State private var isGenerating = false
    @State private var isExporting = false
    @State private var showShareSheet = false
    @State private var exportedPDFURL: URL?
    @State private var generationMessage = ""
    @State private var hapticTrigger = false
    @State private var filterText = ""

    private var config: AcademicCalendarConfig {
        viewModel.academicCalendarConfig
    }

    private var filteredCards: [ReportCardEntry] {
        if filterText.isEmpty {
            return reportCards
        }
        return reportCards.filter {
            $0.studentName.localizedCaseInsensitiveContains(filterText)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 16) {
                    termSelectionSection
                    if selectedTermId != nil {
                        actionButtons
                    }
                    if !reportCards.isEmpty {
                        reportCardListSection
                    } else if selectedTermId != nil && !isGenerating {
                        emptyState
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Report Cards")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $previewingCard) { card in
                NavigationStack {
                    ReportCardPreviewView(reportCard: card)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Done") { previewingCard = nil }
                            }
                            ToolbarItem(placement: .primaryAction) {
                                Button {
                                    hapticTrigger.toggle()
                                    exportSinglePDF(card)
                                } label: {
                                    Label("Export PDF", systemImage: "square.and.arrow.up")
                                }
                            }
                        }
                }
            }
            .sheet(isPresented: $showShareSheet) {
                if let url = exportedPDFURL {
                    ShareSheetView(activityItems: [url])
                }
            }
            .sensoryFeedback(.impact(weight: .medium), trigger: hapticTrigger)
            .task {
                await viewModel.loadAcademicCalendar()
            }
        }
        .requireRole(.admin, .superAdmin, currentRole: viewModel.currentUser?.role)
    }

    // MARK: - Term Selection

    private var termSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Select Term / Grading Period", systemImage: "calendar.badge.clock")
                .font(.headline)

            if config.terms.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                    Text("No terms configured. Set up the academic calendar first.")
                        .font(.subheadline)
                        .foregroundStyle(Color(.secondaryLabel))
                }
                .padding(14)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                ForEach(config.terms) { term in
                    Button {
                        hapticTrigger.toggle()
                        withAnimation {
                            selectedTermId = term.id
                            reportCards = []
                            generationMessage = ""
                        }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: selectedTermId == term.id ? "checkmark.circle.fill" : "circle")
                                .font(.title3)
                                .foregroundStyle(selectedTermId == term.id ? .indigo : Color(.tertiaryLabel))

                            VStack(alignment: .leading, spacing: 2) {
                                Text(term.name)
                                    .font(.subheadline.bold())
                                    .foregroundStyle(Color(.label))
                                Text(term.formattedDateRange)
                                    .font(.caption)
                                    .foregroundStyle(Color(.secondaryLabel))
                            }

                            Spacer()

                            if term.isActive {
                                Text("Current")
                                    .font(.caption2.bold())
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Color.green.opacity(0.15))
                                    .clipShape(Capsule())
                                    .foregroundStyle(.green)
                            }

                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(Color(.tertiaryLabel))
                        }
                        .padding(14)
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(selectedTermId == term.id ? Color.indigo.opacity(0.4) : Color.clear, lineWidth: 1.5)
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(term.name), \(term.formattedDateRange)\(term.isActive ? ", current term" : "")")
                    .accessibilityAddTraits(selectedTermId == term.id ? .isSelected : [])
                }
            }
        }
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: 10) {
            Button {
                hapticTrigger.toggle()
                generateAll()
            } label: {
                HStack(spacing: 10) {
                    if isGenerating {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "doc.on.doc.fill")
                    }
                    Text(isGenerating ? "Generating..." : "Generate All Report Cards")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(.indigo)
            .disabled(isGenerating || selectedTermId == nil)
            .accessibilityLabel("Generate all report cards for selected term")

            if !generationMessage.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text(generationMessage)
                        .font(.caption)
                        .foregroundStyle(Color(.secondaryLabel))
                }
            }

            if !reportCards.isEmpty {
                Button {
                    hapticTrigger.toggle()
                    exportAllPDFs()
                } label: {
                    HStack(spacing: 8) {
                        if isExporting {
                            ProgressView()
                                .tint(.indigo)
                        } else {
                            Image(systemName: "square.and.arrow.up.on.square")
                        }
                        Text(isExporting ? "Exporting..." : "Export All as PDF")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
                .buttonStyle(.bordered)
                .tint(.indigo)
                .disabled(isExporting)
                .accessibilityLabel("Export all report cards as PDF")
            }
        }
    }

    // MARK: - Report Card List

    private var reportCardListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Generated Report Cards (\(reportCards.count))", systemImage: "doc.richtext")
                    .font(.headline)
                Spacer()
            }

            if reportCards.count > 3 {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(Color(.secondaryLabel))
                    TextField("Search students...", text: $filterText)
                        .font(.subheadline)
                        .accessibilityLabel("Search students by name")
                }
                .padding(10)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            ForEach(filteredCards) { card in
                reportCardRow(card)
            }
        }
    }

    private func reportCardRow(_ card: ReportCardEntry) -> some View {
        Button {
            hapticTrigger.toggle()
            previewingCard = card
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "person.crop.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.indigo)

                VStack(alignment: .leading, spacing: 4) {
                    Text(card.studentName)
                        .font(.subheadline.bold())
                        .foregroundStyle(Color(.label))
                    HStack(spacing: 12) {
                        Label("GPA: \(String(format: "%.1f", card.gpa))%", systemImage: "chart.bar.fill")
                            .font(.caption)
                            .foregroundStyle(Color(.secondaryLabel))
                        Label(card.letterGrade, systemImage: "graduationcap")
                            .font(.caption.bold())
                            .foregroundStyle(Theme.gradeColor(card.gpa))
                        Label("\(card.courseEntries.count) courses", systemImage: "book.fill")
                            .font(.caption)
                            .foregroundStyle(Color(.secondaryLabel))
                    }
                }

                Spacer()

                Image(systemName: "eye.fill")
                    .font(.caption)
                    .foregroundStyle(Color(.tertiaryLabel))
            }
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.indigo.opacity(0.15), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(card.studentName), GPA \(String(format: "%.1f", card.gpa)) percent, \(card.letterGrade), \(card.courseEntries.count) courses")
        .accessibilityHint("Tap to preview report card")
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 40))
                .foregroundStyle(Color(.secondaryLabel))
            Text("No report cards generated yet")
                .font(.subheadline)
                .foregroundStyle(Color(.secondaryLabel))
            Text("Select a term and tap 'Generate All' to create report cards.")
                .font(.caption)
                .foregroundStyle(Color(.tertiaryLabel))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Actions

    private func generateAll() {
        guard let termId = selectedTermId else { return }
        isGenerating = true
        reportCards = viewModel.generateAllReportCards(termId: termId)
        isGenerating = false
        generationMessage = "Generated \(reportCards.count) report card\(reportCards.count == 1 ? "" : "s")"
    }

    private func exportSinglePDF(_ card: ReportCardEntry) {
        isExporting = true
        let url = ReportCardPDFGenerator.generatePDF(for: card)
        exportedPDFURL = url
        isExporting = false
        if url != nil {
            showShareSheet = true
        }
    }

    private func exportAllPDFs() {
        isExporting = true
        // Generate a combined PDF or first card as demonstration
        if let firstCard = reportCards.first {
            let url = ReportCardPDFGenerator.generatePDF(for: firstCard, batchCards: reportCards)
            exportedPDFURL = url
            isExporting = false
            if url != nil {
                showShareSheet = true
            }
        } else {
            isExporting = false
        }
    }
}

// MARK: - Report Card Preview View

struct ReportCardPreviewView: View {
    let reportCard: ReportCardEntry

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                headerSection
                courseGradesTable
                gpaSummary
                attendanceSummary
                if reportCard.courseEntries.contains(where: { $0.teacherComment != nil }) {
                    commentsSection
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Report Card Preview")
        .navigationBarTitleDisplayMode(.inline)
    }

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

            Divider().padding(.horizontal, 40)

            VStack(spacing: 6) {
                previewInfoRow(label: "Student", value: reportCard.studentName)
                previewInfoRow(label: "Term", value: reportCard.termName)
                previewInfoRow(label: "Date Generated", value: Date().formatted(date: .long, time: .omitted))
            }
            .padding(.top, 4)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Report card for \(reportCard.studentName), term \(reportCard.termName)")
    }

    private func previewInfoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline.bold())
        }
    }

    private var courseGradesTable: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Course Grades", systemImage: "tablecells")
                .font(.headline)

            VStack(spacing: 0) {
                HStack {
                    Text("Course")
                        .font(.caption.bold())
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("Teacher")
                        .font(.caption.bold())
                        .frame(width: 80)
                    Text("Grade")
                        .font(.caption.bold())
                        .frame(width: 50)
                    Text("Percent")
                        .font(.caption.bold())
                        .frame(width: 65)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.indigo.opacity(0.1))

                if reportCard.courseEntries.isEmpty {
                    Text("No course data available")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                } else {
                    ForEach(Array(reportCard.courseEntries.enumerated()), id: \.element.id) { index, entry in
                        HStack {
                            Text(entry.courseName)
                                .font(.subheadline)
                                .lineLimit(1)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text(entry.teacherName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .frame(width: 80)
                            Text(entry.letterGrade)
                                .font(.subheadline.bold())
                                .foregroundStyle(Theme.gradeColor(entry.numericGrade))
                                .frame(width: 50)
                            Text(String(format: "%.1f%%", entry.numericGrade))
                                .font(.subheadline)
                                .frame(width: 65)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(index % 2 == 0 ? Color.clear : Color(.systemGray6).opacity(0.5))
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(.systemGray4), lineWidth: 0.5)
            )
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var gpaSummary: some View {
        VStack(spacing: 16) {
            Label("GPA Summary", systemImage: "chart.bar.fill")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 24) {
                ZStack {
                    Circle()
                        .stroke(Color(.systemGray4), lineWidth: 8)
                    Circle()
                        .trim(from: 0, to: reportCard.gpa / 100)
                        .stroke(Theme.gradeColor(reportCard.gpa), style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: 2) {
                        Text(String(format: "%.1f", reportCard.gpa))
                            .font(.title3.bold())
                        Text(reportCard.letterGrade)
                            .font(.caption.bold())
                            .foregroundStyle(Theme.gradeColor(reportCard.gpa))
                    }
                }
                .frame(width: 90, height: 90)

                VStack(alignment: .leading, spacing: 8) {
                    gpaStat(label: "Courses", value: "\(reportCard.courseEntries.count)")
                    gpaStat(label: "Cumulative GPA", value: String(format: "%.1f%%", reportCard.gpa))
                    gpaStat(label: "Letter Grade", value: reportCard.letterGrade)
                    gpaStat(label: "Standing", value: reportCard.standing)
                }

                Spacer()
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("GPA \(String(format: "%.1f", reportCard.gpa)) percent, letter grade \(reportCard.letterGrade), \(reportCard.standing)")
    }

    private func gpaStat(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.caption.bold())
        }
    }

    private var attendanceSummary: some View {
        VStack(spacing: 16) {
            Label("Attendance Summary", systemImage: "calendar.badge.checkmark")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            let att = reportCard.attendanceSummary
            HStack(spacing: 16) {
                attendanceStat(icon: "checkmark.circle.fill", label: "Present", count: att.presentCount, color: .green)
                attendanceStat(icon: "xmark.circle.fill", label: "Absent", count: att.absentCount, color: .red)
                attendanceStat(icon: "clock.fill", label: "Tardy", count: att.tardyCount, color: .orange)
                attendanceStat(icon: "doc.text.fill", label: "Excused", count: att.excusedCount, color: .blue)
            }

            HStack {
                Text("Attendance Rate")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(String(format: "%.1f%%", att.attendanceRate))
                    .font(.subheadline.bold())
                    .foregroundStyle(att.attendanceRate >= 90 ? .green : (att.attendanceRate >= 80 ? .orange : .red))
            }
            .padding(.top, 4)
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Attendance rate \(String(format: "%.1f", reportCard.attendanceSummary.attendanceRate)) percent, \(reportCard.attendanceSummary.presentCount) present, \(reportCard.attendanceSummary.absentCount) absent")
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

    private var commentsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Teacher Comments", systemImage: "text.bubble.fill")
                .font(.headline)

            ForEach(reportCard.courseEntries.filter { $0.teacherComment != nil }) { entry in
                VStack(alignment: .leading, spacing: 6) {
                    Text(entry.courseName)
                        .font(.caption.bold())
                        .foregroundStyle(.indigo)
                    if let comment = entry.teacherComment {
                        Text("\"\(comment)\"")
                            .font(.subheadline)
                            .italic()
                            .foregroundStyle(.primary)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.systemGray6).opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - PDF Generator

enum ReportCardPDFGenerator {

    static func generatePDF(for card: ReportCardEntry, batchCards: [ReportCardEntry]? = nil) -> URL? {
        let cards = batchCards ?? [card]

        let pageWidth: CGFloat = 612
        let pageHeight: CGFloat = 792
        let margin: CGFloat = 50
        let contentWidth = pageWidth - (margin * 2)

        let format = UIGraphicsPDFRendererFormat()
        let renderer = UIGraphicsPDFRenderer(
            bounds: CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight),
            format: format
        )

        let data = renderer.pdfData { context in
            for reportCard in cards {
                context.beginPage()
                var yOffset: CGFloat = margin

                let headerFont = UIFont.systemFont(ofSize: 22, weight: .bold)
                let sectionFont = UIFont.systemFont(ofSize: 14, weight: .bold)
                let bodyFont = UIFont.systemFont(ofSize: 11, weight: .regular)
                let bodyBoldFont = UIFont.systemFont(ofSize: 11, weight: .semibold)
                let smallFont = UIFont.systemFont(ofSize: 9, weight: .regular)

                // Header
                let headerText = "WolfWhale LMS - Report Card" as NSString
                let headerAttrs: [NSAttributedString.Key: Any] = [.font: headerFont, .foregroundColor: UIColor.systemIndigo]
                let headerSize = headerText.size(withAttributes: headerAttrs)
                headerText.draw(at: CGPoint(x: (pageWidth - headerSize.width) / 2, y: yOffset), withAttributes: headerAttrs)
                yOffset += headerSize.height + 8

                let lineCtx = context.cgContext
                lineCtx.setStrokeColor(UIColor.systemIndigo.cgColor)
                lineCtx.setLineWidth(2)
                lineCtx.move(to: CGPoint(x: margin, y: yOffset))
                lineCtx.addLine(to: CGPoint(x: pageWidth - margin, y: yOffset))
                lineCtx.strokePath()
                yOffset += 16

                let infoAttrs: [NSAttributedString.Key: Any] = [.font: bodyFont, .foregroundColor: UIColor.darkGray]
                let infoBoldAttrs: [NSAttributedString.Key: Any] = [.font: bodyBoldFont, .foregroundColor: UIColor.black]

                func drawInfoRow(_ label: String, _ value: String, at y: CGFloat) -> CGFloat {
                    (label as NSString).draw(at: CGPoint(x: margin, y: y), withAttributes: infoAttrs)
                    (value as NSString).draw(at: CGPoint(x: margin + 140, y: y), withAttributes: infoBoldAttrs)
                    return y + 18
                }

                yOffset = drawInfoRow("Student Name:", reportCard.studentName, at: yOffset)
                yOffset = drawInfoRow("Term:", reportCard.termName, at: yOffset)
                yOffset = drawInfoRow("Date Generated:", Date().formatted(date: .long, time: .omitted), at: yOffset)
                yOffset += 16

                // Course Grades
                let sectionAttrs: [NSAttributedString.Key: Any] = [.font: sectionFont, .foregroundColor: UIColor.black]
                ("Course Grades" as NSString).draw(at: CGPoint(x: margin, y: yOffset), withAttributes: sectionAttrs)
                yOffset += 24

                let colCourse: CGFloat = margin
                let colTeacher: CGFloat = margin + contentWidth * 0.45
                let colGrade: CGFloat = margin + contentWidth * 0.65
                let colPercent: CGFloat = margin + contentWidth * 0.80

                let tableHeaderAttrs: [NSAttributedString.Key: Any] = [.font: bodyBoldFont, .foregroundColor: UIColor.white]
                let headerRowHeight: CGFloat = 22

                lineCtx.setFillColor(UIColor.systemIndigo.cgColor)
                lineCtx.fill(CGRect(x: margin, y: yOffset, width: contentWidth, height: headerRowHeight))

                ("Course" as NSString).draw(at: CGPoint(x: colCourse + 6, y: yOffset + 4), withAttributes: tableHeaderAttrs)
                ("Teacher" as NSString).draw(at: CGPoint(x: colTeacher + 6, y: yOffset + 4), withAttributes: tableHeaderAttrs)
                ("Grade" as NSString).draw(at: CGPoint(x: colGrade + 6, y: yOffset + 4), withAttributes: tableHeaderAttrs)
                ("Percent" as NSString).draw(at: CGPoint(x: colPercent + 6, y: yOffset + 4), withAttributes: tableHeaderAttrs)
                yOffset += headerRowHeight

                let rowAttrs: [NSAttributedString.Key: Any] = [.font: bodyFont, .foregroundColor: UIColor.darkGray]
                let rowBoldAttrs: [NSAttributedString.Key: Any] = [.font: bodyBoldFont, .foregroundColor: UIColor.black]
                let rowHeight: CGFloat = 22

                for (index, entry) in reportCard.courseEntries.enumerated() {
                    if index % 2 == 0 {
                        lineCtx.setFillColor(UIColor.systemGray6.cgColor)
                        lineCtx.fill(CGRect(x: margin, y: yOffset, width: contentWidth, height: rowHeight))
                    }
                    lineCtx.setStrokeColor(UIColor.systemGray4.cgColor)
                    lineCtx.setLineWidth(0.5)
                    lineCtx.stroke(CGRect(x: margin, y: yOffset, width: contentWidth, height: rowHeight))

                    (entry.courseName as NSString).draw(at: CGPoint(x: colCourse + 6, y: yOffset + 4), withAttributes: rowAttrs)
                    (entry.teacherName as NSString).draw(at: CGPoint(x: colTeacher + 6, y: yOffset + 4), withAttributes: rowAttrs)
                    (entry.letterGrade as NSString).draw(at: CGPoint(x: colGrade + 6, y: yOffset + 4), withAttributes: rowBoldAttrs)
                    (String(format: "%.1f%%", entry.numericGrade) as NSString).draw(at: CGPoint(x: colPercent + 6, y: yOffset + 4), withAttributes: rowAttrs)

                    yOffset += rowHeight
                }

                lineCtx.setStrokeColor(UIColor.systemGray4.cgColor)
                lineCtx.setLineWidth(0.5)
                lineCtx.move(to: CGPoint(x: margin, y: yOffset))
                lineCtx.addLine(to: CGPoint(x: pageWidth - margin, y: yOffset))
                lineCtx.strokePath()
                yOffset += 24

                // GPA
                ("GPA Summary" as NSString).draw(at: CGPoint(x: margin, y: yOffset), withAttributes: sectionAttrs)
                yOffset += 22
                yOffset = drawInfoRow("Cumulative GPA:", String(format: "%.1f%%", reportCard.gpa), at: yOffset)
                yOffset = drawInfoRow("Letter Grade:", reportCard.letterGrade, at: yOffset)
                yOffset = drawInfoRow("Standing:", reportCard.standing, at: yOffset)
                yOffset += 16

                // Attendance
                let att = reportCard.attendanceSummary
                ("Attendance Summary" as NSString).draw(at: CGPoint(x: margin, y: yOffset), withAttributes: sectionAttrs)
                yOffset += 22
                yOffset = drawInfoRow("Total Days:", "\(att.totalDays)", at: yOffset)
                yOffset = drawInfoRow("Present:", "\(att.presentCount)", at: yOffset)
                yOffset = drawInfoRow("Absent:", "\(att.absentCount)", at: yOffset)
                yOffset = drawInfoRow("Tardy:", "\(att.tardyCount)", at: yOffset)
                yOffset = drawInfoRow("Excused:", "\(att.excusedCount)", at: yOffset)
                yOffset = drawInfoRow("Attendance Rate:", String(format: "%.1f%%", att.attendanceRate), at: yOffset)
                yOffset += 16

                // Teacher Comments
                let commentsEntries = reportCard.courseEntries.filter { $0.teacherComment != nil }
                if !commentsEntries.isEmpty {
                    if yOffset > pageHeight - 150 {
                        context.beginPage()
                        yOffset = margin
                    }

                    ("Teacher Comments" as NSString).draw(at: CGPoint(x: margin, y: yOffset), withAttributes: sectionAttrs)
                    yOffset += 22

                    let commentLabelAttrs: [NSAttributedString.Key: Any] = [.font: bodyBoldFont, .foregroundColor: UIColor.systemIndigo]
                    let commentBodyAttrs: [NSAttributedString.Key: Any] = [.font: bodyFont, .foregroundColor: UIColor.darkGray]

                    for entry in commentsEntries {
                        if yOffset > pageHeight - 80 {
                            context.beginPage()
                            yOffset = margin
                        }

                        (entry.courseName as NSString).draw(at: CGPoint(x: margin, y: yOffset), withAttributes: commentLabelAttrs)
                        yOffset += 16

                        if let comment = entry.teacherComment {
                            let commentText = "\"\(comment)\"" as NSString
                            let commentRect = CGRect(x: margin + 10, y: yOffset, width: contentWidth - 20, height: 60)
                            commentText.draw(with: commentRect, options: .usesLineFragmentOrigin, attributes: commentBodyAttrs, context: nil)
                            let size = commentText.boundingRect(with: CGSize(width: contentWidth - 20, height: .greatestFiniteMagnitude), options: .usesLineFragmentOrigin, attributes: commentBodyAttrs, context: nil)
                            yOffset += size.height + 12
                        }
                    }
                }

                // Footer
                let footerAttrs: [NSAttributedString.Key: Any] = [.font: smallFont, .foregroundColor: UIColor.gray]
                let footerLine = "Generated by WolfWhale LMS on \(Date().formatted(date: .long, time: .shortened))" as NSString
                let footerSize = footerLine.size(withAttributes: footerAttrs)
                footerLine.draw(at: CGPoint(x: (pageWidth - footerSize.width) / 2, y: pageHeight - margin + 10), withAttributes: footerAttrs)

                lineCtx.setStrokeColor(UIColor.systemGray4.cgColor)
                lineCtx.setLineWidth(0.5)
                lineCtx.move(to: CGPoint(x: margin, y: pageHeight - margin + 4))
                lineCtx.addLine(to: CGPoint(x: pageWidth - margin, y: pageHeight - margin + 4))
                lineCtx.strokePath()
            }
        }

        let name = cards.count == 1 ? cards[0].studentName.replacingOccurrences(of: " ", with: "_") : "All_Students"
        let fileName = "ReportCard_\(name)_\(Date().formatted(.iso8601.year().month().day())).pdf"
        let fileURL = FileManager.default.temporaryDirectory.appending(path: fileName)

        do {
            try data.write(to: fileURL)
            return fileURL
        } catch {
            #if DEBUG
            print("[ReportCardPDFGenerator] PDF export failed: \(error)")
            #endif
            return nil
        }
    }
}
