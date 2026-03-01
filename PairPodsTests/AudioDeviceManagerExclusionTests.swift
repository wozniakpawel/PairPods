//
//  AudioDeviceManagerExclusionTests.swift
//  PairPodsTests
//

import CoreAudio
@testable import PairPods
import Testing

@Suite("AudioDeviceManager Exclusion & N-Device")
struct AudioDeviceManagerExclusionTests {
    @MainActor private func makeMockAndManager() -> (MockAudioSystem, AudioDeviceManager) {
        // Clear any persisted exclusions from previous test runs
        UserDefaults.standard.removeObject(forKey: "excludedDeviceUIDs")
        let mock = MockAudioSystem()
        let manager = AudioDeviceManager(audioSystem: mock, shouldShowAlerts: false)
        return (mock, manager)
    }

    // MARK: - Exclusion Toggle

    @Test("Excluding a device removes it from selectedDevices")
    @MainActor func excludeDeviceRemovesFromSelected() async {
        let (mock, manager) = makeMockAndManager()
        let bt1 = AudioDeviceFixtures.bluetoothDevice(id: 1, uid: "bt1")
        let bt2 = AudioDeviceFixtures.bluetoothDevice(id: 2, uid: "bt2")
        let bt3 = AudioDeviceFixtures.bluetoothDevice(id: 3, uid: "bt3")
        mock.devicesToReturn = [bt1, bt2, bt3]
        await manager.refreshCompatibleDevices()

        #expect(manager.selectedDevices.count == 3)

        manager.setDeviceExcluded("bt2", excluded: true)

        #expect(manager.selectedDevices.count == 2)
        #expect(!manager.selectedDevices.contains(where: { $0.uid == "bt2" }))
    }

    @Test("Re-including a device adds it back to selectedDevices")
    @MainActor func reIncludeDeviceAddsBack() async {
        let (mock, manager) = makeMockAndManager()
        let bt1 = AudioDeviceFixtures.bluetoothDevice(id: 1, uid: "bt1")
        let bt2 = AudioDeviceFixtures.bluetoothDevice(id: 2, uid: "bt2")
        mock.devicesToReturn = [bt1, bt2]
        await manager.refreshCompatibleDevices()

        manager.setDeviceExcluded("bt2", excluded: true)
        #expect(manager.selectedDevices.count == 1)

        manager.setDeviceExcluded("bt2", excluded: false)
        #expect(manager.selectedDevices.count == 2)
    }

    @Test("isDeviceSelected returns correct value")
    @MainActor func isDeviceSelectedReturnsCorrectValue() {
        let (_, manager) = makeMockAndManager()

        #expect(manager.isDeviceSelected("bt1"))

        manager.setDeviceExcluded("bt1", excluded: true)
        #expect(!manager.isDeviceSelected("bt1"))

        manager.setDeviceExcluded("bt1", excluded: false)
        #expect(manager.isDeviceSelected("bt1"))
    }

    // MARK: - Persistence

    @Test("Exclusion persists to UserDefaults")
    @MainActor func exclusionPersistsToUserDefaults() {
        let (_, manager) = makeMockAndManager()

        manager.setDeviceExcluded("bt1", excluded: true)
        manager.setDeviceExcluded("bt3", excluded: true)

        let stored = UserDefaults.standard.stringArray(forKey: "excludedDeviceUIDs") ?? []
        #expect(Set(stored) == Set(["bt1", "bt3"]))

        // Clean up
        UserDefaults.standard.removeObject(forKey: "excludedDeviceUIDs")
    }

    @Test("Exclusion loads from UserDefaults on init")
    @MainActor func exclusionLoadsFromUserDefaults() {
        UserDefaults.standard.set(["bt2", "bt4"], forKey: "excludedDeviceUIDs")

        let mock = MockAudioSystem()
        let manager = AudioDeviceManager(audioSystem: mock, shouldShowAlerts: false)

        #expect(manager.excludedDeviceUIDs == Set(["bt2", "bt4"]))
        #expect(!manager.isDeviceSelected("bt2"))
        #expect(manager.isDeviceSelected("bt1"))

        // Clean up
        UserDefaults.standard.removeObject(forKey: "excludedDeviceUIDs")
    }

    // MARK: - N-Device Selection

    @Test("3-device selection returns all 3 sorted")
    @MainActor func threeDeviceSelection() {
        let (_, manager) = makeMockAndManager()
        let bt1 = AudioDeviceFixtures.bluetoothDevice(id: 1, uid: "a", sampleRate: 48000)
        let bt2 = AudioDeviceFixtures.bluetoothDevice(id: 2, uid: "b", sampleRate: 48000)
        let bt3 = AudioDeviceFixtures.bluetoothDevice(id: 3, uid: "c", sampleRate: 44100)

        let result = manager.selectDevicesForSharing([bt1, bt2, bt3])
        #expect(result.count == 3)
        // 48000 is majority, so those come first
        #expect(result[0].sampleRate == 48000)
        #expect(result[1].sampleRate == 48000)
        #expect(result[2].sampleRate == 44100)
    }

