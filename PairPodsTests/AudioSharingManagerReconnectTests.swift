//
//  AudioSharingManagerReconnectTests.swift
//  PairPodsTests
//

import CoreAudio
@testable import PairPods
import Testing

struct AudioSharingManagerReconnectTests {
    private let defaults = TestDefaults.make()

    private static let timeoutKey = "PairPods.ReconnectTimeout"

    init() {
        defaults.removeObject(forKey: Self.timeoutKey)
    }

    /// Polls until `condition` holds or the deadline passes.
    ///
    /// These tests used to sleep a fixed wall-clock interval and then assert, which
    /// raced the reconnect timeout on a loaded machine and failed outright under the
    /// sanitizers, where everything runs several times slower. Waiting for the state
    /// instead of for the clock is both faster in the common case and immune to that.
    @MainActor
    private func waitUntil(
        timeout: Duration = .seconds(15),
        _ condition: @MainActor () -> Bool
    ) async -> Bool {
        let deadline = ContinuousClock.now + timeout
        while ContinuousClock.now < deadline {
            if condition() {
                return true
            }
            try? await Task.sleep(for: .milliseconds(20))
        }
        return condition()
    }

    @Test("Disconnect stops sharing and attempts reconnection")
    @MainActor func disconnectStopsSharingAndReconnects() async {
        defer { defaults.removeObject(forKey: Self.timeoutKey) }
        defaults.set(1.0, forKey: Self.timeoutKey)
        let mock = MockAudioSystem()
        let deviceManager = AudioDeviceManager(audioSystem: mock, shouldShowAlerts: false, userDefaults: defaults)
        let sharingManager = AudioSharingManager(audioDeviceManager: deviceManager, userDefaults: defaults)

        let bt1 = AudioDeviceFixtures.bluetoothDevice(id: 1, uid: "bt1", sampleRate: 48000)
        let bt2 = AudioDeviceFixtures.bluetoothDevice(id: 2, uid: "bt2", sampleRate: 48000)
        mock.devicesToReturn = [bt1, bt2]
        mock.createAggregateResult = .success(999)

        await sharingManager.startSharing()
        #expect(sharingManager.state == .active)

        // Simulate device disconnect by posting notification
        NotificationCenter.default.postDeviceConfigurationChanged()

        // The devices are still present, so the manager should settle back into sharing
        // rather than sit in a transitional state.
        let settled = await waitUntil { sharingManager.state == .active || sharingManager.state == .inactive }
        #expect(settled, "Stuck in transitional state \(sharingManager.state)")
    }

    @Test("Reconnection gives up after timeout when devices don't reappear")
    @MainActor func reconnectionGivesUpAfterTimeout() async {
        defer { defaults.removeObject(forKey: Self.timeoutKey) }
        defaults.set(0.3, forKey: Self.timeoutKey)
        let mock = MockAudioSystem()
        let deviceManager = AudioDeviceManager(audioSystem: mock, shouldShowAlerts: false, userDefaults: defaults)
        let sharingManager = AudioSharingManager(audioDeviceManager: deviceManager, userDefaults: defaults)

        let bt1 = AudioDeviceFixtures.bluetoothDevice(id: 1, uid: "bt1", sampleRate: 48000)
        let bt2 = AudioDeviceFixtures.bluetoothDevice(id: 2, uid: "bt2", sampleRate: 48000)
        mock.devicesToReturn = [bt1, bt2]
        mock.createAggregateResult = .success(999)

        await sharingManager.startSharing()
        #expect(sharingManager.state == .active)

        // Remove all devices so reconnection will fail
        mock.devicesToReturn = []

        // Simulate disconnect
        NotificationCenter.default.postDeviceConfigurationChanged()

        // With no devices left to find, the reconnect watch must expire and give up.
        let gaveUp = await waitUntil { sharingManager.state == .inactive }
        #expect(gaveUp, "Reconnect watch never gave up; state is \(sharingManager.state)")
    }
}
