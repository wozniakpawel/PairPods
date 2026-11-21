//
//  AudioSharingManagerTests.swift
//  PairPodsTests
//

import Combine
import CoreAudio
@testable import PairPods
import Testing

struct AudioSharingManagerTests {
    private let defaults = TestDefaults.make()

    @MainActor private func makeManagerAndMock() -> (AudioSharingManager, MockAudioSystem, AudioDeviceManager) {
        let mock = MockAudioSystem()
        let deviceManager = AudioDeviceManager(audioSystem: mock, shouldShowAlerts: false, monitorHardware: false, userDefaults: defaults)
        let sharingManager = AudioSharingManager(audioDeviceManager: deviceManager, userDefaults: defaults)
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
        let observation = sharingManager.$state.sink { observedStates.append($0) }
        defer { observation.cancel() }

        await sharingManager.startSharing()

        #expect(sharingManager.state == .active)
        #expect(observedStates == [.inactive, .starting, .active])
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

        await sharingManager.startSharing()
        #expect(sharingManager.state == .active)
        #expect(mock.createAggregateCalls.count == 1)
    }

    @Test("Stopping during setup releases the aggregate and leaves sharing off")
    @MainActor func stopDuringSetup() async {
        let (sharing, audio, _) = makeManagerAndMock()
        audio.devicesToReturn = [
            AudioDeviceFixtures.bluetoothDevice(id: 1, uid: "stop-a"),
            AudioDeviceFixtures.bluetoothDevice(id: 2, uid: "stop-b"),
        ]
        let (created, creation) = AsyncStream<Void>.makeStream()
        let (resume, continuation) = AsyncStream<Void>.makeStream()
        audio.beforeReturningAggregate = {
            creation.yield(())
            for await _ in resume {
                break
            }
        }
        let start = Task { await sharing.startSharing() }
        for await _ in created {
            break
        }
        #expect(sharing.state == .starting)

        let observation = sharing.$state.sink { state in
            if state == .stopping {
                continuation.finish()
            }
        }
        defer { observation.cancel() }
        await sharing.stopSharing()
        await start.value
        #expect(sharing.state == .inactive)
        #expect(audio.destroyAggregateCalls == [999])
        #expect(audio.setDefaultOutputCalls.isEmpty)
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

        #expect(mock.setDefaultOutputCalls.count > callsBefore)
    }

    @Test("A failed start exposes its reason and a successful retry clears it")
    @MainActor func failureMessageClearsOnRetry() async {
        let (sharingManager, mock, deviceManager) = makeManagerAndMock()
        mock.devicesToReturn = [
            AudioDeviceFixtures.bluetoothDevice(id: 1, uid: "bt1"),
            AudioDeviceFixtures.bluetoothDevice(id: 2, uid: "bt2"),
        ]
        mock.createAggregateResult = .failure(AppError.operationError("Audio device unavailable"))

        await sharingManager.startSharing()
        #expect(sharingManager.lastErrorMessage == "Audio device unavailable")
        #expect(sharingManager.state == .inactive)

        mock.createAggregateResult = .success(999)
        await sharingManager.startSharing()
        #expect(sharingManager.lastErrorMessage == nil)
        #expect(sharingManager.state == .active)

        await sharingManager.stopSharing()
        await deviceManager.cleanup()
    }
}
