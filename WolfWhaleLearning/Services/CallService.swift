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
            if error == nil {
                Task { @MainActor in
                    self?.activeCallUUID = uuid
                    self?.remoteParticipantName = displayName
                }
            }
        }
    }

    func endCall() {
        guard let uuid = activeCallUUID else { return }
        let endAction = CXEndCallAction(call: uuid)
        let transaction = CXTransaction(action: endAction)
        callController.request(transaction, completion: { _ in })
    }

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
    }

    nonisolated func provider(_ provider: CXProvider, didDeactivate audioSession: AVAudioSession) {
    }

    nonisolated private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(
            .playAndRecord,
            mode: .voiceChat,
            options: [.allowBluetoothHFP, .duckOthers]
        )
        try? session.setActive(true)
    }
}
