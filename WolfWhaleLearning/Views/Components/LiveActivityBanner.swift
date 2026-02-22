import SwiftUI

struct LiveActivityBanner: View {
    let liveActivityService: LiveActivityService
    let courseName: String
    let teacherName: String
    @State private var showStartSheet = false
    @State private var duration = 60
    @State private var topic = ""
    @State private var hapticTrigger = false

    var body: some View {
        if liveActivityService.isClassSessionActive {
            activeSessionBanner
        } else {
            startSessionButton
        }
    }

    // MARK: - Active Session Banner

    private var activeSessionBanner: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(.red)
                .frame(width: 10, height: 10)
                .overlay {
                    Circle()
                        .fill(.red.opacity(0.4))
                        .frame(width: 20, height: 20)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text("LIVE SESSION")
                    .font(.caption2.bold())
                    .foregroundStyle(.red)
                Text(courseName)
                    .font(.subheadline.bold())
                    .lineLimit(1)
            }

            Spacer()

            Button {
                hapticTrigger.toggle()
                liveActivityService.endClassSession()
            } label: {
                Text("End")
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(.red.gradient, in: Capsule())
            }
            .sensoryFeedback(.impact(weight: .heavy), trigger: hapticTrigger)
            .accessibilityLabel("End live session")
            .accessibilityHint("Double tap to end the current live class session")
        }
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: 14)
                .fill(.clear)
                .glassEffect(.regular.tint(.red), in: RoundedRectangle(cornerRadius: 14))
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Start Session Button

    private var startSessionButton: some View {
        Button {
            hapticTrigger.toggle()
            showStartSheet = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "dot.radiowaves.left.and.right")
                    .font(.subheadline)
                    .foregroundStyle(.purple)
                Text("Start Live Session")
                    .font(.subheadline.bold())
                    .foregroundStyle(.black)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.black.opacity(0.4))
            }
            .padding(14)
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(Color.purple.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
        .accessibilityLabel("Start live session")
        .accessibilityHint("Double tap to configure and start a Dynamic Island live session for \(courseName)")
        .sheet(isPresented: $showStartSheet) {
            startSessionSheet
        }
    }

    // MARK: - Start Session Sheet

    private var startSessionSheet: some View {
        NavigationStack {
            Form {
                Section("Session Details") {
                    HStack {
                        Image(systemName: "book.fill")
                            .foregroundStyle(.purple)
                        Text(courseName)
                            .font(.subheadline.bold())
                    }

                    TextField("Current Topic", text: $topic)
                        .textContentType(.none)
                }

                Section("Duration") {
                    Picker("Duration", selection: $duration) {
                        Text("30 min").tag(30)
                        Text("45 min").tag(45)
                        Text("60 min").tag(60)
                        Text("90 min").tag(90)
                        Text("120 min").tag(120)
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    HStack {
                        Image(systemName: "island.fill")
                            .foregroundStyle(.cyan)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Dynamic Island")
                                .font(.subheadline.bold())
                            Text("Students will see session progress on their lock screen and Dynamic Island")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Live Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        hapticTrigger.toggle()
                        showStartSheet = false
                    }
                    .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Start") {
                        hapticTrigger.toggle()
                        let sessionTopic = topic.isEmpty ? "General Session" : topic
                        liveActivityService.startClassSession(
                            courseName: courseName,
                            teacherName: teacherName,
                            duration: duration,
                            topic: sessionTopic,
                            color: "purple"
                        )
                        showStartSheet = false
                    }
                    .fontWeight(.semibold)
                    .sensoryFeedback(.impact(weight: .medium), trigger: hapticTrigger)
                }
            }
        }
        .presentationDetents([.medium])
    }
}
