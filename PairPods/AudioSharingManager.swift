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
final class AudioSharingManager: ObservableObject {
    private static let reconnectTimeoutKey = "PairPods.ReconnectTimeout"
    private let audioDeviceManager: AudioDeviceManager
    private var monitoringTask: Task<Void, Never>?
    private var reconnectTask: Task<Void, Never>?

    var reconnectTimeout: TimeInterval {
        UserDefaults.standard.object(forKey: Self.reconnectTimeoutKey) as? TimeInterval ?? 10.0
    }

    var isSharingAudio: Bool {
        state == .active
    }

    var stateDidChange: ((AudioSharingState) -> Void)?

    @Published private(set) var state: AudioSharingState = .inactive {
        didSet {
            stateDidChange?(state)
        }
    }

    init(audioDeviceManager: AudioDeviceManager) {
        logDebug("Initializing AudioSharingManager")
        self.audioDeviceManager = audioDeviceManager
        setupMonitoring()
    }

    deinit {
        logDebug("AudioSharingManager deinitializing")
        monitoringTask?.cancel()
        reconnectTask?.cancel()
    }

    // MARK: - Public Methods

    func cleanup() async {
        logInfo("Cleaning up AudioSharingManager")
        reconnectTask?.cancel()
        reconnectTask = nil
    }

    func startSharing() async {
        logInfo("Received request to start audio sharing")
        reconnectTask?.cancel()
        reconnectTask = nil
        await handleStateTransition(to: .starting)
    }

    func stopSharing() async {
        logInfo("Received request to stop audio sharing")
        reconnectTask?.cancel()
        reconnectTask = nil
        await handleStateTransition(to: .stopping)
    }

    // MARK: - Private Methods

    private func setupMonitoring() {
        logDebug("Setting up audio configuration monitoring")
        monitoringTask = Task {
            await withTaskGroup(of: Void.self) { group in
                group.addTask { [weak self] in
                    for await _ in NotificationCenter.default.notifications(named: .audioDeviceConfigurationChanged) {
                        logWarning("Audio device configuration changed, handling disconnect")
                        await self?.handleDeviceDisconnect()
                    }
                }
            }
        }
    }

    private func handleDeviceDisconnect() async {
        guard state == .active else { return }

        await stopSharing()

        // Check if enough selected devices remain to immediately restart
        await audioDeviceManager.refreshCompatibleDevices()
        if audioDeviceManager.selectedDevices.count >= 2 {
            logInfo("2+ selected devices still available, restarting sharing immediately")
            await startSharing()
            return
        }

        guard reconnectTimeout > 0 else {
            logInfo("Reconnect disabled, staying inactive")
            return
        }

        logInfo("Watching for reconnection of selected devices")
        reconnectTask?.cancel()
        reconnectTask = Task {
            let deadline = Date().addingTimeInterval(reconnectTimeout)
            while Date() < deadline {
                guard !Task.isCancelled else {
                    logInfo("Reconnect watch cancelled")
                    return
                }

                await audioDeviceManager.refreshCompatibleDevices()
                if audioDeviceManager.selectedDevices.count >= 2 {
                    logInfo("Enough selected devices reconnected, restarting audio sharing")
                    await startSharing()
                    return
                }

                try? await Task.sleep(nanoseconds: 500_000_000)
            }
            logInfo("Reconnect timeout expired, giving up")
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
        logInfo("Stopping audio sharing")
        state = .stopping

        await audioDeviceManager.restoreOutputDevice()
        await audioDeviceManager.removeMultiOutputDevice()

        await handleStateTransition(to: .inactive)
        logInfo("Audio sharing stopped successfully")
    }
}
