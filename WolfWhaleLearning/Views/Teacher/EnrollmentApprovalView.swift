import SwiftUI

struct EnrollmentApprovalView: View {
    let viewModel: AppViewModel
    @State private var enrollmentService = EnrollmentService()
    @State private var hapticTrigger = false
    @State private var showDenySheet = false
    @State private var denyTargetRequest: EnrollmentRequest?
    @State private var denyReason = ""
    @State private var showApproveAllConfirmation = false

    var body: some View {
        NavigationStack {
            Group {
                if enrollmentService.isLoading && enrollmentService.pendingRequests.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .accessibilityLabel("Loading enrollment requests")
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(enrollmentService.pendingRequests) { request in
                                requestCard(request)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)
                    }
                    .overlay {
                        if enrollmentService.pendingRequests.isEmpty {
                            ContentUnavailableView(
                                "No Pending Requests",
                                systemImage: "checkmark.seal.fill",
                                description: Text("All enrollment requests have been reviewed")
                            )
                        }
                    }
                }
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle("Enrollment Requests")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if !enrollmentService.pendingRequests.isEmpty {
                        Menu {
                            Button {
                                showApproveAllConfirmation = true
                            } label: {
                                Label("Approve All (\(enrollmentService.pendingRequests.count))", systemImage: "checkmark.circle.fill")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    if !enrollmentService.pendingRequests.isEmpty {
                        Text("\(enrollmentService.pendingRequests.count)")
                            .font(.caption2.bold())
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(.red)
                            .foregroundStyle(.white)
                            .clipShape(.capsule)
                    }
                }
            }
            .refreshable {
                await loadRequests()
            }
            .task {
                await loadRequests()
            }
            .alert("Error", isPresented: .init(
                get: { enrollmentService.error != nil },
                set: { if !$0 { enrollmentService.error = nil } }
            )) {
                Button("OK", role: .cancel) { enrollmentService.error = nil }
            } message: {
                Text(enrollmentService.error ?? "")
            }
            .confirmationDialog(
                "Approve All Requests",
                isPresented: $showApproveAllConfirmation,
                titleVisibility: .visible
            ) {
                Button("Approve All (\(enrollmentService.pendingRequests.count))") {
                    hapticTrigger.toggle()
                    Task { await approveAll() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will approve all \(enrollmentService.pendingRequests.count) pending enrollment requests. This action cannot be undone.")
            }
            .sheet(isPresented: $showDenySheet) {
                denyReasonSheet
            }
            .sensoryFeedback(.success, trigger: hapticTrigger)
        }
    }

    // MARK: - Request Card

    private func requestCard(_ request: EnrollmentRequest) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // Student info
            HStack(spacing: 10) {
                Image(systemName: "person.crop.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.indigo)

                VStack(alignment: .leading, spacing: 2) {
                    Text(request.studentName)
                        .font(.subheadline.weight(.semibold))

                    Text(request.courseName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(request.requestDate, style: .date)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)

                    Text(request.requestDate, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            Divider()

            // Action buttons
            HStack(spacing: 12) {
                Button {
                    hapticTrigger.toggle()
                    Task { await approve(request) }
                } label: {
                    Label("Approve", systemImage: "checkmark.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(.green.gradient, in: .rect(cornerRadius: 10))
                }
                .buttonStyle(.plain)

                Button {
                    denyTargetRequest = request
                    denyReason = ""
                    showDenySheet = true
                } label: {
                    Label("Deny", systemImage: "xmark.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(.red.gradient, in: .rect(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(request.studentName) requests enrollment in \(request.courseName), submitted \(request.requestDate, format: .dateTime.month().day())")
    }

    // MARK: - Deny Reason Sheet

    private var denyReasonSheet: some View {
        NavigationStack {
            VStack(spacing: 20) {
                VStack(spacing: 8) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.largeTitle)
                        .foregroundStyle(.red)

                    Text("Deny Enrollment")
                        .font(.title2.bold())

                    if let request = denyTargetRequest {
                        Text("Denying \(request.studentName)'s request for \(request.courseName)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Reason (optional)")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)

                    TextField("Enter a reason for denial...", text: $denyReason, axis: .vertical)
                        .textFieldStyle(.plain)
                        .lineLimit(3...6)
                        .padding(12)
                        .background(.ultraThinMaterial, in: .rect(cornerRadius: 12))
                }

                Button {
                    hapticTrigger.toggle()
                    showDenySheet = false
                    if let request = denyTargetRequest {
                        Task { await deny(request) }
                    }
                } label: {
                    Text("Deny Request")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(.red.gradient, in: .rect(cornerRadius: 12))
                }
                .buttonStyle(.plain)

                Spacer()
            }
            .padding()
            .navigationTitle("Deny Enrollment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showDenySheet = false
                        denyTargetRequest = nil
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Actions

    private func loadRequests() async {
        guard let user = viewModel.currentUser else { return }
        await enrollmentService.fetchPendingRequests(teacherId: user.id)
    }

    private func approve(_ request: EnrollmentRequest) async {
        guard let user = viewModel.currentUser else { return }
        _ = await enrollmentService.approveEnrollment(requestId: request.id, reviewerId: user.id)
    }

    private func deny(_ request: EnrollmentRequest) async {
        guard let user = viewModel.currentUser else { return }
        let reason = denyReason.trimmingCharacters(in: .whitespacesAndNewlines)
        _ = await enrollmentService.denyEnrollment(
            requestId: request.id,
            reviewerId: user.id,
            reason: reason.isEmpty ? nil : reason
        )
        denyTargetRequest = nil
    }

    private func approveAll() async {
        guard let user = viewModel.currentUser else { return }
        let requests = enrollmentService.pendingRequests
        for request in requests {
            _ = await enrollmentService.approveEnrollment(requestId: request.id, reviewerId: user.id)
        }
    }
}
