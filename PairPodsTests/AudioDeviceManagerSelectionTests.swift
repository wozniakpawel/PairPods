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
        let mock = MockAudioSystem()
        return AudioDeviceManager(audioSystem: mock, shouldShowAlerts: false)
    }

    @Test("Selects lowest sample rate device as master")
    @MainActor func selectsLowestSampleRateAsMaster() {
        let manager = makeManager()
        let bt1 = AudioDeviceFixtures.bluetoothDevice(id: 1, sampleRate: 48000)
        let bt2 = AudioDeviceFixtures.bluetoothLEDevice(id: 2, sampleRate: 44100)

        let (master, second) = manager.selectDevicesForSharing([bt1, bt2])
        #expect(master.sampleRate == 44100)
        #expect(second.sampleRate == 48000)
    }

    @Test("Equal sample rates returns two distinct devices")
    @MainActor func equalSampleRatesReturnsTwoDevices() {
        let manager = makeManager()
        let bt1 = AudioDeviceFixtures.bluetoothDevice(id: 1, uid: "a", sampleRate: 48000)
        let bt2 = AudioDeviceFixtures.bluetoothDevice(id: 2, uid: "b", sampleRate: 48000)

        let (master, second) = manager.selectDevicesForSharing([bt1, bt2])
        #expect(master.id != second.id)
    }

    @Test("Returns pair sorted ascending by sample rate")
    @MainActor func returnsSortedPair() {
        let manager = makeManager()
        let bt1 = AudioDeviceFixtures.bluetoothDevice(id: 1, sampleRate: 96000)
        let bt2 = AudioDeviceFixtures.bluetoothDevice(id: 2, uid: "b", sampleRate: 44100)
        let bt3 = AudioDeviceFixtures.bluetoothDevice(id: 3, uid: "c", sampleRate: 48000)

        let (master, second) = manager.selectDevicesForSharing([bt1, bt2, bt3])
        #expect(master.sampleRate <= second.sampleRate)
    }

    @Test("Throws when fewer than 2 compatible devices")
    @MainActor func throwsWithFewerThanTwo() {
        let manager = makeManager()
        let single = [AudioDeviceFixtures.bluetoothDevice()]

        #expect(throws: AppError.self) {
            try manager.validateCompatibleDevices(single)
        }
    }

    @Test("Throws with zero devices")
    @MainActor func throwsWithZero() {
        let manager = makeManager()

        #expect(throws: AppError.self) {
            try manager.validateCompatibleDevices([])
        }
    }

    @Test("Succeeds with exactly 2 devices")
    @MainActor func succeedsWithTwo() throws {
        let manager = makeManager()
        let devices = [
            AudioDeviceFixtures.bluetoothDevice(id: 1),
            AudioDeviceFixtures.bluetoothDevice(id: 2, uid: "b"),
        ]

        try manager.validateCompatibleDevices(devices)
    }

    @Test("Succeeds with more than 2 devices")
    @MainActor func succeedsWithThree() throws {
        let manager = makeManager()
        let devices = [
            AudioDeviceFixtures.bluetoothDevice(id: 1),
            AudioDeviceFixtures.bluetoothDevice(id: 2, uid: "b"),
            AudioDeviceFixtures.bluetoothLEDevice(id: 3),
        ]

        try manager.validateCompatibleDevices(devices)
    }

    @Test("Prefers same-sample-rate pair over lower rates")
    @MainActor func prefersSameSampleRatePair() {
        let manager = makeManager()
        let bt1 = AudioDeviceFixtures.bluetoothDevice(id: 1, uid: "a", sampleRate: 44100)
        let bt2 = AudioDeviceFixtures.bluetoothDevice(id: 2, uid: "b", sampleRate: 48000)
        let bt3 = AudioDeviceFixtures.bluetoothDevice(id: 3, uid: "c", sampleRate: 48000)

        let (master, second) = manager.selectDevicesForSharing([bt1, bt2, bt3])
        #expect(master.sampleRate == 48000)
        #expect(second.sampleRate == 48000)
        #expect(master.id != second.id)
    }
}
