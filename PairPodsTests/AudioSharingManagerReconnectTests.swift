//
//  AudioSharingManagerReconnectTests.swift
//  PairPodsTests
//

import CoreAudio
@testable import PairPods
import Testing

@MainActor
struct AudioSharingManagerReconnectTests {
    private let defaults = TestDefaults.make()
    private let timeoutKey = "PairPods.ReconnectTimeout"
    private let first = AudioDeviceFixtures.bluetoothDevice(id: 1, uid: "reconnect-a")
    private let second = AudioDeviceFixtures.bluetoothDevice(id: 2, uid: "reconnect-b")

    @Test("Reconnects when the selected device returns with a new Core Audio ID")
    func reconnectsAfterDeviceReturns() async throws {
        let (sharing, devices, audio) = try await startSharing(timeout: 5)
        audio.devicesToReturn = [first]
        await devices.handleAudioDeviceChange()
        #expect(sharing.state == .reconnecting)
        #expect(sharing.isSharingEnabled)
        #expect(audio.createAggregateCalls.count == 1)

        audio.devicesToReturn = [first, AudioDeviceFixtures.bluetoothDevice(id: 3, uid: second.uid)]
        try await waitForState(.active, in: sharing)
        #expect(audio.createAggregateCalls.count == 2)
        #expect(audio.destroyAggregateCalls == [999])
        await sharing.stopSharing()
        await devices.cleanup()
    }

    @Test("Stopping cancels an automatic restart even when the selected device returns")
    func stopCancelsReconnect() async throws {
        let (sharing, devices, audio) = try await startSharing(timeout: 5)
        audio.devicesToReturn = [first]
        await devices.handleAudioDeviceChange()
        #expect(sharing.state == .reconnecting)

        audio.devicesToReturn = [first, second]
        await sharing.stopSharing()
        await devices.handleAudioDeviceChange()
        #expect(sharing.state == .inactive)
        #expect(audio.createAggregateCalls.count == 1)
        #expect(audio.destroyAggregateCalls == [999])
        await devices.cleanup()
    }

    @Test("Reconnect times out when too few devices return")
    func reconnectTimesOut() async throws {
        let (sharing, devices, audio) = try await startSharing(timeout: 2)
        audio.devicesToReturn = [first]
        await devices.handleAudioDeviceChange()
        #expect(sharing.state == .reconnecting)

        let callsAfterDisconnect = audio.fetchAllDevicesCalls
        try await waitUntil { audio.fetchAllDevicesCalls >= callsAfterDisconnect + 3 }
        try await waitForState(.inactive, in: sharing)
        let callsAfterTimeout = audio.fetchAllDevicesCalls
        try await Task.sleep(for: .milliseconds(600))
        #expect(audio.fetchAllDevicesCalls == callsAfterTimeout)
        #expect(audio.createAggregateCalls.count == 1)
        await devices.cleanup()
    }

    private func startSharing(timeout: TimeInterval) async throws -> (AudioSharingManager, AudioDeviceManager, MockAudioSystem) {
        defaults.set(timeout, forKey: timeoutKey)
        let audio = MockAudioSystem()
        audio.devicesToReturn = [first, second]
        let devices = AudioDeviceManager(audioSystem: audio, shouldShowAlerts: false, monitorHardware: false, userDefaults: defaults)
        let sharing = AudioSharingManager(audioDeviceManager: devices, userDefaults: defaults)
        await sharing.startSharing()
        try #require(sharing.state == .active)
        return (sharing, devices, audio)
    }

    private func waitForState(_ state: AudioSharingState, in sharing: AudioSharingManager) async throws {
        try await waitUntil { sharing.state == state }
    }

    private func waitUntil(_ condition: () -> Bool) async throws {
        let clock = ContinuousClock()
        let deadline = clock.now + .seconds(10)
        while !condition(), clock.now < deadline {
            try await clock.sleep(for: .milliseconds(20))
        }
        try #require(condition())
    }
}
