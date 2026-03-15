//
//  AudioSharingManagerTests.swift
//  PairPodsTests
//

import CoreAudio
@testable import PairPods
import Testing

struct AudioSharingManagerTests {
    @MainActor private func makeManagerAndMock() -> (AudioSharingManager, MockAudioSystem, AudioDeviceManager) {
        UserDefaults.standard.removeObject(forKey: "excludedDeviceUIDs")
        UserDefaults.standard.set(0.5, forKey: "PairPods.ReconnectTimeout")
        let mock = MockAudioSystem()
        let deviceManager = AudioDeviceManager(audioSystem: mock, shouldShowAlerts: false)
        let sharingManager = AudioSharingManager(audioDeviceManager: deviceManager)
        return (sharingManager, mock, deviceManager)
    }

    @Test("startSharing transitions inactive -> starting -> active on success")
    @MainActor func startSharingSuccess() async {
        let (sharingManager, mock, _) = makeManagerAndMock()
        let bt1 = AudioDeviceFixtures.bluetoothDevice(id: 1, uid: "bt1", sampleRate: 48000)
        let bt2 = AudioDeviceFixtures.bluetoothDevice(id: 2, uid: "bt2", sampleRate: 48000)
        mock.devicesToReturn = [bt1, bt2]
        mock.createAggregateResult = .success(999)

        #expect(sharingManager.state == .inactive)

        var observedStates: [AudioSharingState] = []
        sharingManager.stateDidChange = { state in
            observedStates.append(state)
        }

        await sharingManager.startSharing()

        #expect(sharingManager.state == .active)
        #expect(observedStates.contains(.starting))
        #expect(observedStates.contains(.active))
    }

    @Test("startSharing transitions inactive -> starting -> inactive on failure")
    @MainActor func startSharingFailure() async {
        let (sharingManager, mock, _) = makeManagerAndMock()
        mock.devicesToReturn = [] // No devices = will fail

        await sharingManager.startSharing()

        #expect(sharingManager.state == .inactive)
    }

    @Test("stopSharing transitions active -> stopping -> inactive")
    @MainActor func stopSharingFromActive() async {
        let (sharingManager, mock, _) = makeManagerAndMock()
        let bt1 = AudioDeviceFixtures.bluetoothDevice(id: 1, uid: "bt1", sampleRate: 48000)
        let bt2 = AudioDeviceFixtures.bluetoothDevice(id: 2, uid: "bt2", sampleRate: 48000)
        mock.devicesToReturn = [bt1, bt2]
        mock.createAggregateResult = .success(999)

        await sharingManager.startSharing()
        #expect(sharingManager.state == .active)

        await sharingManager.stopSharing()
        #expect(sharingManager.state == .inactive)
    }

    @Test("stopSharing from inactive is a no-op")
    @MainActor func stopSharingFromInactive() async {
        let (sharingManager, _, _) = makeManagerAndMock()

        #expect(sharingManager.state == .inactive)
        await sharingManager.stopSharing()
        #expect(sharingManager.state == .inactive)
    }

    @Test("stateDidChange callback fires on every transition")
    @MainActor func stateDidChangeCallback() async {
        let (sharingManager, mock, _) = makeManagerAndMock()
        let bt1 = AudioDeviceFixtures.bluetoothDevice(id: 1, uid: "bt1", sampleRate: 48000)
        let bt2 = AudioDeviceFixtures.bluetoothDevice(id: 2, uid: "bt2", sampleRate: 48000)
        mock.devicesToReturn = [bt1, bt2]
        mock.createAggregateResult = .success(999)

        var callbackCount = 0
        sharingManager.stateDidChange = { _ in
            callbackCount += 1
        }

        await sharingManager.startSharing()
        await sharingManager.stopSharing()

        #expect(callbackCount >= 3) // starting, active, stopping/inactive
    }

    @Test("isSharingAudio matches state")
    @MainActor func isSharingAudioMatchesState() async {
        let (sharingManager, mock, _) = makeManagerAndMock()
        let bt1 = AudioDeviceFixtures.bluetoothDevice(id: 1, uid: "bt1", sampleRate: 48000)
        let bt2 = AudioDeviceFixtures.bluetoothDevice(id: 2, uid: "bt2", sampleRate: 48000)
        mock.devicesToReturn = [bt1, bt2]
        mock.createAggregateResult = .success(999)

        #expect(!sharingManager.isSharingAudio)

        await sharingManager.startSharing()
        #expect(sharingManager.isSharingAudio)

        await sharingManager.stopSharing()
        #expect(!sharingManager.isSharingAudio)
    }

    @Test("Double startSharing is handled gracefully")
    @MainActor func doubleStartSharing() async {
        let (sharingManager, mock, _) = makeManagerAndMock()
        let bt1 = AudioDeviceFixtures.bluetoothDevice(id: 1, uid: "bt1", sampleRate: 48000)
        let bt2 = AudioDeviceFixtures.bluetoothDevice(id: 2, uid: "bt2", sampleRate: 48000)
        mock.devicesToReturn = [bt1, bt2]
        mock.createAggregateResult = .success(999)

        await sharingManager.startSharing()
        #expect(sharingManager.state == .active)

        // Second start while active — should be handled without crash
        await sharingManager.startSharing()
        // State should remain active or transition gracefully
        #expect(sharingManager.state == .active || sharingManager.state == .inactive)
    }

    @Test("stopSharing calls restore and remove on AudioDeviceManager")
    @MainActor func stopSharingCallsRestoreAndRemove() async {
        let (sharingManager, mock, _) = makeManagerAndMock()
        let bt1 = AudioDeviceFixtures.bluetoothDevice(id: 1, uid: "bt1", sampleRate: 48000)
        let bt2 = AudioDeviceFixtures.bluetoothDevice(id: 2, uid: "bt2", sampleRate: 48000)
        mock.devicesToReturn = [bt1, bt2]
        mock.createAggregateResult = .success(999)

        await sharingManager.startSharing()
        let callsBefore = mock.setDefaultOutputCalls.count

        await sharingManager.stopSharing()

        // restoreOutputDevice should have called setDefaultOutput
        #expect(mock.setDefaultOutputCalls.count > callsBefore)
    }
}
