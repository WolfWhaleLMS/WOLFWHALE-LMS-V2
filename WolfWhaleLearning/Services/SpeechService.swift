import Speech
import AVFoundation
import Observation
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Speech Language

nonisolated enum SpeechLanguage: String, CaseIterable, Sendable, Identifiable {
    case english = "en-US"
    case spanish = "es-ES"
    case french = "fr-FR"
    case mandarin = "zh-CN"
    case japanese = "ja-JP"
    case german = "de-DE"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .english: "English"
        case .spanish: "Spanish"
        case .french: "French"
        case .mandarin: "Mandarin"
        case .japanese: "Japanese"
        case .german: "German"
        }
    }

    var flagEmoji: String {
        switch self {
        case .english: "\u{1F1FA}\u{1F1F8}"
        case .spanish: "\u{1F1EA}\u{1F1F8}"
        case .french: "\u{1F1EB}\u{1F1F7}"
        case .mandarin: "\u{1F1E8}\u{1F1F3}"
        case .japanese: "\u{1F1EF}\u{1F1F5}"
        case .german: "\u{1F1E9}\u{1F1EA}"
        }
    }

    var locale: Locale {
        Locale(identifier: rawValue)
    }
}

// MARK: - Recognized Word

nonisolated struct RecognizedWord: Identifiable, Hashable, Sendable {
    let id: UUID
    let text: String
    let confidence: Float
    let timestamp: TimeInterval

    init(text: String, confidence: Float, timestamp: TimeInterval) {
        self.id = UUID()
        self.text = text
        self.confidence = confidence
        self.timestamp = timestamp
    }
}

// MARK: - Speech Service

@MainActor
@Observable
final class SpeechService {

    // MARK: - Public State

    var isAuthorized = false
    var isRecording = false
    var transcribedText = ""
    var confidenceLevel: Float = 0
    var audioLevel: Float = 0
    var error: String?
    var isLoading = false
    var selectedLanguage: SpeechLanguage = .english
    var recognizedWords: [RecognizedWord] = []

    // MARK: - Private Properties

    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    private var audioLevelTimer: Timer?

    // MARK: - Initialization

