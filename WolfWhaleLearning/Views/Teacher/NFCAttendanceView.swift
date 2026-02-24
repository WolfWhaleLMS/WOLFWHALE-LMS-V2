import SwiftUI

struct NFCAttendanceView: View {
    @Bindable var viewModel: AppViewModel
    let courseId: UUID

    @State private var nfcService: NFCAttendanceService?
    @State private var checkedInStudents: [(id: UUID, name: String, time: Date)] = []
    @State private var showFinishConfirmation = false
    @State private var showSuccess = false
    @State private var isSaving = false
    @State private var pulseAnimation = false
    @State private var hapticTrigger = false

    private var courseName: String {
        viewModel.courses.first(where: { $0.id == courseId })?.title ?? "Unknown Course"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                nfcScannerSection
                checkedInSection
                finishButton
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("NFC Attendance")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if nfcService == nil {
                nfcService = NFCAttendanceService()
            }
        }
        .onChange(of: nfcService?.scanResult) { _, newValue in
            handleScanResult(newValue)
        }
        .alert("Finish Session?", isPresented: $showFinishConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Save & Finish") {
                saveAttendanceSession()
            }
        } message: {
            Text("This will save attendance for \(checkedInStudents.count) student\(checkedInStudents.count == 1 ? "" : "s").")
        }
        .overlay {
            if showSuccess {
                successOverlay
            }
        }
    }

    // MARK: - NFC Scanner Section

    private var nfcScannerSection: some View {
        VStack(spacing: 20) {
            // NFC icon with pulse animation
            ZStack {
                // Outer pulse rings
                if nfcService?.isScanning == true {
                    Circle()
                        .stroke(Color.purple.opacity(0.3), lineWidth: 2)
                        .frame(width: 160, height: 160)
                        .scaleEffect(pulseAnimation ? 1.3 : 1.0)
                        .opacity(pulseAnimation ? 0 : 0.6)

                    Circle()
                        .stroke(Color.cyan.opacity(0.3), lineWidth: 2)
                        .frame(width: 140, height: 140)
                        .scaleEffect(pulseAnimation ? 1.2 : 1.0)
                        .opacity(pulseAnimation ? 0 : 0.6)
                }

                // Main circle
                Circle()
                    .fill(
                        LinearGradient(
                            colors: scannerGradientColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)
                    .shadow(color: scannerGradientColors.first?.opacity(0.4) ?? .clear, radius: 12, y: 4)

                Image(systemName: scannerIconName)
                    .font(.system(size: 44))
                    .foregroundStyle(.white)
                    .symbolEffect(.pulse, isActive: nfcService?.isScanning == true)
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: false)) {
                    pulseAnimation = true
                }
            }

            // Status text
            VStack(spacing: 6) {
                Text(scannerTitle)
                    .font(.title3.bold())

                Text(scannerSubtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            // Scan button
            Button {
                hapticTrigger.toggle()
                nfcService?.startScanning()
            } label: {
                Label(
                    nfcService?.isScanning == true ? "Scanning..." : "Tap to Start Scanning",
                    systemImage: "sensor.tag.radiowaves.forward.fill"
                )
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
            }
            .buttonStyle(.borderedProminent)
            .tint(
                Theme.brandGradientHorizontal
            )
            .disabled(nfcService?.isScanning == true || nfcService?.isNFCAvailable != true)
            .sensoryFeedback(.impact(weight: .medium), trigger: hapticTrigger)

            if nfcService?.isNFCAvailable != true {
                Label("NFC is not available on this device", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            if let error = nfcService?.lastError {
                Label(error, systemImage: "xmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(10)
                    .frame(maxWidth: .infinity)
                    .background(.red.opacity(0.1), in: .rect(cornerRadius: 8))
            }
        }
        .padding(24)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 20))
    }

    // MARK: - Checked-In Students Section

    private var checkedInSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Checked In", systemImage: "person.crop.circle.badge.checkmark")
                    .font(.headline)
                Spacer()
                Text("\(checkedInStudents.count) student\(checkedInStudents.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(.green.opacity(0.15), in: Capsule())
            }

            if checkedInStudents.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "person.2.slash")
                        .font(.title)
                        .foregroundStyle(.secondary)
                    Text("No students checked in yet")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("Start scanning NFC tags to check in students")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
                .background(.ultraThinMaterial, in: .rect(cornerRadius: 12))
            } else {
                ForEach(checkedInStudents, id: \.id) { student in
                    studentCheckInRow(student)
                        .transition(.asymmetric(
                            insertion: .scale.combined(with: .opacity),
                            removal: .opacity
                        ))
                }
            }
        }
    }

    private func studentCheckInRow(_ student: (id: UUID, name: String, time: Date)) -> some View {
        HStack(spacing: 12) {
            // Avatar circle
            Circle()
                .fill(
                    Theme.brandGradient
                )
                .frame(width: 40, height: 40)
                .overlay {
                    Text(String(student.name.prefix(1)).uppercased())
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(student.name)
                    .font(.subheadline.bold())
                    .lineLimit(1)
                Text(student.time, style: .time)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.title3)
                .foregroundStyle(.green)
        }
        .padding(12)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 12))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(student.name) checked in at \(student.time.formatted(date: .omitted, time: .shortened))")
    }

    // MARK: - Finish Button

    private var finishButton: some View {
        Button {
            hapticTrigger.toggle()
            showFinishConfirmation = true
        } label: {
            Group {
                if isSaving {
                    ProgressView()
                        .tint(.white)
                } else {
                    Label("Finish Session", systemImage: "checkmark.circle.fill")
                        .fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
        }
        .buttonStyle(.borderedProminent)
        .tint(.pink)
        .disabled(checkedInStudents.isEmpty || isSaving)
        .sensoryFeedback(.impact(weight: .medium), trigger: hapticTrigger)
        .padding(.top, 4)
    }

    // MARK: - Success Overlay

    private var successOverlay: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.green)
                Text("Attendance Saved")
                    .font(.title3.bold())
                Text("Recorded \(checkedInStudents.count) student\(checkedInStudents.count == 1 ? "" : "s") for \(courseName)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(32)
            .background(.regularMaterial, in: .rect(cornerRadius: 20))
        }
        .transition(.opacity)
        .onTapGesture {
            withAnimation { showSuccess = false }
        }
    }

    // MARK: - Helpers

    private var scannerGradientColors: [Color] {
        switch nfcService?.scanResult {
        case .success: [.green, .mint]
        case .error: [.red, .orange]
        case nil: nfcService?.isScanning == true ? Theme.brandGradientColors : [Theme.brandPurple, Theme.brandBlue]
        }
    }

    private var scannerIconName: String {
        switch nfcService?.scanResult {
        case .success: "checkmark.circle.fill"
        case .error: "xmark.circle.fill"
        case nil: "sensor.tag.radiowaves.forward.fill"
        }
    }

    private var scannerTitle: String {
        switch nfcService?.scanResult {
        case .success(let name): "Checked In: \(name)"
        case .error: "Scan Failed"
        case nil: nfcService?.isScanning == true ? "Scanning..." : "Ready to Scan"
        }
    }

    private var scannerSubtitle: String {
        switch nfcService?.scanResult {
        case .success: "Tap to scan another student"
        case .error: "Please try again"
        case nil: nfcService?.isScanning == true
            ? "Hold a student ID near the device"
            : "Tap the button below to start NFC scanning"
        }
    }

    private func handleScanResult(_ result: NFCAttendanceService.ScanResult?) {
        guard case .success(let name) = result else { return }

        // Avoid duplicates
        guard !checkedInStudents.contains(where: { $0.name == name }) else {
            nfcService?.lastError = "\(name) is already checked in"
            return
        }

        withAnimation(.snappy) {
            checkedInStudents.append((id: UUID(), name: name, time: Date()))
        }

        // Reset for next scan after a brief delay
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            nfcService?.reset()
        }
    }

    private func saveAttendanceSession() {
        isSaving = true

        Task {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withFullDate]
            let dateString = formatter.string(from: Date())

            let records: [(studentId: UUID, courseId: UUID, courseName: String, date: String, status: String)] =
                checkedInStudents.map { student in
                    (studentId: student.id, courseId: courseId, courseName: courseName, date: dateString, status: "Present")
                }

            await viewModel.takeAttendance(records: records)

            isSaving = false
            withAnimation(.snappy) {
                showSuccess = true
            }

            try? await Task.sleep(for: .seconds(2))
            withAnimation { showSuccess = false }
        }
    }
}
