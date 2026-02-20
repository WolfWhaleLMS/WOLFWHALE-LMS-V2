import Foundation
import CallKit
import AVFoundation
import SwiftUI

@preconcurrency import CallKit

@Observable
final class CallService: NSObject {

    var activeCallUUID: UUID?
    var isCallActive: Bool = false
    var callDuration: TimeInterval = 0
    var remoteParticipantName: String = ""

    private var callTimer: Timer?
    private var provider: CXProvider?
    private let callController = CXCallController()

    private var pendingAnswerAction: CXAnswerCallAction?
    private var pendingEndAction: CXEndCallAction?

    override init() {
        super.init()
        let config = CXProviderConfiguration()
        config.supportsVideo = false
        config.maximumCallGroups = 1
        config.supportedHandleTypes = [.generic, .phoneNumber]
        let provider = CXProvider(configuration: config)
        provider.setDelegate(self, queue: nil)
        self.provider = provider
    }

    func reportIncomingCall(uuid: UUID, handle: String, displayName: String) async throws {
        let callHandle = CXHandle(type: .generic, value: handle)
        let callUpdate = CXCallUpdate()
        callUpdate.remoteHandle = callHandle
        callUpdate.localizedCallerName = displayName
        callUpdate.hasVideo = false
        callUpdate.supportsGrouping = false
        callUpdate.supportsUngrouping = false
        callUpdate.supportsHolding = false

        try await provider?.reportNewIncomingCall(with: uuid, update: callUpdate)
        await MainActor.run {
            self.remoteParticipantName = displayName
        }
    }

    func startCall(to handle: String, displayName: String) {
        let uuid = UUID()
        let callHandle = CXHandle(type: .generic, value: handle)
        let startAction = CXStartCallAction(call: uuid, handle: callHandle)
        startAction.isVideo = false
        startAction.contactIdentifier = displayName
        let transaction = CXTransaction(action: startAction)
        callController.request(transaction) { [weak self] error in
<<<<<<< HEAD
            if error == nil {
                Task { @MainActor in
                    self?.activeCallUUID = uuid
                    self?.remoteParticipantName = displayName
=======
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let error {
                    #if DEBUG
                    print("CallService: start call failed — \(error.localizedDescription)")
                    #endif
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
>>>>>>> 8913cc2 (App Store audit fixes: privacy keys, entitlements, thread safety, production hardening)
                }
            }
        }
    }

<<<<<<< HEAD
    func endCall() {
        guard let uuid = activeCallUUID else { return }
        let endAction = CXEndCallAction(call: uuid)
        let transaction = CXTransaction(action: endAction)
        callController.request(transaction, completion: { _ in })
    }

=======
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
                    #if DEBUG
                    print("CallService: incoming call report failed — \(error.localizedDescription)")
                    #endif
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
                    #if DEBUG
                    print("CallService: end call failed — \(error.localizedDescription)")
                    #endif
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
                #if DEBUG
                print("CallService: mute toggle failed — \(error.localizedDescription)")
                #endif
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
            #if DEBUG
            print("CallService: audio session configuration failed — \(error.localizedDescription)")
            #endif
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
            #if DEBUG
            print("CallService: speaker toggle failed — \(error.localizedDescription)")
            #endif
        }
    }

    private func deactivateAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            #if DEBUG
            print("CallService: audio session deactivation failed — \(error.localizedDescription)")
            #endif
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
            audioEngine?.stop()
            audioEngine = nil
            #if DEBUG
            print("CallService: audio engine start failed — \(error.localizedDescription)")
            #endif
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

>>>>>>> 8913cc2 (App Store audit fixes: privacy keys, entitlements, thread safety, production hardening)
    private func startCallTimer() {
        callTimer?.invalidate()
        callDuration = 0
        callTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.callDuration += 1
            }
        }
    }

    private func stopCallTimer() {
        callTimer?.invalidate()
        callTimer = nil
        callDuration = 0
    }

    var formattedDuration: String {
        let minutes = Int(callDuration) / 60
        let seconds = Int(callDuration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

extension CallService: CXProviderDelegate {

    nonisolated func providerDidReset(_ provider: CXProvider) {
        Task { @MainActor in
            stopCallTimer()
            isCallActive = false
            activeCallUUID = nil
        }
    }

    nonisolated func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        configureAudioSession()
        action.fulfill()
        Task { @MainActor in
            isCallActive = true
            startCallTimer()
        }
    }

    nonisolated func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        action.fulfill()
        Task { @MainActor in
            stopCallTimer()
            isCallActive = false
            activeCallUUID = nil
        }
    }

    nonisolated func provider(_ provider: CXProvider, perform action: CXStartCallAction) {
        configureAudioSession()
        action.fulfill()
        Task { @MainActor in
            isCallActive = true
            activeCallUUID = action.callUUID
            startCallTimer()
        }
        let callUpdate = CXCallUpdate()
        callUpdate.remoteHandle = action.handle
        callUpdate.localizedCallerName = action.contactIdentifier
        provider.reportCall(with: action.callUUID, updated: callUpdate)
    }

    nonisolated func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) {
        // Audio session activated by CallKit
    }

    nonisolated func provider(_ provider: CXProvider, didDeactivate audioSession: AVAudioSession) {
        // Audio session deactivated by CallKit
    }

    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(
            .playAndRecord,
            mode: .voiceChat,
            options: [.allowBluetoothHFP, .duckOthers]
        )
        try? session.setActive(true)
    }
}
