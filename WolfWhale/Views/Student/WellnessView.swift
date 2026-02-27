import SwiftUI
import HealthKit
#if canImport(UIKit)
import UIKit
#endif

struct WellnessView: View {
    let viewModel: AppViewModel
    @State private var healthService = HealthService()
    @State private var hapticTrigger = false
    @State private var showWorkoutPicker = false
    @State private var animateScore = false
    @State private var selectedWorkoutType: HKWorkoutActivityType = .functionalStrengthTraining

    private var scoreColor: Color {
        guard let score = healthService.wellnessData?.wellnessScore else { return .gray }
        switch score {
        case 0..<30: return .red
        case 30..<50: return .orange
        case 50..<70: return .yellow
        case 70..<85: return .green
        default: return .mint
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if !healthService.isAuthorized {
                    authorizationView
                } else if healthService.isLoading && healthService.wellnessData == nil {
                    loadingView
                } else {
                    dashboardContent
                }
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle("Wellness")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showWorkoutPicker) {
                workoutPickerSheet
            }
        }
    }

    // MARK: - Authorization View

    private var authorizationView: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.indigo.opacity(0.3), .purple.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)

                Image(systemName: "heart.text.clipboard.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.indigo, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .symbolRenderingMode(.hierarchical)
                    .compatBreathePulsePeriodic(delay: 2)
            }

            VStack(spacing: 12) {
                Text("Track Your Wellness")
                    .font(.title2.bold())

                Text("Connect HealthKit to track your PE class activity, steps, calories, sleep, and more.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            VStack(alignment: .leading, spacing: 16) {
                permissionRow(icon: "figure.walk", title: "Steps & Distance", color: .green)
                permissionRow(icon: "flame.fill", title: "Active Calories", color: .orange)
                permissionRow(icon: "heart.fill", title: "Heart Rate", color: .red)
                permissionRow(icon: "bed.double.fill", title: "Sleep Analysis", color: .indigo)
                permissionRow(icon: "figure.run", title: "PE Workouts", color: .purple)
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 20)

            Button {
                hapticTrigger.toggle()
                Task {
                    await healthService.requestAuthorization()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "heart.fill")
                    Text("Enable HealthKit")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [.indigo, .purple],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    in: RoundedRectangle(cornerRadius: 16)
                )
                .foregroundStyle(.white)
            }
            .padding(.horizontal, 32)
            .sensoryFeedback(.impact(weight: .medium), trigger: hapticTrigger)

            if let error = healthService.error {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()
        }
    }

    private func permissionRow(icon: String, title: String, color: Color) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(color)
                .frame(width: 32)
            Text(title)
                .font(.subheadline)
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green.opacity(0.6))
                .font(.subheadline)
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Loading wellness data...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityLabel("Loading wellness data")
    }

    // MARK: - Dashboard Content

    private var dashboardContent: some View {
        ScrollView {
            VStack(spacing: 20) {
                wellnessScoreSection
                todayStatsSection
                workoutControlSection
                weeklyChartSection
                sleepSection
                hydrationSection
                workoutHistorySection
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
        .refreshable {
            await healthService.loadAllData()
        }
    }

    // MARK: - Wellness Score Ring

    private var wellnessScoreSection: some View {
        VStack(spacing: 16) {
            Text("Wellness Score")
                .font(.headline)

            ZStack {
                // Background ring
                Circle()
                    .stroke(scoreColor.opacity(0.15), lineWidth: 20)
                    .frame(width: 180, height: 180)

                // Animated score ring
                Circle()
                    .trim(from: 0, to: animateScore ? CGFloat(healthService.wellnessData?.wellnessScore ?? 0) / 100.0 : 0)
                    .stroke(
                        AngularGradient(
                            colors: [scoreColor.opacity(0.7), scoreColor, scoreColor.opacity(0.7)],
                            center: .center,
                            startAngle: .degrees(-90),
                            endAngle: .degrees(270)
                        ),
                        style: StrokeStyle(lineWidth: 20, lineCap: .round)
                    )
                    .frame(width: 180, height: 180)
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 4) {
                    Text("\(healthService.wellnessData?.wellnessScore ?? 0)")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundStyle(scoreColor)
                        .contentTransition(.numericText())

                    Text("out of 100")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 8)
            .onAppear {
                withAnimation(.spring(duration: 1.5, bounce: 0.2).delay(0.3)) {
                    animateScore = true
                }
            }

            Text(wellnessMessage)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Wellness score: \(healthService.wellnessData?.wellnessScore ?? 0) out of 100. \(wellnessMessage)")
    }

    private var wellnessMessage: String {
        guard let score = healthService.wellnessData?.wellnessScore else { return "No data yet" }
        switch score {
        case 0..<30: return "Let's get moving! Every step counts."
        case 30..<50: return "Good start! Keep building healthy habits."
        case 50..<70: return "Nice work! You're on the right track."
        case 70..<85: return "Great job! You're crushing your goals."
        default: return "Outstanding! You're a wellness champion!"
        }
    }

    // MARK: - Today's Stats Cards

    private var todayStatsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Today's Activity")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                statCard(
                    icon: "figure.walk",
                    value: formattedSteps,
                    label: "Steps",
                    color: .green
                )
                statCard(
                    icon: "location.fill",
                    value: formattedDistance,
                    label: "Distance",
                    color: .blue
                )
                statCard(
                    icon: "flame.fill",
                    value: formattedCalories,
                    label: "Calories",
                    color: .orange
                )
                statCard(
                    icon: "heart.fill",
                    value: formattedHeartRate,
                    label: "Resting HR",
                    color: .red
                )
            }
        }
    }

    private func statCard(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)

            Text(value)
                .font(.title3.bold())
                .contentTransition(.numericText())

            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }

    // MARK: - Workout Control

    private var workoutControlSection: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "figure.run")
                    .foregroundStyle(.purple)
                Text("PE Workout")
                    .font(.headline)
                Spacer()

                if healthService.isWorkoutActive, let start = healthService.activeWorkoutStart {
                    Text(start, style: .timer)
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.purple)
                }
            }

            if healthService.isWorkoutActive {
                Button {
                    hapticTrigger.toggle()
                    Task {
                        await healthService.stopPEWorkout()
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "stop.circle.fill")
                            .font(.title3)
                        Text("End Workout")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(.red.gradient, in: RoundedRectangle(cornerRadius: 14))
                    .foregroundStyle(.white)
                }
                .sensoryFeedback(.impact(weight: .medium), trigger: hapticTrigger)
            } else {
                Button {
                    hapticTrigger.toggle()
                    showWorkoutPicker = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "play.circle.fill")
                            .font(.title3)
                        Text("Start PE Workout")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(
                            colors: [.indigo, .purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        in: RoundedRectangle(cornerRadius: 14)
                    )
                    .foregroundStyle(.white)
                }
                .sensoryFeedback(.impact(weight: .medium), trigger: hapticTrigger)
            }

            if let error = healthService.error {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("PE Workout controls")
    }

    // MARK: - Weekly Step Chart (Bar Chart using SwiftUI Shapes)

    private var weeklyChartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundStyle(.indigo)
                Text("Weekly Steps")
                    .font(.headline)
                Spacer()
                if let data = healthService.wellnessData {
                    let total = data.weeklySteps.reduce(0) { $0 + $1.steps }
                    Text("\(total.formatted()) total")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if let data = healthService.wellnessData, !data.weeklySteps.isEmpty {
                weeklyBarChart(data: data.weeklySteps)
            } else {
                Text("No step data available for this week.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
    }

    private func weeklyBarChart(data: [DailyStepCount]) -> some View {
        let maxSteps = max(data.map(\.steps).max() ?? 1, 1)
        let dayFormatter: DateFormatter = {
            let f = DateFormatter()
            f.dateFormat = "EEE"
            return f
        }()

        return VStack(spacing: 8) {
            // Step goal reference line
            HStack {
                Spacer()
                Text("Goal: 10,000")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            GeometryReader { geo in
                let barWidth = max((geo.size.width - CGFloat(data.count - 1) * 8) / CGFloat(data.count), 10)
                let chartHeight = geo.size.height - 24

                ZStack(alignment: .bottom) {
                    // Goal line
                    let goalRatio = min(CGFloat(10_000) / CGFloat(maxSteps), 1.0)
                    Rectangle()
                        .fill(.indigo.opacity(0.3))
                        .frame(height: 1)
                        .offset(y: -(chartHeight * goalRatio))

                    HStack(alignment: .bottom, spacing: 8) {
                        ForEach(data) { entry in
                            VStack(spacing: 4) {
                                let ratio = maxSteps > 0 ? CGFloat(entry.steps) / CGFloat(maxSteps) : 0
                                let barHeight = max(chartHeight * ratio, 4)

                                RoundedRectangle(cornerRadius: 6)
                                    .fill(
                                        LinearGradient(
                                            colors: entry.steps >= 10_000
                                                ? [.green, .mint]
                                                : [.indigo, .purple],
                                            startPoint: .bottom,
                                            endPoint: .top
                                        )
                                    )
                                    .frame(width: barWidth, height: barHeight)

                                Text(dayFormatter.string(from: entry.date))
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .frame(height: 160)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Weekly steps bar chart showing 7-day trends")
        }
    }

    // MARK: - Sleep Summary

    private var sleepSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "bed.double.fill")
                    .foregroundStyle(.indigo)
                Text("Sleep")
                    .font(.headline)
                Spacer()
            }

            if let sleep = healthService.wellnessData?.sleepHours {
                HStack(spacing: 20) {
                    VStack(spacing: 6) {
                        Text(String(format: "%.1f", sleep))
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundStyle(.indigo)
                        Text("hours")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        sleepQualityBar(hours: sleep)

                        Text(sleepQualityMessage(hours: sleep))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            } else {
                HStack {
                    Image(systemName: "moon.zzz")
                        .foregroundStyle(.secondary)
                    Text("No sleep data recorded recently")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 12)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Sleep: \(healthService.wellnessData?.sleepHours.map { String(format: "%.1f hours", $0) } ?? "No data")")
    }

    private func sleepQualityBar(hours: Double) -> some View {
        let quality = min(hours / 8.0, 1.0)
        let barColor: Color = hours >= 7 ? .indigo : (hours >= 5 ? .orange : .red)

        return VStack(alignment: .leading, spacing: 4) {
            Text("Quality")
                .font(.caption2)
                .foregroundStyle(.secondary)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(barColor.opacity(0.15))
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [barColor.opacity(0.7), barColor],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * quality)
                }
            }
            .frame(height: 8)
        }
    }

    private func sleepQualityMessage(hours: Double) -> String {
        switch hours {
        case 0..<5: return "Try to get more rest tonight."
        case 5..<7: return "A bit short. Aim for 7-9 hours."
        case 7..<9: return "Great sleep! Right in the optimal range."
        default: return "Plenty of rest. Watch for oversleeping."
        }
    }

    // MARK: - Hydration Tracker

    private var hydrationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "drop.fill")
                    .foregroundStyle(.cyan)
                Text("Hydration")
                    .font(.headline)
                Spacer()
                Text("\(healthService.hydrationGlasses) / 8 glasses")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                ForEach(0..<8, id: \.self) { index in
                    Button {
                        hapticTrigger.toggle()
                        if index < healthService.hydrationGlasses {
                            // Tapping a filled glass does nothing in forward mode
                        } else {
                            // Fill up to this glass
                            while healthService.hydrationGlasses <= index {
                                healthService.incrementHydration()
                            }
                        }
                    } label: {
                        Image(systemName: index < healthService.hydrationGlasses ? "drop.fill" : "drop")
                            .font(.title3)
                            .foregroundStyle(index < healthService.hydrationGlasses ? .cyan : .gray.opacity(0.4))
                            .frame(maxWidth: .infinity)
                    }
                    .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
                    .accessibilityLabel("Glass \(index + 1) of water\(index < healthService.hydrationGlasses ? ", consumed" : "")")
                }
            }
            .padding(.vertical, 8)

            // Reset button
            if healthService.hydrationGlasses > 0 {
                Button {
                    hapticTrigger.toggle()
                    healthService.decrementHydration()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "minus.circle")
                            .font(.caption)
                        Text("Remove last glass")
                            .font(.caption)
                    }
                    .foregroundStyle(.secondary)
                }
                .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Hydration tracker: \(healthService.hydrationGlasses) of 8 glasses consumed")
    }

    // MARK: - Workout History

    private var workoutHistorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "clock.arrow.circlepath")
                    .foregroundStyle(.purple)
                Text("Workout History")
                    .font(.headline)
                Spacer()
                Text("\(healthService.workoutHistory.count) workouts")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if healthService.workoutHistory.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "figure.run.circle")
                        .font(.title)
                        .foregroundStyle(.secondary)
                    Text("No workouts recorded yet")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("Start a PE workout to see your history here")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                ForEach(healthService.workoutHistory.prefix(10)) { workout in
                    workoutRow(workout)
                }
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
    }

    private func workoutRow(_ workout: PEWorkout) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [.indigo, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 40, height: 40)
                .overlay {
                    Image(systemName: workoutIcon(for: workout.activityType))
                        .font(.subheadline)
                        .foregroundStyle(.white)
                }

            VStack(alignment: .leading, spacing: 3) {
                Text(workout.activityType)
                    .font(.subheadline.bold())
                Text(workout.startDate, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                let duration = workout.endDate.timeIntervalSince(workout.startDate)
                Text("\(Int(duration / 60)) min")
                    .font(.subheadline.bold())
                    .foregroundStyle(.purple)
                Text("\(Int(workout.caloriesBurned)) cal")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(workout.activityType) on \(workout.startDate.formatted(.dateTime.month(.abbreviated).day())), \(Int(workout.endDate.timeIntervalSince(workout.startDate) / 60)) minutes, \(Int(workout.caloriesBurned)) calories")
    }

    private func workoutIcon(for type: String) -> String {
        switch type {
        case "Running": return "figure.run"
        case "Walking": return "figure.walk"
        case "Cycling": return "figure.outdoor.cycle"
        case "Swimming": return "figure.pool.swim"
        case "Basketball": return "figure.basketball"
        case "Soccer": return "figure.soccer"
        case "Tennis": return "figure.tennis"
        case "Volleyball": return "volleyball.fill"
        case "Dance": return "figure.dance"
        case "Yoga": return "figure.yoga"
        case "Gymnastics": return "figure.gymnastics"
        case "Track & Field": return "figure.track.and.field"
        case "Jump Rope": return "figure.jumprope"
        default: return "figure.strengthtraining.functional"
        }
    }

    // MARK: - Workout Picker Sheet

    private var workoutPickerSheet: some View {
        NavigationStack {
            List {
                Section {
                    workoutOption("Strength Training", type: .functionalStrengthTraining, icon: "figure.strengthtraining.functional")
                    workoutOption("Running", type: .running, icon: "figure.run")
                    workoutOption("Walking", type: .walking, icon: "figure.walk")
                    workoutOption("Cycling", type: .cycling, icon: "figure.outdoor.cycle")
                    workoutOption("Swimming", type: .swimming, icon: "figure.pool.swim")
                    workoutOption("Basketball", type: .basketball, icon: "figure.basketball")
                    workoutOption("Soccer", type: .soccer, icon: "figure.soccer")
                    workoutOption("Volleyball", type: .volleyball, icon: "volleyball.fill")
                    workoutOption("Dance", type: .socialDance, icon: "figure.dance")
                    workoutOption("Yoga", type: .yoga, icon: "figure.yoga")
                    workoutOption("Track & Field", type: .trackAndField, icon: "figure.track.and.field")
                    workoutOption("Jump Rope", type: .jumpRope, icon: "figure.jumprope")
                    workoutOption("Gymnastics", type: .gymnastics, icon: "figure.gymnastics")
                } header: {
                    Text("Select Activity")
                } footer: {
                    Text("Choose the activity type for your PE class workout.")
                }
            }
            .navigationTitle("Start Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showWorkoutPicker = false
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func workoutOption(_ name: String, type: HKWorkoutActivityType, icon: String) -> some View {
        Button {
            hapticTrigger.toggle()
            showWorkoutPicker = false
            Task {
                await healthService.startPEWorkout(activityType: type)
            }
        } label: {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(.purple)
                    .frame(width: 32)
                Text(name)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: hapticTrigger)
        .accessibilityLabel("Start \(name) workout")
    }

    // MARK: - Formatted Values

    private var formattedSteps: String {
        guard let data = healthService.wellnessData else { return "--" }
        return data.steps.formatted()
    }

    private var formattedDistance: String {
        guard let data = healthService.wellnessData else { return "--" }
        let km = data.distance / 1000.0
        return String(format: "%.1f km", km)
    }

    private var formattedCalories: String {
        guard let data = healthService.wellnessData else { return "--" }
        return "\(Int(data.activeCalories))"
    }

    private var formattedHeartRate: String {
        guard let data = healthService.wellnessData, let hr = data.restingHeartRate else { return "--" }
        return "\(Int(hr)) bpm"
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    WellnessView(viewModel: {
        let vm = AppViewModel()
        vm.loginAsDemo(role: .student)
        return vm
    }())
}
#endif
