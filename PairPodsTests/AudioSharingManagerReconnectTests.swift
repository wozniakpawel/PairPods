//
//  AudioSharingManagerReconnectTests.swift
//  PairPodsTests
//

import CoreAudio
@testable import PairPods
import Testing

struct AudioSharingManagerReconnectTests {
    private let defaults = TestDefaults.make()
    /// Private bus: NotificationCenter.default is process-wide, so a notification posted
    /// by another suite running in parallel would drive this manager too.
    private let center = NotificationCenter()

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

    @Test("Disconnect with devices still present rebuilds the aggregate")
    @MainActor func disconnectStopsSharingAndReconnects() async {
        defer { defaults.removeObject(forKey: Self.timeoutKey) }
        defaults.set(1.0, forKey: Self.timeoutKey)
        let mock = MockAudioSystem()
        let deviceManager = AudioDeviceManager(audioSystem: mock, shouldShowAlerts: false, userDefaults: defaults, notificationCenter: center)
        let sharingManager = AudioSharingManager(audioDeviceManager: deviceManager, userDefaults: defaults, notificationCenter: center)

        mock.devicesToReturn = [
            AudioDeviceFixtures.bluetoothDevice(id: 1, uid: "bt1", sampleRate: 48000),
            AudioDeviceFixtures.bluetoothDevice(id: 2, uid: "bt2", sampleRate: 48000),
        ]
        mock.createAggregateResult = .success(999)

        await sharingManager.startSharing()
        #expect(sharingManager.state == .active)
        #expect(mock.createAggregateCalls.count == 1)

        center.postDeviceConfigurationChanged()

        // Asserting on the state alone proves nothing here: it is already .active, so any
        // predicate accepting .active is satisfied before the notification is even
        // processed. The observable that distinguishes a real restart is a second
        // aggregate being built.
        let rebuilt = await waitUntil { mock.createAggregateCalls.count >= 2 }
        #expect(rebuilt, "Aggregate was never rebuilt; createAggregateDevice called \(mock.createAggregateCalls.count) time(s)")
        #expect(sharingManager.state == .active, "Ended in \(sharingManager.state) after rebuilding")
    }

    @Test("Reconnection gives up after the timeout when devices do not reappear")
    @MainActor func reconnectionGivesUpAfterTimeout() async {
        defer { defaults.removeObject(forKey: Self.timeoutKey) }
        let reconnectTimeout = Duration.milliseconds(300)
        defaults.set(0.3, forKey: Self.timeoutKey)
        let mock = MockAudioSystem()
        let deviceManager = AudioDeviceManager(audioSystem: mock, shouldShowAlerts: false, userDefaults: defaults, notificationCenter: center)
        let sharingManager = AudioSharingManager(audioDeviceManager: deviceManager, userDefaults: defaults, notificationCenter: center)

        mock.devicesToReturn = [
            AudioDeviceFixtures.bluetoothDevice(id: 1, uid: "bt1", sampleRate: 48000),
            AudioDeviceFixtures.bluetoothDevice(id: 2, uid: "bt2", sampleRate: 48000),
        ]
        mock.createAggregateResult = .success(999)

        await sharingManager.startSharing()
        #expect(sharingManager.state == .active)
        #expect(mock.createAggregateCalls.count == 1)

        mock.devicesToReturn = []
        let disconnectedAt = ContinuousClock.now
        center.postDeviceConfigurationChanged()

        // .inactive on its own is not evidence of giving up: production passes through it
        // during stopSharing(), before the reconnect watch even starts. The watch has only
        // genuinely expired once the timeout has elapsed and nothing was rebuilt.
        let expired = await waitUntil {
            ContinuousClock.now - disconnectedAt > reconnectTimeout + .milliseconds(500)
        }
        #expect(expired)
        #expect(sharingManager.state == .inactive, "Ended in \(sharingManager.state) rather than giving up")
        #expect(mock.createAggregateCalls.count == 1,
                "Rebuilt the aggregate \(mock.createAggregateCalls.count - 1) time(s) despite no devices being available")
    }
}