    @Test("4-device selection returns all 4")
    @MainActor func fourDeviceSelection() {
        let (_, manager) = makeMockAndManager()
        let bt1 = AudioDeviceFixtures.bluetoothDevice(id: 1, uid: "a", sampleRate: 48000)
        let bt2 = AudioDeviceFixtures.bluetoothDevice(id: 2, uid: "b", sampleRate: 48000)
        let bt3 = AudioDeviceFixtures.bluetoothDevice(id: 3, uid: "c", sampleRate: 44100)
        let bt4 = AudioDeviceFixtures.bluetoothLEDevice(id: 4, uid: "d", sampleRate: 48000)

        let result = manager.selectDevicesForSharing([bt1, bt2, bt3, bt4])
        #expect(result.count == 4)
    }

    // MARK: - Setup with Exclusions

    @Test("Setup with 3 compatible and 1 excluded creates aggregate with 2")
    @MainActor func setupWithExclusion() async throws {
        let (mock, manager) = makeMockAndManager()
        let bt1 = AudioDeviceFixtures.bluetoothDevice(id: 1, uid: "bt1", sampleRate: 48000)
        let bt2 = AudioDeviceFixtures.bluetoothDevice(id: 2, uid: "bt2", sampleRate: 48000)
        let bt3 = AudioDeviceFixtures.bluetoothDevice(id: 3, uid: "bt3", sampleRate: 48000)
        mock.devicesToReturn = [bt1, bt2, bt3]
        mock.createAggregateResult = .success(999)

        manager.setDeviceExcluded("bt2", excluded: true)

        try await manager.setupMultiOutputDevice()

        #expect(mock.createAggregateCalls.count == 1)
        let call = mock.createAggregateCalls[0]
        #expect(call.subDeviceUIDs.count == 2)
        #expect(!call.subDeviceUIDs.contains("bt2"))
    }

    @Test("Setup fails when exclusions leave fewer than 2 selected")
    @MainActor func setupFailsWithTooManyExclusions() async {
        let (mock, manager) = makeMockAndManager()
        let bt1 = AudioDeviceFixtures.bluetoothDevice(id: 1, uid: "bt1", sampleRate: 48000)
        let bt2 = AudioDeviceFixtures.bluetoothDevice(id: 2, uid: "bt2", sampleRate: 48000)
        mock.devicesToReturn = [bt1, bt2]

        manager.setDeviceExcluded("bt1", excluded: true)

        await #expect(throws: AppError.self) {
            try await manager.setupMultiOutputDevice()
        }
    }

    // MARK: - N-Device Aggregate

    @Test("Setup with 3 devices creates aggregate with all 3 sub-device UIDs")
    @MainActor func setupWithThreeDevices() async throws {
        let (mock, manager) = makeMockAndManager()
        let bt1 = AudioDeviceFixtures.bluetoothDevice(id: 1, uid: "bt1", sampleRate: 48000)
        let bt2 = AudioDeviceFixtures.bluetoothDevice(id: 2, uid: "bt2", sampleRate: 48000)
        let bt3 = AudioDeviceFixtures.bluetoothDevice(id: 3, uid: "bt3", sampleRate: 48000)
        mock.devicesToReturn = [bt1, bt2, bt3]
        mock.createAggregateResult = .success(999)

        try await manager.setupMultiOutputDevice()

        #expect(mock.createAggregateCalls.count == 1)
        let call = mock.createAggregateCalls[0]
        #expect(call.subDeviceUIDs.count == 3)
        #expect(mock.setDefaultOutputCalls.contains(999))
    }

    @Test("Setup with 3 devices syncs sample rates for non-master devices")
    @MainActor func setupSyncsSampleRatesForMultipleDevices() async throws {
        let (mock, manager) = makeMockAndManager()
        let bt1 = AudioDeviceFixtures.bluetoothDevice(id: 1, uid: "bt1", sampleRate: 48000)
        let bt2 = AudioDeviceFixtures.bluetoothDevice(id: 2, uid: "bt2", sampleRate: 48000)
        let bt3 = AudioDeviceFixtures.bluetoothDevice(id: 3, uid: "bt3", sampleRate: 44100)
        mock.devicesToReturn = [bt1, bt2, bt3]
        mock.createAggregateResult = .success(999)

        try await manager.setupMultiOutputDevice()

        // The 44100 device should be synced to the master's rate (48000, the majority)
        #expect(mock.setSampleRateCalls.count == 1)
        #expect(mock.setSampleRateCalls.first?.sampleRate == 48000)
    }
}
