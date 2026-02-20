import Foundation
import CallKit
import AVFoundation
import SwiftUI
import Observation

@preconcurrency import CallKit

@MainActor
@Observable
final class CallService: NSObject {

    var activeCallUUID: UUID?
    var isCallActive: Bool = false
    var callDuration: TimeInterval = 0
    var remoteParticipantName: String = ""
    var isMuted: Bool = false
    var isSpeakerOn: Bool = false

    private var callTimer: Timer?
    private var provider: CXProvider?
    private let callController = CXCallController()
    private var audioEngine: AVAudioEngine?

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

    // MARK: - Start Call

    func startCall(to handle: String, displayName: String) {
        let uuid = UUID()
        let callHandle = CXHandle(type: .generic, value: handle)
        let startAction = CXStartCallAction(call: uuid, handle: callHandle)
        startAction.isVideo = false
        startAction.contactIdentifier = displayName
        let transaction = CXTransaction(action: startAction)
        callController.request(transaction) { [weak self] error in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let error {
                    #if DEBUG
                    print("CallService: start call failed — \(error.localizedDescription)")
                    #endif
                } else {
                    self.activeCallUUID = uuid
                    self.remoteParticipantName = displayName
                }
            }
        }
    }

    // MARK: - Incoming Call

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
        self.remoteParticipantName = displayName
    }

    // MARK: - End Call

    func endCall() {
        guard let uuid = activeCallUUID else { return }
        let endAction = CXEndCallAction(call: uuid)
        let transaction = CXTransaction(action: endAction)
        callController.request(transaction) { [weak self] error in
            Task { @MainActor [weak self] in
                if let error {
                    #if DEBUG
                    print("CallService: end call failed — \(error.localizedDescription)")
                    #endif
                    self?.resetCallState()
                }
            }
        }
    }

    // MARK: - Mute / Speaker

    func toggleMute() {
        guard let uuid = activeCallUUID else { return }
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

        audioEngine?.inputNode.volume = isMuted ? 0.0 : 1.0
    }

    func toggleSpeaker() {
        isSpeakerOn.toggle()
        configureSpeakerOutput()
    }

    // MARK: - State Management

    private func resetCallState() {
        stopCallTimer()
        stopAudioEngine()
        deactivateAudioSession()
        isCallActive = false
        activeCallUUID = nil
        remoteParticipantName = ""
        isMuted = false
        isSpeakerOn = false
    }

    // MARK: - Audio Session

    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(
                .playAndRecord,
                mode: .voiceChat,
                options: [.allowBluetooth, .defaultToSpeaker]
            )
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

    private func startAudioEngine() {
        let engine = AVAudioEngine()
        audioEngine = engine

        let inputNode = engine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { buffer, time in
            _ = buffer
            _ = time
        }

        let playerNode = AVAudioPlayerNode()
        engine.attach(playerNode)
        engine.connect(playerNode, to: engine.mainMixerNode, format: inputFormat)

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

        inputNode.volume = isMuted ? 0.0 : 1.0
    }

    private func stopAudioEngine() {
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
    }

    // MARK: - Call Timer

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

// MARK: - CXProviderDelegate

extension CallService: CXProviderDelegate {

    nonisolated func providerDidReset(_ provider: CXProvider) {
        Task { @MainActor in
            resetCallState()
        }
    }

    nonisolated func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        action.fulfill()
        Task { @MainActor in
            configureAudioSession()
            startAudioEngine()
            isCallActive = true
            startCallTimer()
        }
    }

    nonisolated func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        action.fulfill()
        Task { @MainActor in
            resetCallState()
        }
    }

    nonisolated func provider(_ provider: CXProvider, perform action: CXStartCallAction) {
        action.fulfill()
        Task { @MainActor in
            configureAudioSession()
            startAudioEngine()
            isCallActive = true
            activeCallUUID = action.callUUID
            startCallTimer()

            let callUpdate = CXCallUpdate()
            callUpdate.remoteHandle = action.handle
            callUpdate.localizedCallerName = action.contactIdentifier
            provider.reportCall(with: action.callUUID, updated: callUpdate)
        }
    }

    nonisolated func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) {
    }

    nonisolated func provider(_ provider: CXProvider, didDeactivate audioSession: AVAudioSession) {
    }
}