    init() {
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: selectedLanguage.rawValue))
        checkAuthorizationStatus()
    }

    // MARK: - Authorization

    func requestAuthorization() async {
        isLoading = true
        error = nil

        let speechStatus = await withCheckedContinuation { (continuation: CheckedContinuation<SFSpeechRecognizerAuthorizationStatus, Never>) in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }

        switch speechStatus {
        case .authorized:
            break
        case .denied:
            error = "Speech recognition permission was denied. Please enable it in Settings."
            isAuthorized = false
            isLoading = false
            return
        case .restricted:
            error = "Speech recognition is restricted on this device."
            isAuthorized = false
            isLoading = false
            return
        case .notDetermined:
            error = "Speech recognition authorization not yet determined."
            isAuthorized = false
            isLoading = false
            return
        @unknown default:
            error = "Unknown speech recognition authorization status."
            isAuthorized = false
            isLoading = false
            return
        }

        // Request microphone permission
        let micGranted: Bool
        #if os(iOS)
        if #available(iOS 17.0, *) {
            micGranted = await AVAudioApplication.requestRecordPermission()
        } else {
            micGranted = await withCheckedContinuation { continuation in
                AVAudioSession.sharedInstance().requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }
        }
        #else
        micGranted = true
        #endif

        guard micGranted else {
            error = "Microphone access was denied. Please enable it in Settings."
            isAuthorized = false
            isLoading = false
            return
        }

        isAuthorized = true
        isLoading = false
    }

    func checkAuthorizationStatus() {
        let speechStatus = SFSpeechRecognizer.authorizationStatus()
        isAuthorized = speechStatus == .authorized
    }

    // MARK: - Language Selection

    func changeLanguage(_ language: SpeechLanguage) {
        guard language != selectedLanguage else { return }

        if isRecording {
            stopRecording()
        }

        selectedLanguage = language
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: language.rawValue))

        // Reset state for new language
        transcribedText = ""
        recognizedWords = []
        confidenceLevel = 0
        error = nil
    }

    // MARK: - Recording Controls

    func startRecording() {
        guard isAuthorized else {
            error = "Speech recognition is not authorized."
            return
        }

        guard let speechRecognizer, speechRecognizer.isAvailable else {
            error = "Speech recognizer is not available for \(selectedLanguage.displayName)."
            return
        }

        // Cancel any existing task
        if recognitionTask != nil {
            recognitionTask?.cancel()
            recognitionTask = nil
        }

        // Reset state
        transcribedText = ""
        recognizedWords = []
        confidenceLevel = 0
        audioLevel = 0
        error = nil

        // Configure audio session
        #if os(iOS)
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            self.error = "Failed to configure audio session: \(error.localizedDescription)"
            return
        }
        #endif

        // Create recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest else {
            self.error = "Failed to create recognition request."
            return
        }

        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.addsPunctuation = true

        if #available(iOS 16.0, *) {
            if speechRecognizer.supportsOnDeviceRecognition {
                recognitionRequest.requiresOnDeviceRecognition = false
            }
        }

        // Start recognition task
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            Task { @MainActor [weak self] in
                guard let self else { return }

                if let result {
                    self.processRecognitionResult(result)
                }

                if let error {
                    // Ignore cancellation errors during normal stop
                    let nsError = error as NSError
                    if nsError.domain == "kAFAssistantErrorDomain" && nsError.code == 216 {
                        // Recognition was cancelled — not an error
                    } else if nsError.domain == "kAFAssistantErrorDomain" && nsError.code == 209 {
                        // No speech detected — informational
                        if self.transcribedText.isEmpty {
                            self.error = "No speech detected. Please try again."
                        }
                    } else {
                        self.error = "Recognition error: \(error.localizedDescription)"
                    }
                }

                if result?.isFinal == true || error != nil {
                    self.finishRecording()
                }
            }
        }

        // Configure audio input
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)

            // Calculate audio level from buffer
            let level = self?.calculateAudioLevel(buffer: buffer) ?? 0
            Task { @MainActor [weak self] in
                self?.audioLevel = level
            }
        }

        // Start audio engine
        do {
            audioEngine.prepare()
            try audioEngine.start()
            isRecording = true
        } catch {
            self.error = "Failed to start audio engine: \(error.localizedDescription)"
            finishRecording()
        }

        // Start audio level metering timer for smooth updates
        startAudioLevelMetering()
    }

    func stopRecording() {
        guard isRecording else { return }
        finishRecording()
    }

    func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }

    // MARK: - Pronunciation Scoring

    /// Compares spoken text to expected text and returns a normalized score from 0.0 to 1.0.
    /// Uses word-level Levenshtein distance for accurate comparison.
    func calculatePronunciationScore(expected: String, spoken: String) -> Double {
        let expectedWords = normalizeText(expected)
        let spokenWords = normalizeText(spoken)

        guard !expectedWords.isEmpty else { return 0 }
        guard !spokenWords.isEmpty else { return 0 }

        // Calculate word-level edit distance
        let distance = levenshteinDistance(expectedWords, spokenWords)
        let maxLength = max(expectedWords.count, spokenWords.count)

        guard maxLength > 0 else { return 1.0 }

        let similarity = 1.0 - (Double(distance) / Double(maxLength))
        return max(0, min(similarity, 1.0))
    }

    // MARK: - Private Helpers

    private func processRecognitionResult(_ result: SFSpeechRecognitionResult) {
        transcribedText = result.bestTranscription.formattedString

        // Process individual segments for word-by-word data
        var words: [RecognizedWord] = []
        var totalConfidence: Float = 0

        for segment in result.bestTranscription.segments {
            let word = RecognizedWord(
                text: segment.substring,
                confidence: segment.confidence,
                timestamp: segment.timestamp
            )
            words.append(word)
            totalConfidence += segment.confidence
        }

        recognizedWords = words

        if !words.isEmpty {
            confidenceLevel = totalConfidence / Float(words.count)
        } else {
            confidenceLevel = 0
        }
    }

    private func finishRecording() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        isRecording = false
        stopAudioLevelMetering()

        // Deactivate audio session
        #if os(iOS)
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            // Non-critical — log but do not surface to user
        }
        #endif
    }

    private nonisolated func calculateAudioLevel(buffer: AVAudioPCMBuffer) -> Float {
        guard let channelData = buffer.floatChannelData else { return 0 }

        let channelDataValue = channelData.pointee
        let channelDataCount = Int(buffer.frameLength)

        guard channelDataCount > 0 else { return 0 }

        var sum: Float = 0
        for i in 0..<channelDataCount {
            let sample = channelDataValue[i]
            sum += sample * sample
        }

        let rms = sqrtf(sum / Float(channelDataCount))

        // Convert to a 0-1 range with logarithmic scaling for better visual feedback
        let minDb: Float = -60
        let db = 20 * log10f(max(rms, 1e-6))
        let normalizedDb = max(0, (db - minDb) / (-minDb))

        return min(normalizedDb, 1.0)
    }

    private func startAudioLevelMetering() {
        audioLevelTimer?.invalidate()
        audioLevelTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.isRecording else { return }
                // Smooth the audio level transitions
                let target = self.audioLevel
                let smoothed = self.audioLevel * 0.7 + target * 0.3
                self.audioLevel = smoothed
            }
        }
    }

    private func stopAudioLevelMetering() {
        audioLevelTimer?.invalidate()
        audioLevelTimer = nil
        audioLevel = 0
    }

    private func normalizeText(_ text: String) -> [String] {
        text.lowercased()
            .components(separatedBy: .punctuationCharacters)
            .joined()
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
    }

    /// Standard Levenshtein distance at the word level.
    private func levenshteinDistance(_ source: [String], _ target: [String]) -> Int {
        let sourceCount = source.count
        let targetCount = target.count

        if sourceCount == 0 { return targetCount }
        if targetCount == 0 { return sourceCount }

        var matrix = Array(repeating: Array(repeating: 0, count: targetCount + 1), count: sourceCount + 1)

        for i in 0...sourceCount { matrix[i][0] = i }
        for j in 0...targetCount { matrix[0][j] = j }

        for i in 1...sourceCount {
            for j in 1...targetCount {
                let cost = source[i - 1] == target[j - 1] ? 0 : 1
                matrix[i][j] = min(
                    matrix[i - 1][j] + 1,       // deletion
                    matrix[i][j - 1] + 1,       // insertion
                    matrix[i - 1][j - 1] + cost  // substitution
                )
            }
        }

        return matrix[sourceCount][targetCount]
    }
}
