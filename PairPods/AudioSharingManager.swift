//
//  AudioSharingManager.swift
//  PairPods
//
//  Created by Pawel Wozniak on 24/02/2025.
//

import Combine
import Foundation

enum AudioSharingState: String {
    case inactive, starting, active, stopping
}

@MainActor
final class AudioSharingManager: AudioSharingManaging {
    private let audioDeviceManager: any AudioDeviceManaging
    private var monitoringTask: Task<Void, Never>?

    var isSharingAudio: Bool { state == .active }
    var stateDidChange: ((AudioSharingState) -> Void)?

    @Published private(set) var state: AudioSharingState = .inactive {
        didSet {
            stateDidChange?(state)
        }
    }

    init(audioDeviceManager: any AudioDeviceManaging) {
        logDebug("Initializing AudioSharingManager")
        self.audioDeviceManager = audioDeviceManager
        setupMonitoring()
    }

    deinit {
        logDebug("AudioSharingManager deinitializing")
        monitoringTask?.cancel()
    }

    // MARK: - Public Methods

    public func cleanup() async {
        logInfo("Cleaning up AudioSharingManager")
    }

    public func startSharing() {
        logInfo("Received request to start audio sharing")
        Task {
            await handleStateTransition(to: .starting)
        }
    }

    public func stopSharing() {
        logInfo("Received request to stop audio sharing")
        Task {
            await handleStateTransition(to: .stopping)
        }
    }

    // MARK: - Private Methods

    private func setupMonitoring() {
        logDebug("Setting up audio configuration monitoring")
        monitoringTask = Task {
            await withTaskGroup(of: Void.self) { group in
                group.addTask { [weak self] in
                    for await _ in NotificationCenter.default.notifications(named: .audioDeviceConfigurationChanged) {
                        logWarning("Audio device configuration changed, stopping sharing")
                        await self?.stopSharing()
                    }
                }
            }
        }
    }

    private func handleStateTransition(to newState: AudioSharingState) async {
        logInfo("Processing state transition: \(state) -> \(newState)")

        switch (state, newState) {
        case (.inactive, .starting):
            await startAudioSharing()

        case (.active, .stopping):
            await stopAudioSharing()

        case (.starting, .active), (.stopping, .inactive):
            logDebug("Completing state transition to \(newState)")
            state = newState

        case (.starting, .inactive):
            logWarning("Audio sharing failed to start")
            state = .inactive

        case (.inactive, .stopping), (.stopping, .stopping):
            logDebug("Ignoring redundant stop request - already \(state)")

        default:
            logWarning("Invalid state transition attempted: \(state) -> \(newState)")
        }
    }

    private func startAudioSharing() async {
        logInfo("Starting audio sharing process")
        state = .starting

        do {
            try await audioDeviceManager.setupMultiOutputDevice()
            await handleStateTransition(to: .active)
            logInfo("Audio sharing started successfully")
        } catch {
            logError("Failed to start audio sharing", error: .systemError(error))
            await handleStateTransition(to: .inactive)
        }
    }

    private func stopAudioSharing() async {
        guard state == .active else {
            logDebug("Stop request ignored - audio sharing not active (current state: \(state))")
            return
        }

        logInfo("Stopping audio sharing")
        state = .stopping

        await audioDeviceManager.restoreOutputDevice()
        await audioDeviceManager.removeMultiOutputDevice()

        state = .inactive
        logInfo("Audio sharing stopped successfully")
    }
}
