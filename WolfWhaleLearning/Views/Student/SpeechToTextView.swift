import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct SpeechToTextView: View {
    let viewModel: AppViewModel
    @State private var speechService = SpeechService()
    @State private var practiceMode = false
    @State private var expectedText = ""
    @State private var pronunciationScore: Double?
    @State private var hapticTrigger = false
    @State private var showLanguagePicker = false
    @State private var barAnimations: [CGFloat] = Array(repeating: 0.1, count: 20)
    @State private var animateVisualizer = false
    @State private var visualizerTimer: Timer?
    @State private var showCopiedToast = false
    @State private var recordButtonScale: CGFloat = 1.0
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if !speechService.isAuthorized {
                        permissionSection
                    } else {
                        languageSection
                        transcriptionSection
                        audioVisualizerView
                        controlsSection
                        confidenceSection

                        if practiceMode {
                            practiceSection
                        }

                        actionsSection
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 40)
            }
            .background(
                LinearGradient(
                    colors: [
                        Color.indigo.opacity(0.12),
                        Color(UIColor.systemGroupedBackground)
                    ],
                    startPoint: .top,
                    endPoint: .center
                )
            )
            .navigationTitle("Speech to Text")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        practiceMode.toggle()
                        if !practiceMode {
                            pronunciationScore = nil
                            expectedText = ""
                        }
                    } label: {
                        Label(
                            practiceMode ? "Free Mode" : "Practice",
                            systemImage: practiceMode ? "text.bubble" : "graduationcap"
                        )
                        .font(.subheadline)
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .overlay(alignment: .top) {
                if showCopiedToast {
                    copiedToast
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .task {
                if !speechService.isAuthorized {
                    await speechService.requestAuthorization()
                }
            }
            .onAppear {
                startVisualizerAnimation()
            }
            .onDisappear {
                if speechService.isRecording {
                    speechService.stopRecording()
                }
                visualizerTimer?.invalidate()
                visualizerTimer = nil
            }
        }
    }

    // MARK: - Permission Section

    private var permissionSection: some View {
        VStack(spacing: 24) {
            Spacer().frame(height: 40)

            Image(systemName: "waveform.and.mic")
                .font(.system(size: 64))
                .foregroundStyle(.indigo.gradient)
                .symbolEffect(.pulse, options: .repeating)

            Text("Speech Recognition")
                .font(.title2.bold())

            Text("Allow access to your microphone and speech recognition to transcribe speech in real time. This feature supports multiple languages for language learning.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            if let error = speechService.error {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Button {
                hapticTrigger.toggle()
                Task {
                    await speechService.requestAuthorization()
                }
            } label: {
                HStack(spacing: 8) {
                    if speechService.isLoading {
                        ProgressView()
                            .controlSize(.small)
                            .tint(.white)
                    }
                    Text("Enable Speech Recognition")
                        .font(.headline)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(.indigo.gradient, in: .rect(cornerRadius: 14))
            }
            .disabled(speechService.isLoading)
            .hapticFeedback(.impact(weight: .medium), trigger: hapticTrigger)

            #if os(iOS)
            Button {
                if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsURL)
                }
            } label: {
                Text("Open Settings")
                    .font(.subheadline)
                    .foregroundStyle(.indigo)
            }
            #endif
        }
        .padding(28)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 20))
    }

    // MARK: - Language Section

    private var languageSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Language")
                    .font(.headline)
                Spacer()
                Button {
                    hapticTrigger.toggle()
                    showLanguagePicker.toggle()
                } label: {
                    HStack(spacing: 6) {
                        Text(speechService.selectedLanguage.flagEmoji)
                        Text(speechService.selectedLanguage.displayName)
                            .font(.subheadline.bold())
                        Image(systemName: "chevron.down")
                            .font(.caption.bold())
                    }
                    .foregroundStyle(.indigo)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.indigo.opacity(0.1), in: Capsule())
                }
                .hapticFeedback(.impact(weight: .light), trigger: hapticTrigger)
            }

            if showLanguagePicker {
                languageGrid
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.snappy, value: showLanguagePicker)
    }

    private var languageGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 10) {
            ForEach(SpeechLanguage.allCases) { language in
                let isSelected = language == speechService.selectedLanguage
                Button {
                    hapticTrigger.toggle()
                    withAnimation(.snappy) {
                        speechService.changeLanguage(language)
                        showLanguagePicker = false
                    }
                } label: {
                    VStack(spacing: 6) {
                        Text(language.flagEmoji)
                            .font(.title)
                        Text(language.displayName)
                            .font(.caption.bold())
                            .foregroundStyle(isSelected ? .white : .primary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        isSelected
                            ? AnyShapeStyle(.indigo.gradient)
                            : AnyShapeStyle(.ultraThinMaterial),
                        in: .rect(cornerRadius: 12)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? Color.indigo.opacity(0.6) : .clear, lineWidth: 1.5)
                    )
                }
                .buttonStyle(.plain)
                .hapticFeedback(.impact(weight: .light), trigger: hapticTrigger)
            }
        }
        .padding(14)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

    // MARK: - Transcription Section

    private var transcriptionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(practiceMode ? "Your Speech" : "Transcription")
                    .font(.headline)

                Spacer()

                if !speechService.transcribedText.isEmpty {
                    Button {
                        hapticTrigger.toggle()
                        UIPasteboard.general.string = speechService.transcribedText
                        withAnimation(.snappy) {
                            showCopiedToast = true
                        }
                        Task {
                            try? await Task.sleep(for: .seconds(2))
                            withAnimation(.snappy) {
                                showCopiedToast = false
                            }
                        }
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .font(.subheadline)
                            .foregroundStyle(.indigo)
                    }
                    .hapticFeedback(.impact(weight: .light), trigger: hapticTrigger)
                }
            }

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .frame(minHeight: 160)

                if speechService.transcribedText.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: speechService.isRecording ? "waveform" : "mic.badge.plus")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                            .symbolEffect(.variableColor.iterative, options: .repeating, value: speechService.isRecording)

                        Text(speechService.isRecording ? "Listening..." : "Tap the microphone to start")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 160)
                } else {
                    wordHighlightedText
                        .padding(16)
                }
            }

            if let error = speechService.error {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: speechService.transcribedText)
    }

    /// Displays recognized words with color-coded confidence highlighting.
    private var wordHighlightedText: some View {
        SpeechFlowLayout(spacing: 4) {
            ForEach(speechService.recognizedWords) { word in
                Text(word.text)
                    .font(.body)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(confidenceColor(for: word.confidence).opacity(0.15), in: .rect(cornerRadius: 4))
                    .foregroundStyle(confidenceColor(for: word.confidence))
            }
        }
    }

    // MARK: - Audio Visualizer

    private var audioVisualizerView: some View {
        VStack(spacing: 8) {
            HStack(spacing: 3) {
                ForEach(0..<20, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(
                            LinearGradient(
                                colors: [
                                    .indigo.opacity(0.6),
                                    .indigo
                                ],
                                startPoint: .bottom,
                                endPoint: .top
                            )
                        )
                        .frame(width: 6)
                        .frame(height: speechService.isRecording ? max(4, barAnimations[index] * 60) : 4)
                        .animation(
                            .easeInOut(duration: 0.15),
                            value: animateVisualizer
                        )
                }
            }
            .frame(height: 64)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(.ultraThinMaterial, in: .rect(cornerRadius: 14))
            .accessibilityHidden(true)

            if speechService.isRecording {
                Text("Audio Level: \(Int(speechService.audioLevel * 100))%")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: speechService.isRecording)
    }

    // MARK: - Controls Section

    private var controlsSection: some View {
        VStack(spacing: 16) {
            // Record button
            Button {
                hapticTrigger.toggle()
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    speechService.toggleRecording()
                }
            } label: {
                ZStack {
                    // Outer pulsing ring when recording
                    if speechService.isRecording {
                        Circle()
                            .stroke(.red.opacity(0.3), lineWidth: 3)
                            .frame(width: 96, height: 96)
                            .scaleEffect(recordButtonScale)
                            .animation(
                                .easeInOut(duration: 1.0).repeatForever(autoreverses: true),
                                value: speechService.isRecording
                            )
                    }

                    // Main button
                    Circle()
                        .fill(
                            speechService.isRecording
                                ? LinearGradient(colors: [.red, .red.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing)
                                : LinearGradient(colors: [.indigo, .indigo.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .frame(width: 80, height: 80)
                        .shadow(
                            color: speechService.isRecording ? .red.opacity(0.4) : .indigo.opacity(0.4),
                            radius: 16,
                            y: 4
                        )

                    Image(systemName: speechService.isRecording ? "stop.fill" : "mic.fill")
                        .font(.title)
                        .foregroundStyle(.white)
                        .contentTransition(.symbolEffect(.replace))
                }
            }
            .hapticFeedback(.impact(weight: .heavy), trigger: hapticTrigger)
            .accessibilityLabel(speechService.isRecording ? "Stop recording" : "Start recording")
            .onAppear {
                recordButtonScale = 1.15
            }

            Text(speechService.isRecording ? "Tap to stop" : "Tap to record")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    // MARK: - Confidence Section

    private var confidenceSection: some View {
        Group {
            if !speechService.recognizedWords.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Confidence")
                            .font(.headline)
                        Spacer()
                        Text("\(Int(speechService.confidenceLevel * 100))%")
                            .font(.subheadline.bold().monospacedDigit())
                            .foregroundStyle(confidenceColor(for: speechService.confidenceLevel))
                    }

                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(.secondary.opacity(0.15))
                                .frame(height: 10)

                            RoundedRectangle(cornerRadius: 6)
                                .fill(confidenceColor(for: speechService.confidenceLevel).gradient)
                                .frame(width: geometry.size.width * CGFloat(speechService.confidenceLevel), height: 10)
                                .animation(.easeInOut(duration: 0.3), value: speechService.confidenceLevel)
                        }
                    }
                    .frame(height: 10)

                    HStack(spacing: 16) {
                        confidenceLegendItem(color: .green, label: "High (>80%)")
                        confidenceLegendItem(color: .orange, label: "Medium (50-80%)")
                        confidenceLegendItem(color: .red, label: "Low (<50%)")
                    }
                    .font(.caption2)
                }
                .padding(16)
                .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .animation(.snappy, value: speechService.recognizedWords.isEmpty)
    }

    private func confidenceLegendItem(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(label)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Practice Section

    private var practiceSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "graduationcap.fill")
                    .foregroundStyle(.indigo)
                Text("Pronunciation Practice")
                    .font(.headline)
            }

            Text("Enter the text you want to practice saying, then record yourself speaking it.")
                .font(.caption)
                .foregroundStyle(.secondary)

            TextField("Enter expected text...", text: $expectedText, axis: .vertical)
                .textFieldStyle(.plain)
                .padding(12)
                .background(.ultraThinMaterial, in: .rect(cornerRadius: 12))
                .lineLimit(3...6)

            if !expectedText.isEmpty && !speechService.transcribedText.isEmpty {
                Button {
                    hapticTrigger.toggle()
                    withAnimation(.snappy) {
                        pronunciationScore = speechService.calculatePronunciationScore(
                            expected: expectedText,
                            spoken: speechService.transcribedText
                        )
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.seal.fill")
                        Text("Check Pronunciation")
                            .font(.subheadline.bold())
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(.indigo.gradient, in: .rect(cornerRadius: 12))
                }
                .hapticFeedback(.impact(weight: .medium), trigger: hapticTrigger)
            }

            if let score = pronunciationScore {
                pronunciationScoreCard(score: score)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
        .animation(.snappy, value: pronunciationScore)
    }

    private func pronunciationScoreCard(score: Double) -> some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .stroke(.secondary.opacity(0.15), lineWidth: 8)
                    .frame(width: 100, height: 100)

                Circle()
                    .trim(from: 0, to: CGFloat(score))
                    .stroke(
                        scoreColor(for: score).gradient,
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .frame(width: 100, height: 100)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.8), value: score)

                VStack(spacing: 2) {
                    Text("\(Int(score * 100))%")
                        .font(.title2.bold().monospacedDigit())
                    Text("Score")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Text(scoreLabel(for: score))
                .font(.subheadline.bold())
                .foregroundStyle(scoreColor(for: score))

            Text(scoreFeedback(for: score))
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            // Show word comparison
            if !expectedText.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: "text.book.closed")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("Expected:")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                    }
                    Text(expectedText)
                        .font(.caption)
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.secondary.opacity(0.08), in: .rect(cornerRadius: 8))

                    HStack(spacing: 6) {
                        Image(systemName: "mic")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("You said:")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                    }
                    Text(speechService.transcribedText)
                        .font(.caption)
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.secondary.opacity(0.08), in: .rect(cornerRadius: 8))
                }
            }
        }
        .padding(16)
        .background(scoreColor(for: score).opacity(0.08), in: .rect(cornerRadius: 14))
    }

    // MARK: - Actions Section

    private var actionsSection: some View {
        VStack(spacing: 10) {
            if !speechService.transcribedText.isEmpty && !speechService.isRecording {
                Button {
                    hapticTrigger.toggle()
                    speechService.transcribedText = ""
                    speechService.recognizedWords = []
                    speechService.confidenceLevel = 0
                    pronunciationScore = nil
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.counterclockwise")
                        Text("Clear & Start Over")
                            .font(.subheadline.bold())
                    }
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(.red.opacity(0.1), in: .rect(cornerRadius: 12))
                }
                .hapticFeedback(.impact(weight: .light), trigger: hapticTrigger)
            }
        }
    }

    // MARK: - Copied Toast

    private var copiedToast: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
            Text("Copied to clipboard")
                .font(.subheadline.bold())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: Capsule())
        .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
        .padding(.top, 8)
    }

    // MARK: - Helpers

    private func confidenceColor(for confidence: Float) -> Color {
        switch confidence {
        case 0.8...: .green
        case 0.5..<0.8: .orange
        default: .red
        }
    }

    private func scoreColor(for score: Double) -> Color {
        switch score {
        case 0.85...: .green
        case 0.6..<0.85: .orange
        default: .red
        }
    }

    private func scoreLabel(for score: Double) -> String {
        switch score {
        case 0.9...: "Excellent!"
        case 0.75..<0.9: "Good Job!"
        case 0.5..<0.75: "Keep Practicing"
        default: "Try Again"
        }
    }

    private func scoreFeedback(for score: Double) -> String {
        switch score {
        case 0.9...: "Your pronunciation is very close to the expected text. Great work!"
        case 0.75..<0.9: "You are on the right track. A few words could use some refinement."
        case 0.5..<0.75: "Some parts were recognized differently. Try speaking more slowly and clearly."
        default: "The spoken text differs significantly from the expected text. Try again at a slower pace."
        }
    }

    private func startVisualizerAnimation() {
        visualizerTimer?.invalidate()
        visualizerTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            Task { @MainActor in
                guard visualizerTimer != nil else { return }
                if speechService.isRecording {
                    let baseLevel = CGFloat(speechService.audioLevel)
                    for i in 0..<barAnimations.count {
                        barAnimations[i] = max(0.05, baseLevel + CGFloat.random(in: -0.15...0.15))
                    }
                    animateVisualizer.toggle()
                } else {
                    for i in 0..<barAnimations.count {
                        barAnimations[i] = 0.05
                    }
                    animateVisualizer.toggle()
                }
            }
        }
    }
}

// MARK: - Flow Layout

/// A simple horizontal flow layout that wraps content to the next line
/// when the available width is exceeded. Used for word-by-word display.
private struct SpeechFlowLayout: Layout {
    var spacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)

        for (index, position) in result.positions.enumerated() {
            guard index < subviews.count else { break }
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }

    private func arrangeSubviews(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if currentX + size.width > maxWidth && currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }

            positions.append(CGPoint(x: currentX, y: currentY))
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
            maxX = max(maxX, currentX)
        }

        return (
            size: CGSize(width: maxX, height: currentY + lineHeight),
            positions: positions
        )
    }
}
