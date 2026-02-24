import AVFoundation
import SwiftUI

// MARK: - Sound Types

enum RetroSound {
    /// Short blip — menu select / general tap
    case tap
    /// Two-tone ascending — confirm action
    case confirm
    /// Classic coin collect jingle
    case coin
    /// Triumphant ascending arpeggio — task complete
    case success
    /// Descending buzz — error / denied
    case error
    /// Quick descending — navigate back
    case back
    /// Power-up sweep
    case powerUp
}

// MARK: - Service

/// Generates and plays retro 8-bit square-wave sound effects.
///
/// Uses `AVAudioSession.Category.ambient` so sounds automatically
/// respect the iPhone silent-mode switch — no extra logic needed.
final class RetroSoundService: @unchecked Sendable {
    static let shared = RetroSoundService()

    private let engine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private let sampleRate: Double = 44_100
    private let queue = DispatchQueue(label: "com.wolfwhale.retrosound", qos: .userInteractive)

    private init() {
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        engine.attach(playerNode)
        engine.connect(playerNode, to: engine.mainMixerNode, format: format)

        do {
            // .ambient respects the hardware silent switch
            #if os(iOS)
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            #endif
            try engine.start()
        } catch {
            #if DEBUG
            print("[RetroSoundService] Setup failed: \(error)")
            #endif
        }
    }

    // MARK: - Public API

    func play(_ sound: RetroSound) {
        queue.async { [self] in
            let tones: [(hz: Double, duration: Double)]
            let volume: Float

            switch sound {
            case .tap:
                tones = [(880, 0.045)]
                volume = 0.20
            case .confirm:
                tones = [(660, 0.06), (880, 0.08)]
                volume = 0.22
            case .coin:
                tones = [(988, 0.07), (1319, 0.12)]
                volume = 0.22
            case .success:
                tones = [(523, 0.08), (659, 0.08), (784, 0.08), (1047, 0.14)]
                volume = 0.22
            case .error:
                tones = [(440, 0.12), (330, 0.18)]
                volume = 0.18
            case .back:
                tones = [(660, 0.05), (440, 0.06)]
                volume = 0.18
            case .powerUp:
                tones = [(440, 0.06), (554, 0.06), (659, 0.06), (880, 0.10)]
                volume = 0.20
            }

            guard let buffer = makeBuffer(tones: tones, volume: volume) else { return }

            if !engine.isRunning {
                try? engine.start()
            }

            // .interrupts ensures rapid taps don't queue up
            playerNode.scheduleBuffer(buffer, at: nil, options: .interrupts)
            playerNode.play()
        }
    }

    // MARK: - Square Wave Generator

    /// Builds a PCM buffer containing concatenated square-wave tones
    /// with a short fade-out on each note to prevent audible clicks.
    private func makeBuffer(tones: [(hz: Double, duration: Double)], volume: Float) -> AVAudioPCMBuffer? {
        let totalDuration = tones.reduce(0.0) { $0 + $1.duration }
        let totalFrames = AVAudioFrameCount(sampleRate * totalDuration)
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: totalFrames) else { return nil }
        buffer.frameLength = totalFrames

        guard let samples = buffer.floatChannelData?[0] else { return nil }

        var offset = 0
        for tone in tones {
            let frames = Int(sampleRate * tone.duration)
            let samplesPerCycle = sampleRate / tone.hz
            let fadeStart = Int(Double(frames) * 0.80)

            for i in 0..<frames {
                let pos = Double(i).truncatingRemainder(dividingBy: samplesPerCycle)
                // Square wave: +volume for first half of cycle, -volume for second half
                var value: Float = pos < samplesPerCycle / 2 ? volume : -volume

                // Fade out the last 20% of each note to avoid pops
                if i > fadeStart {
                    let fade = Float(i - fadeStart) / Float(frames - fadeStart)
                    value *= (1.0 - fade)
                }

                samples[offset + i] = value
            }
            offset += frames
        }

        return buffer
    }
}

// MARK: - SwiftUI View Modifier

/// Plays a retro sound effect whenever `trigger` changes — mirrors the
/// `.hapticFeedback(_:trigger:)` API so both can sit side-by-side.
///
///     Button("Save") { save() }
///         .retroSound(.confirm, trigger: saveCount)
///         .hapticFeedback(.impact(weight: .medium), trigger: saveCount)
struct RetroSoundModifier<V: Equatable>: ViewModifier {
    let sound: RetroSound
    let trigger: V

    func body(content: Content) -> some View {
        content.onChange(of: trigger) {
            RetroSoundService.shared.play(sound)
        }
    }
}

extension View {
    /// Play a retro 8-bit sound effect each time `trigger` changes.
    /// Respects iPhone silent mode automatically.
    func retroSound(_ sound: RetroSound, trigger: some Equatable) -> some View {
        modifier(RetroSoundModifier(sound: sound, trigger: trigger))
    }
}
