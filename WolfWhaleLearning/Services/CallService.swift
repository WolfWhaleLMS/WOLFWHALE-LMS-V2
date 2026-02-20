import CallKit
import AVFoundation

@MainActor
@Observable
class CallService: NSObject {
    var isInCall = false
    var isMuted = false
    var isSpeakerOn = false
    var callDuration: TimeInterval = 0
    var callerName: String = ""
    var callUUID: UUID?
    var isRinging = false

    private var provider: CXProvider
    private let callController = CXCallController()
    private var callTimer: Timer?
    private var audioEngine: AVAudioEngine?

    // Nonisolated stored properties for the delegate bridge
    private nonisolated(unsafe) var _pendingAnswerAction: CXAnswerCallAction?
    private nonisolated(unsafe) var _pendingEndAction: CXEndCallAction?

    override init() {
        let configuration = CXProviderConfiguration()
        configuration.localizedName = "WolfWhale Study Calls"
        configuration.supportsVideo = false
        configuration.maximumCallsPerGroup = 1
        configuration.maximumCallGroups = 1
        configuration.supportedHandleTypes = [.generic]
        configuration.iconTemplateImageData = nil
        provider = CXProvider(configuration: configuration)

        super.init()

        provider.setDelegate(self, queue: nil)
    }

    deinit {
        callTimer?.invalidate()
        provider.invalidate()
    }

    // MARK: - Outgoing Call

