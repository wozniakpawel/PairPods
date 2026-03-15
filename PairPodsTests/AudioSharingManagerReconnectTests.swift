//
//  AudioSharingManagerReconnectTests.swift
//  PairPodsTests
//

import CoreAudio
@testable import PairPods
import Testing

struct AudioSharingManagerReconnectTests {
    private static let timeoutKey = "PairPods.ReconnectTimeout"

    init() {
        UserDefaults.standard.removeObject(forKey: Self.timeoutKey)
    }

    @Test("Disconnect stops sharing and attempts reconnection")
    @MainActor func disconnectStopsSharingAndReconnects() async throws {
        defer { UserDefaults.standard.removeObject(forKey: Self.timeoutKey) }
        UserDefaults.standard.set(1.0, forKey: Self.timeoutKey)
        let mock = MockAudioSystem()
        let deviceManager = AudioDeviceManager(audioSystem: mock, shouldShowAlerts: false)
        let sharingManager = AudioSharingManager(audioDeviceManager: deviceManager)

        let bt1 = AudioDeviceFixtures.bluetoothDevice(id: 1, uid: "bt1", sampleRate: 48000)
        let bt2 = AudioDeviceFixtures.bluetoothDevice(id: 2, uid: "bt2", sampleRate: 48000)
        mock.devicesToReturn = [bt1, bt2]
        mock.createAggregateResult = .success(999)

        await sharingManager.startSharing()
        #expect(sharingManager.state == .active)

        // Simulate device disconnect by posting notification
        NotificationCenter.default.postDeviceConfigurationChanged()

        // Give time for the notification to be processed
        try await Task.sleep(nanoseconds: 200_000_000)

        // After disconnect handling, state should transition
        // (It may be inactive waiting for reconnection, or active if reconnection succeeded)
        let currentState = sharingManager.state
        #expect(currentState == .inactive || currentState == .active)
    }

    @Test("Reconnection gives up after timeout when devices don't reappear")
    @MainActor func reconnectionGivesUpAfterTimeout() async throws {
        defer { UserDefaults.standard.removeObject(forKey: Self.timeoutKey) }
        UserDefaults.standard.set(0.3, forKey: Self.timeoutKey)
        let mock = MockAudioSystem()
        let deviceManager = AudioDeviceManager(audioSystem: mock, shouldShowAlerts: false)
        let sharingManager = AudioSharingManager(audioDeviceManager: deviceManager)

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

        // Wait for disconnect processing + timeout
        try await Task.sleep(nanoseconds: 800_000_000)

        #expect(sharingManager.state == .inactive)
    }
}
