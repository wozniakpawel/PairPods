//
//  AudioSharingManager.swift
//  PairPods
//
//  Created by Pawel Wozniak on 24/02/2025.
//

import Combine
import Foundation

enum AudioSharingState: String {
    case inactive, starting, active, reconnecting, stopping
}

@MainActor
final class AudioSharingManager: ObservableObject {
    private static let reconnectTimeoutKey = "PairPods.ReconnectTimeout"
    private let devices: AudioDeviceManager
    private let userDefaults: UserDefaults
    private var outputTask: Task<Void, Never>?

    @Published private(set) var state: AudioSharingState = .inactive
    @Published private(set) var lastErrorMessage: String?

    var isSharingAudio: Bool {
        state == .active
    }

    var isSharingEnabled: Bool {
        state == .active || state == .reconnecting
    }

    var isTransitioning: Bool {
        state == .starting || state == .stopping
    }

    private var reconnectTimeout: TimeInterval {
        userDefaults.object(forKey: Self.reconnectTimeoutKey) as? TimeInterval ?? 10
    }

    init(audioDeviceManager: AudioDeviceManager, userDefaults: UserDefaults = .standard) {
        devices = audioDeviceManager
        self.userDefaults = userDefaults
        devices.configurationDidChange = { [weak self] in
            self?.reconfigure()
        }
    }

    deinit {
        outputTask?.cancel()
    }

    func startSharing() async {
        guard state == .inactive else { return }
        state = .starting
        outputTask = Task { [weak self] in
            await self?.startOutput()
        }
        await outputTask?.value
    }

    func stopSharing() async {
        if state == .stopping {
            await outputTask?.value
            return
        }
        guard state != .inactive else { return }

        let previousTask = outputTask
        previousTask?.cancel()
        state = .stopping
        outputTask = Task { [weak self, devices] in
            await previousTask?.value
            await devices.stopOutput()
            self?.outputTask = nil
            self?.state = .inactive
        }
        await outputTask?.value
    }

    private func startOutput() async {
        guard !Task.isCancelled else { return }
        lastErrorMessage = nil
        do {
            try await devices.setupMultiOutputDevice()
            guard !Task.isCancelled else { return }
            outputTask = nil
            state = .active
            if !devices.isOutputConnected {
                reconfigure()
            }
        } catch {
            guard !Task.isCancelled else { return }
            outputTask = nil
            lastErrorMessage = (error as? ChannelRoutingError)?.message ?? error.localizedDescription
            logError("Failed to start audio sharing", error: .systemError(error))
            state = .inactive
        }
    }

    private func reconfigure() {
        guard state == .active else { return }
        let requiredUIDs = devices.requiredReconnectUIDs
        state = .reconnecting
        outputTask = Task { [weak self, devices] in
            await devices.stopOutput()
            await self?.reconnect(requiredUIDs: requiredUIDs)
        }
    }

    private func reconnect(requiredUIDs: Set<String>) async {
        let clock = ContinuousClock()
        let deadline = clock.now + .seconds(reconnectTimeout)
        repeat {
            await devices.refreshCompatibleDevices()
            guard !Task.isCancelled else { return }

            let selected = devices.selectedDevices
            // Excluding a device while waiting lets the other selected devices resume.
            let required = requiredUIDs.filter(devices.isDeviceSelected)
            if selected.count >= 2, required.isSubset(of: selected.map(\.uid)) {
                state = .starting
                await startOutput()
                return
            }
            guard clock.now < deadline else { break }
            try? await clock.sleep(until: min(clock.now + .milliseconds(500), deadline))
            guard !Task.isCancelled, clock.now < deadline else { break }
        } while true

        guard !Task.isCancelled else {
            return
        }
        outputTask = nil
        state = .inactive
    }
}
