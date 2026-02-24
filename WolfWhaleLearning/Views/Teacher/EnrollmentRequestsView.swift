import SwiftUI

struct EnrollmentRequestsView: View {
    @Bindable var viewModel: AppViewModel
    @State private var hapticTrigger = false
    @State private var showDenySheet = false
    @State private var denyTargetRequest: EnrollmentRequest?
    @State private var denyReason = ""

    private var pendingRequests: [EnrollmentRequest] {
        viewModel.enrollmentRequests.filter { $0.status == .pending }
    }

    var body: some View {
        ScrollView {
            if pendingRequests.isEmpty {
                ContentUnavailableView(
                    "No Pending Requests",
                    systemImage: "checkmark.seal.fill",
                    description: Text("All enrollment requests have been reviewed")
                )
                .padding(.top, 60)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(pendingRequests) { request in
                        requestCard(request)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Enrollment Requests")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if !pendingRequests.isEmpty {
                    Text("\(pendingRequests.count)")
                        .font(.caption2.bold())
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(.red)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                }
            }
        }
        .refreshable {
            await viewModel.loadEnrollmentRequests()
        }
        .task {
            await viewModel.loadEnrollmentRequests()
        }
        .sheet(isPresented: $showDenySheet) {
            denyReasonSheet
        }
        .hapticFeedback(.success, trigger: hapticTrigger)
    }

    // MARK: - Request Card

    private func requestCard(_ request: EnrollmentRequest) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "person.crop.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.indigo)

                VStack(alignment: .leading, spacing: 2) {
                    Text(request.studentName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color(.label))

                    Text(request.courseName)
                        .font(.caption)
                        .foregroundStyle(Color(.secondaryLabel))
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(request.requestDate, style: .date)
                        .font(.caption2)
                        .foregroundStyle(Color(.tertiaryLabel))

                    Text(request.requestDate, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(Color(.tertiaryLabel))
                }
            }

            Divider()

            HStack(spacing: 12) {
                Button {
                    hapticTrigger.toggle()
                    Task { await viewModel.approveEnrollment(requestId: request.id) }
                } label: {
                    Label("Approve", systemImage: "checkmark.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(.green.gradient, in: RoundedRectangle(cornerRadius: 10))
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
                        .background(.red.gradient, in: RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color(.separator).opacity(0.3), lineWidth: 1)
        )
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
                        .foregroundStyle(Color(.label))

                    if let request = denyTargetRequest {
                        Text("Denying \(request.studentName)'s request for \(request.courseName)")
                            .font(.subheadline)
                            .foregroundStyle(Color(.secondaryLabel))
                            .multilineTextAlignment(.center)
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Reason (optional)")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color(.secondaryLabel))

                    TextField("Enter a reason for denial...", text: $denyReason, axis: .vertical)
                        .textFieldStyle(.plain)
                        .lineLimit(3...6)
                        .padding(12)
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                Button {
                    hapticTrigger.toggle()
                    showDenySheet = false
                    if let request = denyTargetRequest {
                        Task { await viewModel.denyEnrollment(requestId: request.id) }
                    }
                } label: {
                    Text("Deny Request")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(.red.gradient, in: RoundedRectangle(cornerRadius: 12))
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
}
