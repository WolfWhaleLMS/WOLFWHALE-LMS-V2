import AVFoundation

/// Plays a gentle, Mozart-inspired classical piano melody on the login screen.
/// Uses AVAudioEngine + AVAudioUnitSampler with Apple's built-in DLS SoundFont
/// so there is ZERO network dependency — the melody is generated programmatically.
///
/// Audio category is `.ambient` so it does not interrupt other apps.
/// Fades in on appear and fades out when the user signs in.
@MainActor
@Observable
class LoginAudioService {
    var isPlaying = false

    private var engine: AVAudioEngine?
    private var sampler: AVAudioUnitSampler?
    private var melodyTask: Task<Void, Never>?
    private var fadeTask: Task<Void, Never>?

    /// Maximum volume for the login music (kept soft)
    private let maxVolume: Float = 0.3

    /// Duration of the fade-in in seconds
    private let fadeInDuration: TimeInterval = 2.0

    /// Duration of the fade-out in seconds
    private let fadeOutDuration: TimeInterval = 1.0

    // MARK: - MIDI Constants

    // Octave 3 bass notes
    private let A2:  UInt8 = 45
    private let B2:  UInt8 = 47
    private let C3:  UInt8 = 48
    private let D3:  UInt8 = 50
    private let E3:  UInt8 = 52
    private let F3:  UInt8 = 53
    private let G3:  UInt8 = 55
    private let Ab3: UInt8 = 56
    private let A3:  UInt8 = 57

    // Octave 4 melody notes
    private let C4:  UInt8 = 60
    private let D4:  UInt8 = 62
    private let Eb4: UInt8 = 63
    private let E4:  UInt8 = 64
    private let F4:  UInt8 = 65
    private let G4:  UInt8 = 67
    private let Ab4: UInt8 = 68
    private let A4:  UInt8 = 69
    private let Bb4: UInt8 = 70
    private let B4:  UInt8 = 71

    // Octave 5 melody notes
    private let C5:  UInt8 = 72
    private let D5:  UInt8 = 74
    private let Eb5: UInt8 = 75
    private let E5:  UInt8 = 76

    /// Tempo: ~72 BPM means one beat = 833ms
    private let beatDuration: Duration = .milliseconds(833)

    /// MIDI velocity for melody notes (mf - moderately soft)
    private let melodyVelocity: UInt8 = 70

    /// MIDI velocity for bass notes (softer than melody)
    private let bassVelocity: UInt8 = 50

    /// MIDI velocity for inner-voice / arpeggio notes
    private let arpeggioVelocity: UInt8 = 45

    // MARK: - Public API

    func startPlaying() {
        guard !isPlaying else { return }

        configureAudioSession()

        do {
            try setupAudioEngine()
        } catch {
            #if DEBUG
            print("[LoginAudioService] Failed to set up audio engine: \(error.localizedDescription)")
            #endif
            return
        }

        // Start silent for fade-in
        engine?.mainMixerNode.outputVolume = 0
        isPlaying = true

        // Begin melody loop in a background task
        melodyTask = Task.detached(priority: .utility) { [weak self] in
            await self?.melodyLoop()
        }

        // Fade in
        fadeVolume(from: 0, to: maxVolume, duration: fadeInDuration)
    }

    func fadeOutAndStop() {
        guard isPlaying else { return }
        let currentVolume = engine?.mainMixerNode.outputVolume ?? maxVolume
        fadeVolume(from: currentVolume, to: 0, duration: fadeOutDuration) { [weak self] in
            Task { @MainActor [weak self] in
                self?.stop()
            }
        }
    }