    func startCall(to peerID: String, displayName: String) {
        let uuid = UUID()
        callUUID = uuid
        callerName = displayName
        callDuration = 0

        let handle = CXHandle(type: .generic, value: peerID)
        let startCallAction = CXStartCallAction(call: uuid, handle: handle)
        startCallAction.contactIdentifier = displayName
        startCallAction.isVideo = false

        let transaction = CXTransaction(action: startCallAction)
        callController.request(transaction) { [weak self] error in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let error {
                    print("CallService: start call failed — \(error.localizedDescription)")
                    self.resetCallState()
                } else {
                    // Update the provider with caller info so the system UI shows the name
                    self.provider.reportCall(with: uuid, updated: CXCallUpdate().apply {
                        $0.remoteHandle = handle
                        $0.localizedCallerName = displayName
                        $0.hasVideo = false
                        $0.supportsHolding = false
                        $0.supportsGrouping = false
                        $0.supportsUngrouping = false
                        $0.supportsDTMF = false
                    })
                }
            }
        }
    }

    // MARK: - Incoming Call

    func reportIncomingCall(from peerID: String, displayName: String) {
        let uuid = UUID()
        callUUID = uuid
        callerName = displayName
        isRinging = true

        let update = CXCallUpdate()
        update.remoteHandle = CXHandle(type: .generic, value: peerID)
        update.localizedCallerName = displayName
        update.hasVideo = false
        update.supportsHolding = false
        update.supportsGrouping = false
        update.supportsUngrouping = false
        update.supportsDTMF = false

        provider.reportNewIncomingCall(with: uuid, update: update) { [weak self] error in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let error {
                    print("CallService: incoming call report failed — \(error.localizedDescription)")
                    self.resetCallState()
                }
            }
        }
    }

    // MARK: - End Call

    func endCall() {
        guard let uuid = callUUID else { return }

        let endCallAction = CXEndCallAction(call: uuid)
        let transaction = CXTransaction(action: endCallAction)
        callController.request(transaction) { [weak self] error in
            Task { @MainActor [weak self] in
                if let error {
                    print("CallService: end call failed — \(error.localizedDescription)")
                    // Force cleanup even if the transaction fails
                    self?.cleanupCall()
                }
            }
        }
    }

    // MARK: - Mute / Speaker

    func toggleMute() {
        guard let uuid = callUUID else { return }
        isMuted.toggle()

        let muteAction = CXSetMutedCallAction(call: uuid, muted: isMuted)
        let transaction = CXTransaction(action: muteAction)
        callController.request(transaction) { error in
            if let error {
                print("CallService: mute toggle failed — \(error.localizedDescription)")
            }
        }

        // Also mute the audio engine input
        audioEngine?.inputNode.volume = isMuted ? 0.0 : 1.0
    }

    func toggleSpeaker() {
        isSpeakerOn.toggle()
        configureSpeakerOutput()
    }

    // MARK: - Audio Session

    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .voiceChat, options: [.allowBluetooth, .defaultToSpeaker])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
            configureSpeakerOutput()
        } catch {
            print("CallService: audio session configuration failed — \(error.localizedDescription)")
        }
    }

    private func configureSpeakerOutput() {
        do {
            let session = AVAudioSession.sharedInstance()
            if isSpeakerOn {
                try session.overrideOutputAudioPort(.speaker)
            } else {
                try session.overrideOutputAudioPort(.none)
            }
        } catch {
            print("CallService: speaker toggle failed — \(error.localizedDescription)")
        }
    }

    private func deactivateAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            print("CallService: audio session deactivation failed — \(error.localizedDescription)")
        }
    }

    // MARK: - Audio Engine

    /// Sets up AVAudioEngine for voice capture and playback.
    /// In production, captured audio buffers would be sent to the remote peer
    /// via WebRTC or MultipeerConnectivity, and received audio buffers would be
    /// scheduled on the playerNode. For now this configures the pipeline correctly.
    private func startAudioEngine() {
        let engine = AVAudioEngine()
        audioEngine = engine

        let inputNode = engine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)

        // Install a tap on the microphone input to capture audio buffers
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { buffer, time in
            // TODO: Send audio buffer to remote peer via WebRTC or MultipeerConnectivity
            // Example: peerService.sendAudioBuffer(buffer, at: time)
            _ = buffer
            _ = time
        }

        // Create a player node for receiving remote audio
        let playerNode = AVAudioPlayerNode()
        engine.attach(playerNode)
        engine.connect(playerNode, to: engine.mainMixerNode, format: inputFormat)

        // TODO: When receiving audio buffers from remote peer, schedule them:
        // playerNode.scheduleBuffer(receivedBuffer, completionHandler: nil)

        do {
            try engine.start()
            playerNode.play()
        } catch {
            print("CallService: audio engine start failed — \(error.localizedDescription)")
        }

        // Apply current mute state
        inputNode.volume = isMuted ? 0.0 : 1.0
    }

    private func stopAudioEngine() {
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
    }

    // MARK: - Call Timer

    private func startCallTimer() {
        callDuration = 0
        callTimer?.invalidate()
        callTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.callDuration += 1
            }
        }
    }

    private func stopCallTimer() {
        callTimer?.invalidate()
        callTimer = nil
    }

    // MARK: - Call Lifecycle

    private func beginCall() {
        isInCall = true
        isRinging = false
        isMuted = false
        isSpeakerOn = false
        callDuration = 0
        configureAudioSession()
        startAudioEngine()
        startCallTimer()
    }

    private func cleanupCall() {
        stopCallTimer()
        stopAudioEngine()
        deactivateAudioSession()
        resetCallState()
    }

    private func resetCallState() {
        isInCall = false
        isRinging = false
        isMuted = false
        isSpeakerOn = false
        callDuration = 0
        callerName = ""
        callUUID = nil
    }

    // MARK: - Formatting

    var formattedDuration: String {
        let minutes = Int(callDuration) / 60
        let seconds = Int(callDuration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// MARK: - CXCallUpdate Helper

private extension CXCallUpdate {
    @discardableResult
    func apply(_ block: (CXCallUpdate) -> Void) -> CXCallUpdate {
        block(self)
        return self
    }
}

// MARK: - CXProviderDelegate

extension CallService: CXProviderDelegate {

    nonisolated func providerDidReset(_ provider: CXProvider) {
        Task { @MainActor in
            cleanupCall()
        }
    }

    nonisolated func provider(_ provider: CXProvider, perform action: CXStartCallAction) {
        Task { @MainActor in
            configureAudioSession()
            provider.reportOutgoingCall(with: action.callUUID, startedConnectingAt: Date())
            // Simulate connection delay for the outgoing call
            try? await Task.sleep(for: .milliseconds(500))
            provider.reportOutgoingCall(with: action.callUUID, connectedAt: Date())
            beginCall()
            action.fulfill()
        }
    }

    nonisolated func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        Task { @MainActor in
            beginCall()
            action.fulfill()
        }
    }

    nonisolated func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        Task { @MainActor in
            cleanupCall()
            action.fulfill()
        }
    }

    nonisolated func provider(_ provider: CXProvider, perform action: CXSetMutedCallAction) {
        Task { @MainActor in
            isMuted = action.isMuted
            audioEngine?.inputNode.volume = isMuted ? 0.0 : 1.0
        }
        action.fulfill()
    }

    nonisolated func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) {
        Task { @MainActor in
            // Audio session has been activated by the system after CallKit takes over
            // Restart audio engine if needed
            if audioEngine == nil || !(audioEngine?.isRunning ?? false) {
                startAudioEngine()
            }
        }
    }

    nonisolated func provider(_ provider: CXProvider, didDeactivate audioSession: AVAudioSession) {
        Task { @MainActor in
            stopAudioEngine()
        }
    }
}
