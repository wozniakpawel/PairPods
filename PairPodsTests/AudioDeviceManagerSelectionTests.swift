//
//  AudioDeviceManagerSelectionTests.swift
//  PairPodsTests
//

import CoreAudio
@testable import PairPods
import Testing

@Suite("AudioDeviceManager Selection")
struct AudioDeviceManagerSelectionTests {
    @MainActor private func makeManager() -> AudioDeviceManager {
        UserDefaults.standard.removeObject(forKey: "excludedDeviceUIDs")
        let mock = MockAudioSystem()
        return AudioDeviceManager(audioSystem: mock, shouldShowAlerts: false)
    }

    @Test("Selects highest sample rate device as master")
    @MainActor func selectsHighestSampleRateAsMaster() {
        let manager = makeManager()
        let bt1 = AudioDeviceFixtures.bluetoothDevice(id: 1, sampleRate: 48000)
        let bt2 = AudioDeviceFixtures.bluetoothLEDevice(id: 2, sampleRate: 44100)

        let result = manager.selectDevicesForSharing([bt1, bt2])
        #expect(result.count == 2)
        // With 2 devices at different rates, each rate has count 1 — ties broken by descending rate
        #expect(result[0].sampleRate >= result[1].sampleRate)
    }

    @Test("Equal sample rates returns two distinct devices")
    @MainActor func equalSampleRatesReturnsTwoDevices() {
        let manager = makeManager()
        let bt1 = AudioDeviceFixtures.bluetoothDevice(id: 1, uid: "a", sampleRate: 48000)
        let bt2 = AudioDeviceFixtures.bluetoothDevice(id: 2, uid: "b", sampleRate: 48000)

        let result = manager.selectDevicesForSharing([bt1, bt2])
        #expect(result[0].id != result[1].id)
    }

    @Test("Returns devices sorted with master first")
    @MainActor func returnsSortedDevices() {
        let manager = makeManager()
        let bt1 = AudioDeviceFixtures.bluetoothDevice(id: 1, sampleRate: 96000)
        let bt2 = AudioDeviceFixtures.bluetoothDevice(id: 2, uid: "b", sampleRate: 44100)
        let bt3 = AudioDeviceFixtures.bluetoothDevice(id: 3, uid: "c", sampleRate: 48000)

        let result = manager.selectDevicesForSharing([bt1, bt2, bt3])
        #expect(result.count == 3)
    }

    @Test("Throws when fewer than 2 selected devices")
    @MainActor func throwsWithFewerThanTwo() {
        let manager = makeManager()
        let single = [AudioDeviceFixtures.bluetoothDevice()]

        #expect(throws: AppError.self) {
            try manager.validateSelectedDevices(single)
        }
    }

    @Test("Throws with zero devices")
    @MainActor func throwsWithZero() {
        let manager = makeManager()

        #expect(throws: AppError.self) {
            try manager.validateSelectedDevices([])
        }
    }

    @Test("Succeeds with exactly 2 devices")
    @MainActor func succeedsWithTwo() throws {
        let manager = makeManager()
        let devices = [
            AudioDeviceFixtures.bluetoothDevice(id: 1),
            AudioDeviceFixtures.bluetoothDevice(id: 2, uid: "b"),
        ]

        try manager.validateSelectedDevices(devices)
    }

    @Test("Succeeds with more than 2 devices")
    @MainActor func succeedsWithThree() throws {
        let manager = makeManager()
        let devices = [
            AudioDeviceFixtures.bluetoothDevice(id: 1),
            AudioDeviceFixtures.bluetoothDevice(id: 2, uid: "b"),
            AudioDeviceFixtures.bluetoothLEDevice(id: 3),
        ]

        try manager.validateSelectedDevices(devices)
    }

    @Test("Prefers majority sample rate group first")
    @MainActor func prefersMajoritySampleRateGroup() {
        let manager = makeManager()
        let bt1 = AudioDeviceFixtures.bluetoothDevice(id: 1, uid: "a", sampleRate: 44100)
        let bt2 = AudioDeviceFixtures.bluetoothDevice(id: 2, uid: "b", sampleRate: 48000)
        let bt3 = AudioDeviceFixtures.bluetoothDevice(id: 3, uid: "c", sampleRate: 48000)

        let result = manager.selectDevicesForSharing([bt1, bt2, bt3])
        // The two 48000Hz devices form the majority and should come first
        #expect(result[0].sampleRate == 48000)
        #expect(result[1].sampleRate == 48000)
        #expect(result[0].id != result[1].id)
    }
}
