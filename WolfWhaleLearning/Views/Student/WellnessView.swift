import SwiftUI
import Charts

struct WellnessView: View {
    @State private var healthService = HealthService()
    @State private var hapticTrigger = false
    @State private var showStopConfirmation = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if !healthService.isAuthorized {
                    authorizationBanner
                }

                if healthService.isStudySessionActive {
                    activeSessionCard
                }

                if healthService.isAuthorized {
                    todayStatsSection
                    weeklyChartSection
                    studySessionButton
                    healthTipsSection
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Study Wellness")
        .navigationBarTitleDisplayMode(.large)
        .task {
            if healthService.isAuthorized {
                await healthService.refreshAllData()
            }
        }
        .refreshable {
            if healthService.isAuthorized {
                await healthService.refreshAllData()
            }
        }
    }

    // MARK: - Authorization Banner

    private var authorizationBanner: some View {
        VStack(spacing: 14) {
            Image(systemName: "heart.text.clipboard")
                .font(.system(size: 40))
                .foregroundStyle(.pink.gradient)
                .symbolEffect(.pulse)

            Text("Enable Health Tracking")
                .font(.headline)

            Text("Connect HealthKit to track your study sessions, steps, and sleep for better wellness insights.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                hapticTrigger.toggle()
                Task {
                    await healthService.requestAuthorization()
                }
            } label: {
                Label("Connect HealthKit", systemImage: "heart.fill")
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(.pink.gradient, in: .rect(cornerRadius: 12))
            }
            .sensoryFeedback(.impact(weight: .medium), trigger: hapticTrigger)
        }
        .padding(20)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Enable Health Tracking. Connect HealthKit to track study sessions, steps, and sleep.")
        .accessibilityAddTraits(.isButton)
    }

    // MARK: - Active Session Card

