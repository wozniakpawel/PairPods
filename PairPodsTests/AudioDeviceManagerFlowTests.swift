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
        let manager = AudioDeviceManager(audioSystem: mock, shouldShowAlerts: false, userDefaults: defaults)
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

    @Test("Aggregate is clocked by the clock device when the Mac exposes one")
    @MainActor func setupUsesClockDeviceWhenAvailable() async throws {
        let (mock, manager) = makeMockAndManager()
        mock.devicesToReturn = [
            AudioDeviceFixtures.bluetoothDevice(id: 1, uid: "bt1", sampleRate: 48000),
            AudioDeviceFixtures.bluetoothDevice(id: 2, uid: "bt2", sampleRate: 48000),
        ]
        mock.clockDeviceUIDToReturn = "ATSAC:testclock"

        try await manager.setupMultiOutputDevice()

        // With a clock device no Bluetooth radio is the timing reference, which is the
        // entire point: every sub-device can then be drift compensated.
        #expect(mock.createAggregateCalls.first?.clockUID == "ATSAC:testclock")
    }

    @Test("Aggregate falls back to a master sub-device when no clock device exists")
    @MainActor func setupFallsBackToMasterSubDevice() async throws {
        let (mock, manager) = makeMockAndManager()
        mock.devicesToReturn = [
            AudioDeviceFixtures.bluetoothDevice(id: 1, uid: "bt1", sampleRate: 48000),
            AudioDeviceFixtures.bluetoothDevice(id: 2, uid: "bt2", sampleRate: 48000),
        ]
        mock.clockDeviceUIDToReturn = nil

        try await manager.setupMultiOutputDevice()

        let call = try #require(mock.createAggregateCalls.first)
        #expect(call.clockUID == nil)
        #expect(call.subDeviceUIDs.contains(call.masterUID), "Master must be one of the sub-devices")
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

        await manager.restoreOutputDevice()

        #expect(mock.setDefaultOutputCalls.count == 1)
        // Should restore to master (highest rate, sorted first)
        #expect(mock.setDefaultOutputCalls.first == bt2.id)
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

        await manager.restoreOutputDevice()

        #expect(mock.setDefaultOutputCalls.count == 1)
        #expect(mock.setDefaultOutputCalls.first == builtIn.id)
    }
}
