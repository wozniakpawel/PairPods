//
//  AudioDeviceManagerFlowTests.swift
//  PairPodsTests
//

import CoreAudio
@testable import PairPods
import Testing

@Suite("AudioDeviceManager Flow")
struct AudioDeviceManagerFlowTests {
    private let defaults = TestDefaults.make()

    @MainActor private func makeMockAndManager() -> (MockAudioSystem, AudioDeviceManager) {
        defaults.removeObject(forKey: "excludedDeviceUIDs")
        let mock = MockAudioSystem()
        let manager = AudioDeviceManager(audioSystem: mock, shouldShowAlerts: false, monitorHardware: false, userDefaults: defaults)
        return (mock, manager)
    }

    @Test("Setup creates aggregate device and sets default output")
    @MainActor func setupCreatesAggregateAndSetsDefault() async throws {
        let (mock, manager) = makeMockAndManager()
        let bt1 = AudioDeviceFixtures.bluetoothDevice(id: 1, uid: "bt1", sampleRate: 48000)
        let bt2 = AudioDeviceFixtures.bluetoothDevice(id: 2, uid: "bt2", sampleRate: 48000)
        mock.devicesToReturn = [bt1, bt2]
        mock.createAggregateResult = .success(999)

        try await manager.setupMultiOutputDevice()

        #expect(mock.createAggregateCalls.count == 1)
        #expect(mock.setDefaultOutputCalls.contains(999))
    }

    @Test("Setup does not force sample rate changes on Bluetooth devices")
    @MainActor func setupDoesNotForceSampleRateChanges() async throws {
        let (mock, manager) = makeMockAndManager()
        let bt1 = AudioDeviceFixtures.bluetoothDevice(id: 1, uid: "bt1", sampleRate: 44100)
        let bt2 = AudioDeviceFixtures.bluetoothDevice(id: 2, uid: "bt2", sampleRate: 48000)
        mock.devicesToReturn = [bt1, bt2]
        mock.createAggregateResult = .success(999)

        try await manager.setupMultiOutputDevice()

        #expect(mock.setSampleRateCalls.isEmpty)
    }

    @Test("Setup skips sync when rates match")
    @MainActor func setupSkipsSyncWhenRatesMatch() async throws {
        let (mock, manager) = makeMockAndManager()
        let bt1 = AudioDeviceFixtures.bluetoothDevice(id: 1, uid: "bt1", sampleRate: 48000)
        let bt2 = AudioDeviceFixtures.bluetoothDevice(id: 2, uid: "bt2", sampleRate: 48000)
        mock.devicesToReturn = [bt1, bt2]
        mock.createAggregateResult = .success(999)

        try await manager.setupMultiOutputDevice()

        #expect(mock.setSampleRateCalls.isEmpty)
    }

    @Test("Setup throws when fewer than 2 compatible devices")
    @MainActor func setupThrowsWhenNotEnoughDevices() async {
        let (mock, manager) = makeMockAndManager()
        mock.devicesToReturn = [AudioDeviceFixtures.bluetoothDevice()]

        let thrown = await errorThrown { try await manager.setupMultiOutputDevice() }
        #expect(thrown is AppError, "Expected an AppError, got \(String(describing: thrown))")
    }

    @Test("Setup throws when aggregate creation fails")
    @MainActor func setupThrowsWhenAggregateCreationFails() async {
        let (mock, manager) = makeMockAndManager()
        let bt1 = AudioDeviceFixtures.bluetoothDevice(id: 1, uid: "bt1", sampleRate: 48000)
        let bt2 = AudioDeviceFixtures.bluetoothDevice(id: 2, uid: "bt2", sampleRate: 48000)
        mock.devicesToReturn = [bt1, bt2]
        mock.createAggregateResult = .failure(AppError.operationError("Failed"))

        let thrown = await errorThrown { try await manager.setupMultiOutputDevice() }
        #expect(thrown is AppError, "Expected an AppError, got \(String(describing: thrown))")
    }

    @Test("Restore falls back to master device")
    @MainActor func restoreFallsBackToMaster() async throws {
        let (mock, manager) = makeMockAndManager()
        let bt1 = AudioDeviceFixtures.bluetoothDevice(id: 1, uid: "bt1", sampleRate: 44100)
        let bt2 = AudioDeviceFixtures.bluetoothDevice(id: 2, uid: "bt2", sampleRate: 48000)
        mock.devicesToReturn = [bt1, bt2]
        mock.createAggregateResult = .success(999)

        try await manager.setupMultiOutputDevice()
        mock.clearRecordedCalls()

        await manager.stopOutput()

        #expect(mock.setDefaultOutputCalls == [bt2.id])
        #expect(mock.destroyAggregateCalls == [999])
    }

    @Test("Stopping leaves a manually selected system output in place")
    @MainActor func stopPreservesAnotherOutput() async throws {
        let (audio, manager) = makeMockAndManager()
        audio.devicesToReturn = [
            AudioDeviceFixtures.bluetoothDevice(id: 1, uid: "manual-a"),
            AudioDeviceFixtures.bluetoothDevice(id: 2, uid: "manual-b"),
        ]
        try await manager.setupMultiOutputDevice()
        audio.defaultDevice = (nil, 300)

        await manager.stopOutput()

        #expect(audio.setDefaultOutputCalls == [999])
        #expect(audio.destroyAggregateCalls == [999])
    }

    @Test("Restore falls back to built-in speakers when shared devices gone")
    @MainActor func restoreFallsBackToBuiltIn() async throws {
        let (mock, manager) = makeMockAndManager()
        let bt1 = AudioDeviceFixtures.bluetoothDevice(id: 1, uid: "bt1", sampleRate: 48000)
        let bt2 = AudioDeviceFixtures.bluetoothDevice(id: 2, uid: "bt2", sampleRate: 48000)
        mock.devicesToReturn = [bt1, bt2]
        mock.createAggregateResult = .success(999)

        try await manager.setupMultiOutputDevice()
        mock.clearRecordedCalls()

        // Remove shared devices, add built-in
        let builtIn = AudioDeviceFixtures.builtInSpeaker(id: 300)
        mock.devicesToReturn = [builtIn]

        await manager.stopOutput()

        #expect(mock.setDefaultOutputCalls == [builtIn.id])
    }
}
