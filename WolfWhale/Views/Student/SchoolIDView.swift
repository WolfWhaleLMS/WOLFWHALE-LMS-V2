import SwiftUI

struct SchoolIDView: View {
    let user: User
    let walletService: WalletPassService
    @State private var cardRotation: Double = 0
    @State private var appeared = false

    private var pass: WalletPassService.SchoolIDPass {
        walletService.generatePassData(for: user, schoolName: "WolfWhale Academy")
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                idCard
                actionButtons
                detailsSection
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("School ID")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            withAnimation(.smooth(duration: 0.6)) {
                appeared = true
            }
        }
    }

    // MARK: - ID Card

    private var idCard: some View {
        VStack(spacing: 0) {
            // Card Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: "w.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.white)
                        Text("WolfWhale Academy")
                            .font(.subheadline.bold())
                            .foregroundStyle(.white)
                    }
                    Text("Student Identification")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                }
                Spacer()
                Image(systemName: "wave.3.right")
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.6))
                    .symbolRenderingMode(.hierarchical)
                    .symbolEffect(.variableColor.iterative, options: .repeat(.periodic(delay: 3)))
                    .accessibilityLabel("NFC enabled")
            }
            .padding(20)
            .background(
                Theme.brandGradient
            )

            // Card Body
            VStack(spacing: 16) {
                HStack(spacing: 16) {
                    // Photo placeholder
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(
                                LinearGradient(
                                    colors: [Theme.brandPurple.opacity(0.2), Theme.brandBlue.opacity(0.2)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 80, height: 100)
                        Image(systemName: "person.fill")
                            .font(.system(size: 36))
                            .foregroundStyle(.purple.opacity(0.6))
                    }
                    .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(pass.studentName)
                            .font(.title3.bold())
                            .lineLimit(2)
                        Text("ID: \(pass.studentId)")
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)

                        HStack(spacing: 4) {
                            Image(systemName: user.role.iconName)
                                .font(.caption2)
                            Text(pass.role)
                                .font(.caption.bold())
                        }
                        .foregroundStyle(.purple)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(.purple.opacity(0.1), in: Capsule())

                        Text("Expires: \(pass.expirationDate.formatted(.dateTime.month(.abbreviated).year()))")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }

                    Spacer()
                }

                Divider()

                // QR Code placeholder
                VStack(spacing: 8) {
                    qrCodePlaceholder
                        .accessibilityLabel("QR code for student ID \(pass.studentId)")

                    Text(pass.barcode)
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)
                }
            }
            .padding(20)
            .background(Color(.systemBackground))
        }
        .clipShape(.rect(cornerRadius: 20))
        .shadow(color: .purple.opacity(0.15), radius: 20, x: 0, y: 10)
        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
        .rotation3DEffect(.degrees(appeared ? 0 : -15), axis: (x: 1, y: 0, z: 0))
        .opacity(appeared ? 1 : 0)
        .padding(.top, 8)
    }

    // MARK: - QR Code Placeholder

    private var qrCodePlaceholder: some View {
        let gridSize = 11
        let seed = pass.barcode.hashValue
        return VStack(spacing: 1.5) {
            ForEach(0..<gridSize, id: \.self) { row in
                HStack(spacing: 1.5) {
                    ForEach(0..<gridSize, id: \.self) { col in
                        let isBorder = row == 0 || row == gridSize - 1 || col == 0 || col == gridSize - 1
                        let isCornerFinder = (row < 3 && col < 3) || (row < 3 && col >= gridSize - 3) || (row >= gridSize - 3 && col < 3)
                        let isFilled = isCornerFinder || isBorder || ((row &+ col &+ seed) % 3 == 0)
                        Rectangle()
                            .fill(isFilled ? Color.primary : Color.clear)
                            .frame(width: 8, height: 8)
                    }
                }
            }
        }
        .padding(12)
        .background(Color(.systemBackground))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.gray.opacity(0.3), lineWidth: 0.5)
        }
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: 12) {
            // Apple Wallet notice
            HStack(spacing: 10) {
                Image(systemName: "wallet.pass.fill")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Apple Wallet")
                        .font(.subheadline.bold())
                        .foregroundStyle(.secondary)
                    Text("Wallet passes require school administrator setup.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(.ultraThinMaterial, in: .rect(cornerRadius: 14))
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Apple Wallet passes require school administrator setup")

            // NFC indicator
            HStack(spacing: 8) {
                Image(systemName: "wave.3.right.circle.fill")
                    .foregroundStyle(.cyan)
                Text("Tap-to-ID ready with NFC")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial, in: .rect(cornerRadius: 10))
            .accessibilityElement(children: .combine)
            .accessibilityLabel("NFC tap to ID is ready")
        }
    }

    // MARK: - Details Section

    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("ID Details")
                .font(.headline)

            VStack(spacing: 0) {
                detailRow(label: "Full Name", value: pass.studentName, icon: "person.fill")
                Divider().padding(.leading, 44)
                detailRow(label: "Student ID", value: pass.studentId, icon: "number")
                Divider().padding(.leading, 44)
                detailRow(label: "Role", value: pass.role, icon: "shield.fill")
                Divider().padding(.leading, 44)
                detailRow(label: "School", value: pass.schoolName, icon: "building.columns.fill")
                Divider().padding(.leading, 44)
                detailRow(label: "Expires", value: pass.expirationDate.formatted(.dateTime.month(.wide).day().year()), icon: "calendar")
                Divider().padding(.leading, 44)
                detailRow(label: "Barcode", value: pass.barcode, icon: "barcode")
            }
            .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
        }
    }

    private func detailRow(label: String, value: String, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(.purple)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.subheadline)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }
}