    private var activeSessionCard: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "brain.head.profile.fill")
                    .font(.title2)
                    .foregroundStyle(.purple)
                    .symbolEffect(.pulse)
                Text("Study Session Active")
                    .font(.headline)
                Spacer()
            }

            Text(healthService.formattedElapsedTime)
                .font(.system(size: 48, weight: .bold, design: .monospaced))
                .foregroundStyle(.primary)
                .contentTransition(.numericText())
                .animation(.linear(duration: 0.1), value: healthService.studySessionElapsed)

            Button {
                hapticTrigger.toggle()
                showStopConfirmation = true
            } label: {
                Label("Stop Session", systemImage: "stop.circle.fill")
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(.red.gradient, in: .rect(cornerRadius: 12))
            }
            .sensoryFeedback(.impact(weight: .heavy), trigger: hapticTrigger)
            .confirmationDialog("End Study Session?", isPresented: $showStopConfirmation) {
                Button("End & Save", role: .destructive) {
                    Task {
                        await healthService.stopStudySession()
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Your study time will be saved to HealthKit as a mindful session.")
            }
        }
        .padding(20)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(.purple.opacity(0.3), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Study session active. Elapsed time: \(healthService.formattedElapsedTime)")
    }

    // MARK: - Today's Stats

    private var todayStatsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Today")
                .font(.headline)

            HStack(spacing: 12) {
                statsCard(
                    icon: "brain.head.profile.fill",
                    title: "Study Time",
                    value: healthService.formattedStudyTime,
                    color: .purple,
                    detail: "mindful minutes"
                )

                statsCard(
                    icon: "figure.walk",
                    title: "Steps",
                    value: "\(healthService.todaySteps.formatted())",
                    color: .green,
                    detail: "today"
                )

                statsCard(
                    icon: "moon.zzz.fill",
                    title: "Sleep",
                    value: healthService.formattedSleepDuration,
                    color: .indigo,
                    detail: "last night"
                )
            }
        }
    }

    private func statsCard(icon: String, title: String, value: String, color: Color, detail: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color.gradient)

            Text(value)
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            VStack(spacing: 2) {
                Text(title)
                    .font(.caption.bold())
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .padding(.horizontal, 8)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value), \(detail)")
    }

    // MARK: - Weekly Chart

    private var weeklyChartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Weekly Study Time")
                    .font(.headline)
                Spacer()
                if let total = weeklyTotal {
                    Text(total)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            if healthService.weeklyStudyData.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "chart.bar.fill")
                            .font(.title)
                            .foregroundStyle(.tertiary)
                        Text("No study data yet")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 30)
                    Spacer()
                }
                .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
            } else {
                Chart(healthService.weeklyStudyData) { day in
                    BarMark(
                        x: .value("Day", day.dayLabel),
                        y: .value("Minutes", day.minutes)
                    )
                    .foregroundStyle(.purple.gradient)
                    .cornerRadius(6)
                }
                .chartYAxisLabel("Minutes")
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
                .frame(height: 200)
                .padding(16)
                .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
                .accessibilityLabel("Weekly study time chart showing the last 7 days")
            }
        }
    }

    private var weeklyTotal: String? {
        let total = healthService.weeklyStudyData.reduce(0) { $0 + $1.minutes }
        guard total > 0 else { return nil }
        let hours = Int(total) / 60
        let mins = Int(total) % 60
        if hours > 0 && mins > 0 {
            return "\(hours)h \(mins)m total"
        } else if hours > 0 {
            return "\(hours)h total"
        } else {
            return "\(mins)m total"
        }
    }

    // MARK: - Study Session Button

    private var studySessionButton: some View {
        Button {
            hapticTrigger.toggle()
            if healthService.isStudySessionActive {
                showStopConfirmation = true
            } else {
                healthService.startStudySession()
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: healthService.isStudySessionActive ? "stop.circle.fill" : "play.circle.fill")
                    .font(.title2)
                    .symbolEffect(.bounce, value: hapticTrigger)

                VStack(alignment: .leading, spacing: 2) {
                    Text(healthService.isStudySessionActive ? "Stop Study Session" : "Start Study Session")
                        .font(.subheadline.bold())
                    Text(healthService.isStudySessionActive ? "Tap to end and save your session" : "Track your focus time as mindful minutes")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.8))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
            }
            .foregroundStyle(.white)
            .padding(16)
            .background(
                healthService.isStudySessionActive
                    ? AnyShapeStyle(.red.gradient)
                    : AnyShapeStyle(.purple.gradient),
                in: .rect(cornerRadius: 16)
            )
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: hapticTrigger)
        .accessibilityLabel(healthService.isStudySessionActive ? "Stop study session" : "Start study session")
        .accessibilityHint(healthService.isStudySessionActive ? "Double tap to stop and save your study session" : "Double tap to begin tracking your study time")
    }

    // MARK: - Health Tips

    private var healthTipsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Wellness Tips")
                .font(.headline)

            VStack(spacing: 10) {
                if healthService.todaySteps < 5000 {
                    tipRow(
                        icon: "figure.walk",
                        color: .green,
                        title: "Take a Walk!",
                        message: "You've only taken \(healthService.todaySteps.formatted()) steps today. A short walk can boost your focus and creativity."
                    )
                } else {
                    tipRow(
                        icon: "figure.walk",
                        color: .green,
                        title: "Great Job Moving!",
                        message: "You've hit \(healthService.todaySteps.formatted()) steps today. Keep it up!"
                    )
                }

                if healthService.lastSleepHours > 0 && healthService.lastSleepHours < 7 {
                    tipRow(
                        icon: "moon.zzz.fill",
                        color: .indigo,
                        title: "Get More Sleep!",
                        message: "You only got \(healthService.formattedSleepDuration) of sleep last night. Aim for 7-9 hours for optimal learning."
                    )
                } else if healthService.lastSleepHours >= 7 {
                    tipRow(
                        icon: "moon.zzz.fill",
                        color: .indigo,
                        title: "Well Rested!",
                        message: "You got \(healthService.formattedSleepDuration) of sleep. Your brain is ready to learn!"
                    )
                }

                if healthService.todayStudyMinutes < 30 {
                    tipRow(
                        icon: "brain.head.profile.fill",
                        color: .purple,
                        title: "Study More Today",
                        message: "You've studied \(healthService.formattedStudyTime) so far. Try to get at least 30 minutes of focused study time."
                    )
                } else if healthService.todayStudyMinutes >= 120 {
                    tipRow(
                        icon: "cup.and.heat.waves.fill",
                        color: .orange,
                        title: "Take a Break!",
                        message: "You've been studying for \(healthService.formattedStudyTime). Remember to rest your eyes and stretch."
                    )
                } else {
                    tipRow(
                        icon: "brain.head.profile.fill",
                        color: .purple,
                        title: "Good Focus!",
                        message: "You've studied \(healthService.formattedStudyTime) today. Keep up the great work!"
                    )
                }
            }
        }
    }

    private func tipRow(icon: String, color: Color, title: String, message: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.bold())
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(14)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(message)")
    }
}

#Preview {
    NavigationStack {
        WellnessView()
    }
}