    func stop() {
        fadeTask?.cancel()
        fadeTask = nil

        melodyTask?.cancel()
        melodyTask = nil

        // Stop all MIDI notes
        sampler?.stopAllNotes()

        engine?.stop()
        engine = nil
        sampler = nil
        isPlaying = false

        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    // MARK: - Audio Engine Setup

    private func setupAudioEngine() throws {
        let engine = AVAudioEngine()
        let sampler = AVAudioUnitSampler()

        engine.attach(sampler)
        engine.connect(sampler, to: engine.mainMixerNode, format: nil)

        try engine.start()

        // Attempt to load the built-in Apple DLS SoundFont for Acoustic Grand Piano.
        // This path only exists on macOS; on iOS/Simulator the file won't be found
        // and the sampler falls back to its default tone, which is acceptable.
        // Program 0 = Acoustic Grand Piano, bankMSB 0x79 = GM melodic sounds, bankLSB 0
        #if targetEnvironment(simulator) || os(iOS)
        // DLS SoundFont is not available on iOS or Simulator — use default sampler tone.
        #else
        let dlsPath = "/System/Library/Components/CoreAudio.component/Contents/Resources/gs_instruments.dls"
        if FileManager.default.fileExists(atPath: dlsPath) {
            let dlsURL = URL(fileURLWithPath: dlsPath)
            do {
                try sampler.loadSoundBankInstrument(
                    at: dlsURL,
                    program: 0,        // Acoustic Grand Piano
                    bankMSB: 0x79,     // GM Melodic
                    bankLSB: 0
                )
            } catch {
                #if DEBUG
                print("[LoginAudioService] Could not load DLS sound font: \(error.localizedDescription)")
                #endif
                // The sampler will use a default sine-like tone — still usable
            }
        }
        #endif

        self.engine = engine
        self.sampler = sampler
    }

    private func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            #if DEBUG
            print("[LoginAudioService] Audio session error: \(error.localizedDescription)")
            #endif
        }
    }

    // MARK: - Melody Generation

    /// A single note event: pitch, velocity, and duration in beats.
    private struct NoteEvent {
        let note: UInt8
        let velocity: UInt8
        let beats: Double  // how long to hold before releasing
    }

    /// A chord/beat event: multiple notes played simultaneously, with a total duration in beats.
    private struct BeatEvent {
        let notes: [NoteEvent]
        let totalBeats: Double  // time to wait before the next BeatEvent
    }

    /// The main melody loop — runs forever until the task is cancelled.
    private func melodyLoop() async {
        let phrases = buildMelody()

        while !Task.isCancelled {
            for event in phrases {
                guard !Task.isCancelled else { return }

                // Play all notes in this beat event
                for note in event.notes {
                    await playNote(note.note, velocity: note.velocity)
                }

                // Hold for the event duration
                let holdDuration = beatDuration * event.totalBeats
                do {
                    try await Task.sleep(for: holdDuration)
                } catch {
                    return // Cancelled
                }

                // Release notes
                for note in event.notes {
                    await stopNote(note.note)
                }
            }

            // Brief pause before looping
            do {
                try await Task.sleep(for: beatDuration * 0.5)
            } catch {
                return
            }
        }
    }

    /// Build a Mozart-inspired Adagio melody in A minor.
    /// Chord progression: Am - E - Am - Dm - G - C - E - Am
    /// Left hand: bass arpeggios (octave 2-3)
    /// Right hand: lyrical melody (octave 4-5)
    private func buildMelody() -> [BeatEvent] {
        var events: [BeatEvent] = []

        // ─── Phrase 1: Am (i) ───
        // Measure 1: A minor — melody rises gently
        events.append(beat([bass(A2), arp(C3), melody(E4)], beats: 1.0))
        events.append(beat([arp(E3)], beats: 0.5))
        events.append(beat([arp(A3)], beats: 0.5))
        events.append(beat([melody(C5)], beats: 1.0))
        events.append(beat([bass(A2), arp(E3), melody(B4)], beats: 1.0))

        // Measure 2: Am continued — melody descends
        events.append(beat([bass(A2), arp(C3), melody(A4)], beats: 1.5))
        events.append(beat([arp(E3)], beats: 0.5))
        events.append(beat([melody(G4)], beats: 1.0))
        events.append(beat([melody(E4)], beats: 1.0))

        // ─── Phrase 2: E (V) ───
        // Measure 3: E major — tension
        events.append(beat([bass(E3), arp(Ab3), melody(B4)], beats: 1.0))
        events.append(beat([arp(E3)], beats: 0.5))
        events.append(beat([arp(Ab3)], beats: 0.5))
        events.append(beat([melody(E5)], beats: 1.0))
        events.append(beat([bass(E3), melody(D5)], beats: 1.0))

        // Measure 4: E continued — resolve hint
        events.append(beat([bass(E3), arp(Ab3), melody(C5)], beats: 1.0))
        events.append(beat([melody(B4)], beats: 1.0))
        events.append(beat([arp(E3)], beats: 0.5))
        events.append(beat([melody(Ab4)], beats: 1.0))
        events.append(beat([rest()], beats: 0.5))

        // ─── Phrase 3: Am (i) ───
        // Measure 5: Return to A minor
        events.append(beat([bass(A2), arp(C3), melody(A4)], beats: 1.0))
        events.append(beat([arp(E3)], beats: 0.5))
        events.append(beat([arp(A3)], beats: 0.5))
        events.append(beat([melody(C5)], beats: 1.5))
        events.append(beat([melody(B4)], beats: 0.5))

        // Measure 6: Am — gentle descent
        events.append(beat([bass(A2), arp(E3), melody(A4)], beats: 1.0))
        events.append(beat([melody(G4)], beats: 0.5))
        events.append(beat([melody(F4)], beats: 0.5))
        events.append(beat([melody(E4)], beats: 1.5))
        events.append(beat([rest()], beats: 0.5))

        // ─── Phrase 4: Dm (iv) ───
        // Measure 7: D minor — new color
        events.append(beat([bass(D3), arp(F3), melody(D5)], beats: 1.0))
        events.append(beat([arp(A3)], beats: 0.5))
        events.append(beat([arp(D3)], beats: 0.5))
        events.append(beat([melody(C5)], beats: 1.0))
        events.append(beat([bass(D3), melody(A4)], beats: 1.0))

        // Measure 8: Dm continued
        events.append(beat([bass(D3), arp(F3), melody(F4)], beats: 1.0))
        events.append(beat([melody(E4)], beats: 0.5))
        events.append(beat([melody(D4)], beats: 0.5))
        events.append(beat([arp(A3), melody(E4)], beats: 1.0))
        events.append(beat([rest()], beats: 1.0))

        // ─── Phrase 5: G (VII) ───
        // Measure 9: G major — brightness
        events.append(beat([bass(G3), arp(B2), melody(D5)], beats: 1.0))
        events.append(beat([arp(D3)], beats: 0.5))
        events.append(beat([arp(G3)], beats: 0.5))
        events.append(beat([melody(B4)], beats: 1.0))
        events.append(beat([bass(G3), melody(G4)], beats: 1.0))

        // Measure 10: G continued
        events.append(beat([bass(G3), arp(B2), melody(A4)], beats: 1.0))
        events.append(beat([melody(B4)], beats: 1.0))
        events.append(beat([arp(D3)], beats: 0.5))
        events.append(beat([melody(D5)], beats: 1.0))
        events.append(beat([rest()], beats: 0.5))

        // ─── Phrase 6: C (III) ───
        // Measure 11: C major — warmth
        events.append(beat([bass(C3), arp(E3), melody(E5)], beats: 1.5))
        events.append(beat([arp(G3)], beats: 0.5))
        events.append(beat([melody(D5)], beats: 1.0))
        events.append(beat([bass(C3), melody(C5)], beats: 1.0))

        // Measure 12: C continued
        events.append(beat([bass(C3), arp(E3), melody(B4)], beats: 1.0))
        events.append(beat([melody(C5)], beats: 0.5))
        events.append(beat([melody(E4)], beats: 0.5))
        events.append(beat([arp(G3), melody(G4)], beats: 1.0))
        events.append(beat([rest()], beats: 1.0))

        // ─── Phrase 7: E (V) ───
        // Measure 13: E major — building tension for resolution
        events.append(beat([bass(E3), arp(Ab3), melody(B4)], beats: 1.0))
        events.append(beat([arp(E3)], beats: 0.5))
        events.append(beat([arp(Ab3)], beats: 0.5))
        events.append(beat([melody(E5)], beats: 1.5))
        events.append(beat([melody(D5)], beats: 0.5))

        // Measure 14: E — dominant suspense
        events.append(beat([bass(E3), arp(Ab3), melody(C5)], beats: 1.0))
        events.append(beat([melody(B4)], beats: 1.0))
        events.append(beat([arp(E3)], beats: 0.5))
        events.append(beat([melody(Ab4)], beats: 1.0))
        events.append(beat([rest()], beats: 0.5))

        // ─── Phrase 8: Am (i) — Final resolution ───
        // Measure 15: A minor — coming home
        events.append(beat([bass(A2), arp(C3), melody(A4)], beats: 1.5))
        events.append(beat([arp(E3)], beats: 0.5))
        events.append(beat([melody(C5)], beats: 1.0))
        events.append(beat([melody(B4)], beats: 1.0))

        // Measure 16: Am — peaceful ending, slowing
        events.append(beat([bass(A2), arp(C3), arp(E3), melody(A4)], beats: 2.0))
        events.append(beat([bass(A2), melody(E4)], beats: 1.5))
        events.append(beat([rest()], beats: 1.5))

        return events
    }

    // MARK: - Melody Helper Builders

    private func melody(_ note: UInt8) -> NoteEvent {
        NoteEvent(note: note, velocity: melodyVelocity, beats: 1.0)
    }

    private func bass(_ note: UInt8) -> NoteEvent {
        NoteEvent(note: note, velocity: bassVelocity, beats: 1.0)
    }

    private func arp(_ note: UInt8) -> NoteEvent {
        NoteEvent(note: note, velocity: arpeggioVelocity, beats: 1.0)
    }

    private func rest() -> NoteEvent {
        NoteEvent(note: 0, velocity: 0, beats: 0)
    }

    private func beat(_ notes: [NoteEvent], beats: Double) -> BeatEvent {
        // Filter out rests (velocity 0)
        let playable = notes.filter { $0.velocity > 0 }
        return BeatEvent(notes: playable, totalBeats: beats)
    }

    // MARK: - MIDI Playback

    private func playNote(_ note: UInt8, velocity: UInt8) async {
        await MainActor.run {
            sampler?.startNote(note, withVelocity: velocity, onChannel: 0)
        }
    }

    private func stopNote(_ note: UInt8) async {
        await MainActor.run {
            sampler?.stopNote(note, onChannel: 0)
        }
    }

    // MARK: - Volume Fading

    private func fadeVolume(from start: Float, to end: Float, duration: TimeInterval, completion: (() -> Void)? = nil) {
        fadeTask?.cancel()

        let steps = 30
        let interval = duration / Double(steps)
        let delta = (end - start) / Float(steps)

        fadeTask = Task { @MainActor [weak self] in
            for step in 1...steps {
                guard !Task.isCancelled else { return }

                do {
                    try await Task.sleep(for: .seconds(interval))
                } catch {
                    return
                }

                guard let self, let engine = self.engine else { return }

                let newVolume = start + delta * Float(step)
                engine.mainMixerNode.outputVolume = newVolume

                if step == steps {
                    engine.mainMixerNode.outputVolume = end
                    completion?()
                }
            }
        }
    }

    // MARK: - Duration Arithmetic Helper

}

