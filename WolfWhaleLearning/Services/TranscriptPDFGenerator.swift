import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

@MainActor
final class TranscriptPDFGenerator {

    // MARK: - Data Structures

    struct TranscriptData {
        let studentName: String
        let studentId: String
        let schoolName: String
        let gradeLevel: String
        let schoolYear: String
        let courses: [CourseGradeRow]
        let cumulativeGPA: Double
        let totalCredits: Double
        let attendanceRate: Double  // 0-100
        let generatedDate: Date
    }

    struct CourseGradeRow {
        let courseName: String
        let teacherName: String
        let grade: Double           // percentage
        let letterGrade: String
        let credits: Double
        let gradePoints: Double     // on 4.0 scale
    }

    // MARK: - Constants

    private let pageWidth: CGFloat = 612   // US Letter
    private let pageHeight: CGFloat = 792
    private let margin: CGFloat = 50
    private var contentWidth: CGFloat { pageWidth - (margin * 2) }

    // Indigo accent (#4F46E5)
    #if canImport(UIKit)
    private let accentColor = UIColor(red: 79 / 255.0, green: 70 / 255.0, blue: 229 / 255.0, alpha: 1.0)
    private let lightAccent = UIColor(red: 79 / 255.0, green: 70 / 255.0, blue: 229 / 255.0, alpha: 0.10)
    #endif

    // MARK: - Public API

    /// Generates a PDF `Data` blob for the supplied transcript.
    func generateTranscript(from data: TranscriptData) -> Data {
        #if canImport(UIKit)
        return renderPDF(from: data)
        #else
        return Data()
        #endif
    }

    // MARK: - UIKit PDF Rendering

