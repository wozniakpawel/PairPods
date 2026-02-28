//
//  AudioDeviceManagerFlowTests.swift
//  PairPodsTests
//

import CoreAudio
@testable import PairPods
import Testing

@Suite("AudioDeviceManager Flow")
struct AudioDeviceManagerFlowTests {
    @MainActor private func makeMockAndManager() -> (MockAudioSystem, AudioDeviceManager) {
        let mock = MockAudioSystem()
        let manager = AudioDeviceManager(audioSystem: mock, shouldShowAlerts: false)
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

    @Test("Setup syncs sample rates when they differ")
    @MainActor func setupSyncsSampleRates() async throws {
        let (mock, manager) = makeMockAndManager()
        let bt1 = AudioDeviceFixtures.bluetoothDevice(id: 1, uid: "bt1", sampleRate: 44100)
        let bt2 = AudioDeviceFixtures.bluetoothDevice(id: 2, uid: "bt2", sampleRate: 48000)
        mock.devicesToReturn = [bt1, bt2]
        mock.createAggregateResult = .success(999)

        try await manager.setupMultiOutputDevice()

        #expect(mock.setSampleRateCalls.count == 1)
        #expect(mock.setSampleRateCalls.first?.sampleRate == 44100)
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

        await #expect(throws: AppError.self) {
            try await manager.setupMultiOutputDevice()
        }
    }

    @Test("Setup throws when aggregate creation fails")
    @MainActor func setupThrowsWhenAggregateCreationFails() async {
        let (mock, manager) = makeMockAndManager()
        let bt1 = AudioDeviceFixtures.bluetoothDevice(id: 1, uid: "bt1", sampleRate: 48000)
        let bt2 = AudioDeviceFixtures.bluetoothDevice(id: 2, uid: "bt2", sampleRate: 48000)
        mock.devicesToReturn = [bt1, bt2]
        mock.createAggregateResult = .failure(AppError.operationError("Failed"))

        await #expect(throws: AppError.self) {
            try await manager.setupMultiOutputDevice()
        }
    }

    @Test("Restore falls back to master device")
    @MainActor func restoreFallsBackToMaster() async throws {
        let (mock, manager) = makeMockAndManager()
        let bt1 = AudioDeviceFixtures.bluetoothDevice(id: 1, uid: "bt1", sampleRate: 48000)
        let bt2 = AudioDeviceFixtures.bluetoothDevice(id: 2, uid: "bt2", sampleRate: 48000)
        mock.devicesToReturn = [bt1, bt2]
        mock.createAggregateResult = .success(999)

        try await manager.setupMultiOutputDevice()
        mock.setDefaultOutputCalls.removeAll()

        await manager.restoreOutputDevice()

        #expect(mock.setDefaultOutputCalls.count == 1)
        // Should restore to master (lowest rate, sorted first)
        #expect(mock.setDefaultOutputCalls.first == bt1.id)
    }

    @Test("Restore falls back to built-in speakers when shared devices gone")
    @MainActor func restoreFallsBackToBuiltIn() async throws {
        let (mock, manager) = makeMockAndManager()
        let bt1 = AudioDeviceFixtures.bluetoothDevice(id: 1, uid: "bt1", sampleRate: 48000)
        let bt2 = AudioDeviceFixtures.bluetoothDevice(id: 2, uid: "bt2", sampleRate: 48000)
        mock.devicesToReturn = [bt1, bt2]
        mock.createAggregateResult = .success(999)

        try await manager.setupMultiOutputDevice()
        mock.setDefaultOutputCalls.removeAll()

        // Remove shared devices, add built-in
        let builtIn = AudioDeviceFixtures.builtInSpeaker(id: 300)
        mock.devicesToReturn = [builtIn]

        await manager.restoreOutputDevice()

        #expect(mock.setDefaultOutputCalls.count == 1)
        #expect(mock.setDefaultOutputCalls.first == builtIn.id)
    }

    @Test("State callbacks fire correctly")
    @MainActor func stateCallbacksFire() async throws {
        let (mock, manager) = makeMockAndManager()
        let bt1 = AudioDeviceFixtures.bluetoothDevice(id: 1, uid: "bt1", sampleRate: 48000)
        let bt2 = AudioDeviceFixtures.bluetoothDevice(id: 2, uid: "bt2", sampleRate: 48000)
        mock.devicesToReturn = [bt1, bt2]
        mock.createAggregateResult = .success(999)

        var states: [String] = []
        manager.deviceStateDidChange = { state in
            switch state {
            case .active: states.append("active")
            case .inactive: states.append("inactive")
            case .error: states.append("error")
            }
        }

        try await manager.setupMultiOutputDevice()
        #expect(states.contains("active"))
    }
}