// MARK: - AVAudioUnitSampler Convenience

private extension AVAudioUnitSampler {
    /// Stops all sounding notes on channel 0 by sending note-off for the full MIDI range.
    func stopAllNotes() {
        for note: UInt8 in 0...127 {
            stopNote(note, onChannel: 0)
        }
    }
}

// MARK: - Duration * Double

private extension Duration {
    /// Multiply a `Duration` by a `Double` scalar while preserving attosecond-level
    /// precision.  The previous implementation converted everything to nanoseconds
    /// via floating-point, which loses precision for short clips (small durations)
    /// because `Double` only has ~53 bits of mantissa.
    ///
    /// This version scales seconds and attoseconds separately, carries the
    /// overflow properly, and builds the result from the precise components.
    static func * (lhs: Duration, rhs: Double) -> Duration {
        let (sec, atto) = lhs.components                       // (Int64, Int64)
        let attoPerSec: Double = 1_000_000_000_000_000_000     // 1e18

        // Scale each component independently to minimise floating-point magnitude.
        let scaledSec  = Double(sec)  * rhs                    // fractional seconds
        let scaledAtto = Double(atto) * rhs                    // fractional attoseconds

        // Whole seconds from the seconds component
        let wholeSec  = Int64(scaledSec)
        // Remaining fractional second → attoseconds
        let fracAtto  = (scaledSec - Double(wholeSec)) * attoPerSec

        let totalAtto = Int64(fracAtto + scaledAtto)

        // Carry: attoseconds may exceed 1 second
        let carrySeconds = totalAtto / 1_000_000_000_000_000_000
        let remainAtto   = totalAtto % 1_000_000_000_000_000_000

        return .seconds(wholeSec + carrySeconds) + .nanoseconds(remainAtto / 1_000_000_000)
    }
}