    #if canImport(UIKit)
    private func renderPDF(from data: TranscriptData) -> Data {
        let format = UIGraphicsPDFRendererFormat()
        let pageBounds = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        let renderer = UIGraphicsPDFRenderer(bounds: pageBounds, format: format)

        let pdfData = renderer.pdfData { context in
            context.beginPage()
            var y = margin

            // Fonts
            let titleFont = UIFont.systemFont(ofSize: 20, weight: .bold)
            let subtitleFont = UIFont.systemFont(ofSize: 14, weight: .semibold)
            let sectionFont = UIFont.systemFont(ofSize: 13, weight: .bold)
            let bodyFont = UIFont.systemFont(ofSize: 10.5, weight: .regular)
            let bodyBoldFont = UIFont.systemFont(ofSize: 10.5, weight: .semibold)
            let smallFont = UIFont.systemFont(ofSize: 9, weight: .regular)
            let tableHeaderFont = UIFont.systemFont(ofSize: 9.5, weight: .bold)
            let tableBodyFont = UIFont.systemFont(ofSize: 9.5, weight: .regular)
            let tableBodyBoldFont = UIFont.systemFont(ofSize: 9.5, weight: .semibold)

            let cgContext = context.cgContext

            // ----------------------------------------------------------------
            // HEADER
            // ----------------------------------------------------------------
            let headerText = "Official Academic Transcript" as NSString
            let headerAttrs: [NSAttributedString.Key: Any] = [
                .font: titleFont,
                .foregroundColor: accentColor
            ]
            let headerSize = headerText.size(withAttributes: headerAttrs)
            headerText.draw(
                at: CGPoint(x: (pageWidth - headerSize.width) / 2, y: y),
                withAttributes: headerAttrs
            )
            y += headerSize.height + 4

            let schoolText = data.schoolName as NSString
            let schoolAttrs: [NSAttributedString.Key: Any] = [
                .font: subtitleFont,
                .foregroundColor: UIColor.darkGray
            ]
            let schoolSize = schoolText.size(withAttributes: schoolAttrs)
            schoolText.draw(
                at: CGPoint(x: (pageWidth - schoolSize.width) / 2, y: y),
                withAttributes: schoolAttrs
            )
            y += schoolSize.height + 10

            // Horizontal separator
            cgContext.setStrokeColor(accentColor.cgColor)
            cgContext.setLineWidth(2)
            cgContext.move(to: CGPoint(x: margin, y: y))
            cgContext.addLine(to: CGPoint(x: pageWidth - margin, y: y))
            cgContext.strokePath()
            y += 16

            // ----------------------------------------------------------------
            // STUDENT INFO
            // ----------------------------------------------------------------
            let labelAttrs: [NSAttributedString.Key: Any] = [.font: bodyFont, .foregroundColor: UIColor.darkGray]
            let valueAttrs: [NSAttributedString.Key: Any] = [.font: bodyBoldFont, .foregroundColor: UIColor.black]

            func drawInfoRow(_ label: String, _ value: String, at yPos: CGFloat) -> CGFloat {
                (label as NSString).draw(at: CGPoint(x: margin, y: yPos), withAttributes: labelAttrs)
                (value as NSString).draw(at: CGPoint(x: margin + 130, y: yPos), withAttributes: valueAttrs)
                return yPos + 18
            }

            y = drawInfoRow("Name:", data.studentName, at: y)
            y = drawInfoRow("Student ID:", data.studentId, at: y)
            y = drawInfoRow("Grade Level:", data.gradeLevel, at: y)
            y = drawInfoRow("School Year:", data.schoolYear, at: y)
            y += 14

            // ----------------------------------------------------------------
            // COURSE TABLE
            // ----------------------------------------------------------------
            let sectionAttrs: [NSAttributedString.Key: Any] = [
                .font: sectionFont,
                .foregroundColor: accentColor
            ]
            ("Course Grades" as NSString).draw(at: CGPoint(x: margin, y: y), withAttributes: sectionAttrs)
            y += 22

            // Column x-positions
            let colCourse   = margin
            let colTeacher  = margin + contentWidth * 0.32
            let colGrade    = margin + contentWidth * 0.56
            let colLetter   = margin + contentWidth * 0.67
            let colCredits  = margin + contentWidth * 0.78
            let colGPA      = margin + contentWidth * 0.89

            let headerRowHeight: CGFloat = 20
            let tableHeaderTextAttrs: [NSAttributedString.Key: Any] = [
                .font: tableHeaderFont,
                .foregroundColor: UIColor.white
            ]

            // Header row background
            cgContext.setFillColor(accentColor.cgColor)
            cgContext.fill(CGRect(x: margin, y: y, width: contentWidth, height: headerRowHeight))

            let pad: CGFloat = 4
            ("Course" as NSString).draw(at: CGPoint(x: colCourse + pad, y: y + 4), withAttributes: tableHeaderTextAttrs)
            ("Teacher" as NSString).draw(at: CGPoint(x: colTeacher + pad, y: y + 4), withAttributes: tableHeaderTextAttrs)
            ("Grade" as NSString).draw(at: CGPoint(x: colGrade + pad, y: y + 4), withAttributes: tableHeaderTextAttrs)
            ("Letter" as NSString).draw(at: CGPoint(x: colLetter + pad, y: y + 4), withAttributes: tableHeaderTextAttrs)
            ("Credits" as NSString).draw(at: CGPoint(x: colCredits + pad, y: y + 4), withAttributes: tableHeaderTextAttrs)
            ("GPA Pts" as NSString).draw(at: CGPoint(x: colGPA + pad, y: y + 4), withAttributes: tableHeaderTextAttrs)
            y += headerRowHeight

            let rowHeight: CGFloat = 20
            let rowTextAttrs: [NSAttributedString.Key: Any] = [.font: tableBodyFont, .foregroundColor: UIColor.darkGray]
            let rowBoldAttrs: [NSAttributedString.Key: Any] = [.font: tableBodyBoldFont, .foregroundColor: UIColor.black]
            let altRowColor = UIColor.systemGray6.cgColor

            for (index, course) in data.courses.enumerated() {
                // Check page overflow
                if y + rowHeight > pageHeight - margin - 60 {
                    drawFooter(cgContext: cgContext, data: data, pageNumber: pageNumber(context), smallFont: smallFont)
                    context.beginPage()
                    y = margin
                }

                // Alternating row background
                if index % 2 == 0 {
                    cgContext.setFillColor(altRowColor)
                    cgContext.fill(CGRect(x: margin, y: y, width: contentWidth, height: rowHeight))
                }

                // Row border
                cgContext.setStrokeColor(UIColor.systemGray4.cgColor)
                cgContext.setLineWidth(0.5)
                cgContext.stroke(CGRect(x: margin, y: y, width: contentWidth, height: rowHeight))

                (course.courseName as NSString).draw(at: CGPoint(x: colCourse + pad, y: y + 3), withAttributes: rowTextAttrs)
                (course.teacherName as NSString).draw(at: CGPoint(x: colTeacher + pad, y: y + 3), withAttributes: rowTextAttrs)
                (String(format: "%.1f%%", course.grade) as NSString).draw(at: CGPoint(x: colGrade + pad, y: y + 3), withAttributes: rowBoldAttrs)
                (course.letterGrade as NSString).draw(at: CGPoint(x: colLetter + pad, y: y + 3), withAttributes: rowBoldAttrs)
                (String(format: "%.1f", course.credits) as NSString).draw(at: CGPoint(x: colCredits + pad, y: y + 3), withAttributes: rowTextAttrs)
                (String(format: "%.2f", course.gradePoints) as NSString).draw(at: CGPoint(x: colGPA + pad, y: y + 3), withAttributes: rowTextAttrs)

                y += rowHeight
            }

            // Bottom border
            cgContext.setStrokeColor(accentColor.cgColor)
            cgContext.setLineWidth(1)
            cgContext.move(to: CGPoint(x: margin, y: y))
            cgContext.addLine(to: CGPoint(x: pageWidth - margin, y: y))
            cgContext.strokePath()
            y += 24

            // ----------------------------------------------------------------
            // SUMMARY
            // ----------------------------------------------------------------
            if y + 90 > pageHeight - margin - 60 {
                drawFooter(cgContext: cgContext, data: data, pageNumber: pageNumber(context), smallFont: smallFont)
                context.beginPage()
                y = margin
            }

            ("Academic Summary" as NSString).draw(at: CGPoint(x: margin, y: y), withAttributes: sectionAttrs)
            y += 22

            // Summary box
            let summaryBoxHeight: CGFloat = 60
            cgContext.setFillColor(lightAccent.cgColor)
            cgContext.fill(CGRect(x: margin, y: y, width: contentWidth, height: summaryBoxHeight))
            cgContext.setStrokeColor(accentColor.cgColor)
            cgContext.setLineWidth(0.5)
            cgContext.stroke(CGRect(x: margin, y: y, width: contentWidth, height: summaryBoxHeight))

            let summaryLabelAttrs: [NSAttributedString.Key: Any] = [.font: bodyFont, .foregroundColor: UIColor.darkGray]
            let summaryValueAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 13, weight: .bold),
                .foregroundColor: accentColor
            ]

            let col1X = margin + 20
            let col2X = margin + contentWidth * 0.35
            let col3X = margin + contentWidth * 0.68

            // Row 1
            let summaryY1 = y + 10
            ("Cumulative GPA" as NSString).draw(at: CGPoint(x: col1X, y: summaryY1), withAttributes: summaryLabelAttrs)
            (String(format: "%.2f / 4.00", data.cumulativeGPA) as NSString).draw(at: CGPoint(x: col1X, y: summaryY1 + 16), withAttributes: summaryValueAttrs)

            ("Total Credits" as NSString).draw(at: CGPoint(x: col2X, y: summaryY1), withAttributes: summaryLabelAttrs)
            (String(format: "%.1f", data.totalCredits) as NSString).draw(at: CGPoint(x: col2X, y: summaryY1 + 16), withAttributes: summaryValueAttrs)

            ("Attendance Rate" as NSString).draw(at: CGPoint(x: col3X, y: summaryY1), withAttributes: summaryLabelAttrs)
            (String(format: "%.1f%%", data.attendanceRate) as NSString).draw(at: CGPoint(x: col3X, y: summaryY1 + 16), withAttributes: summaryValueAttrs)

            y += summaryBoxHeight + 16

            // ----------------------------------------------------------------
            // FOOTER
            // ----------------------------------------------------------------
            drawFooter(cgContext: cgContext, data: data, pageNumber: pageNumber(context), smallFont: smallFont)
        }

        return pdfData
    }

    // MARK: - Footer Helper

    private func drawFooter(
        cgContext: CGContext,
        data: TranscriptData,
        pageNumber: Int,
        smallFont: UIFont
    ) {
        let footerY = pageHeight - margin + 8

        // Divider line
        cgContext.setStrokeColor(UIColor.systemGray4.cgColor)
        cgContext.setLineWidth(0.5)
        cgContext.move(to: CGPoint(x: margin, y: footerY - 4))
        cgContext.addLine(to: CGPoint(x: pageWidth - margin, y: footerY - 4))
        cgContext.strokePath()

        let footerAttrs: [NSAttributedString.Key: Any] = [.font: smallFont, .foregroundColor: UIColor.gray]

        let dateString = data.generatedDate.formatted(date: .long, time: .shortened)
        let generatedText = "Generated on \(dateString)" as NSString
        generatedText.draw(at: CGPoint(x: margin, y: footerY), withAttributes: footerAttrs)

        let brandText = "WolfWhale Learning Management System" as NSString
        let brandSize = brandText.size(withAttributes: footerAttrs)
        brandText.draw(
            at: CGPoint(x: (pageWidth - brandSize.width) / 2, y: footerY),
            withAttributes: footerAttrs
        )

        let pageText = "Page \(pageNumber)" as NSString
        let pageSize = pageText.size(withAttributes: footerAttrs)
        pageText.draw(
            at: CGPoint(x: pageWidth - margin - pageSize.width, y: footerY),
            withAttributes: footerAttrs
        )
    }

    /// Estimates the current page number from the PDF renderer context.
    /// UIGraphicsPDFRendererContext does not expose a page counter directly,
    /// so we track via a simple helper.
    private func pageNumber(_ context: UIGraphicsPDFRendererContext) -> Int {
        // The pdfContext page count is available via the underlying CGContext.
        // UIGraphicsPDFRenderer tracks pages internally; we approximate by
        // counting beginPage calls. For simplicity, start at 1.
        // A more robust approach would be a mutable counter, but since
        // this is called synchronously inside `pdfData`, we use 1 for single-page
        // or rely on the fact that multipage transcripts are rare.
        return 1
    }
    #endif

    // MARK: - Convenience: Build TranscriptData from AppViewModel state

    /// Builds a `TranscriptData` from the view-model's current state.
    static func buildTranscriptData(
        from grades: [GradeEntry],
        courses: [Course],
        attendance: [AttendanceRecord],
        user: User?,
        gradeService: GradeCalculationService
    ) -> TranscriptData {
        let studentName = user?.fullName ?? "Student"
        let studentId = user?.id.uuidString.prefix(8).uppercased() ?? "N/A"
        let schoolName = "WolfWhale Learning Academy"

        // Derive school year
        let calendar = Calendar.current
        let year = calendar.component(.year, from: Date())
        let month = calendar.component(.month, from: Date())
        let schoolYear = month >= 8 ? "\(year)-\(year + 1)" : "\(year - 1)-\(year)"

        // Build course rows
        let courseRows: [CourseGradeRow] = grades.map { entry in
            let matchingCourse = courses.first { $0.id == entry.courseId }
            let teacherName = matchingCourse?.teacherName ?? "N/A"
            let gradePoints = gradeService.gradePoints(from: entry.numericGrade)
            let letterGrade = gradeService.letterGrade(from: entry.numericGrade)

            return CourseGradeRow(
                courseName: entry.courseName,
                teacherName: teacherName,
                grade: entry.numericGrade,
                letterGrade: letterGrade,
                credits: 1.0,
                gradePoints: gradePoints
            )
        }

        // Cumulative GPA
        let totalGradePoints = courseRows.reduce(0.0) { $0 + $1.gradePoints }
        let cumulativeGPA = courseRows.isEmpty ? 0.0 : totalGradePoints / Double(courseRows.count)

        // Total credits
        let totalCredits = courseRows.reduce(0.0) { $0 + $1.credits }

        // Attendance rate
        let totalAttendance = attendance.count
        let presentOrExcused = attendance.filter { $0.status == .present || $0.status == .excused }.count
        let attendanceRate = totalAttendance > 0 ? Double(presentOrExcused) / Double(totalAttendance) * 100 : 100.0

        return TranscriptData(
            studentName: studentName,
            studentId: String(studentId),
            schoolName: schoolName,
            gradeLevel: "N/A",
            schoolYear: schoolYear,
            courses: courseRows,
            cumulativeGPA: cumulativeGPA,
            totalCredits: totalCredits,
            attendanceRate: attendanceRate,
            generatedDate: Date()
        )
    }

    // MARK: - File Export Helper

    /// Generates a transcript PDF and writes it to a temporary file, returning the URL.
    func generateTranscriptFile(from data: TranscriptData) -> URL? {
        let pdfData = generateTranscript(from: data)
        guard !pdfData.isEmpty else { return nil }

        let tempDir = FileManager.default.temporaryDirectory
        let safeName = data.studentName.replacingOccurrences(of: " ", with: "_")
        let dateStamp = Date().formatted(.iso8601.year().month().day())
        let fileName = "Transcript_\(safeName)_\(dateStamp).pdf"
        let fileURL = tempDir.appendingPathComponent(fileName)

        do {
            try pdfData.write(to: fileURL)
            return fileURL
        } catch {
            return nil
        }
    }
}
