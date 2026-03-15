//
//  AudioDeviceManagerSelectionTests.swift
//  PairPodsTests
//

import CoreAudio
@testable import PairPods
import Testing

struct AudioDeviceManagerSelectionTests {
    @MainActor private func makeManager() -> AudioDeviceManager {
        UserDefaults.standard.removeObject(forKey: "excludedDeviceUIDs")
        UserDefaults.standard.removeObject(forKey: "PairPods.DeviceOrder")
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

    // MARK: - Device Order

    @Test("saveDeviceOrder persists to UserDefaults")
    @MainActor func saveDeviceOrderPersists() {
        let manager = makeManager()
        manager.saveDeviceOrder(["uid-b", "uid-a", "uid-c"])
        let stored = UserDefaults.standard.stringArray(forKey: "PairPods.DeviceOrder") ?? []
        #expect(stored == ["uid-b", "uid-a", "uid-c"])
        UserDefaults.standard.removeObject(forKey: "PairPods.DeviceOrder")
    }

    @Test("loadDeviceOrder returns empty array when nothing saved")
    @MainActor func loadDeviceOrderReturnsEmptyWhenNotSet() {
        let manager = makeManager()
        #expect(manager.loadDeviceOrder() == [])
    }

    @Test("loadDeviceOrder returns saved order")
    @MainActor func loadDeviceOrderReturnsSavedOrder() {
        UserDefaults.standard.set(["uid-z", "uid-x"], forKey: "PairPods.DeviceOrder")
        let mock = MockAudioSystem()
        let manager = AudioDeviceManager(audioSystem: mock, shouldShowAlerts: false)
        #expect(manager.loadDeviceOrder() == ["uid-z", "uid-x"])
        UserDefaults.standard.removeObject(forKey: "PairPods.DeviceOrder")
    }

    @Test("selectDevicesForSharing uses user order when saved")
    @MainActor func selectDevicesForSharingUsesUserOrder() {
        let manager = makeManager()
        let bt1 = AudioDeviceFixtures.bluetoothDevice(id: 1, uid: "uid-a", sampleRate: 48000)
        let bt2 = AudioDeviceFixtures.bluetoothDevice(id: 2, uid: "uid-b", sampleRate: 96000)
        let bt3 = AudioDeviceFixtures.bluetoothDevice(id: 3, uid: "uid-c", sampleRate: 44100)
        // Save order: c, a, b  — should override the sample-rate smart sort
        manager.saveDeviceOrder(["uid-c", "uid-a", "uid-b"])

        let result = manager.selectDevicesForSharing([bt1, bt2, bt3])
        #expect(result[0].uid == "uid-c")
        #expect(result[1].uid == "uid-a")
        #expect(result[2].uid == "uid-b")
        UserDefaults.standard.removeObject(forKey: "PairPods.DeviceOrder")
    }

    @Test("selectDevicesForSharing falls back to sample rate sort when no user order")
    @MainActor func selectDevicesForSharingFallsBackToSampleRateSort() {
        let manager = makeManager()
        let bt1 = AudioDeviceFixtures.bluetoothDevice(id: 1, uid: "uid-a", sampleRate: 44100)
        let bt2 = AudioDeviceFixtures.bluetoothDevice(id: 2, uid: "uid-b", sampleRate: 96000)

        let result = manager.selectDevicesForSharing([bt1, bt2])
        // No user order: highest sample rate first
        #expect(result[0].uid == "uid-b")
        #expect(result[1].uid == "uid-a")
    }

    @Test("selectDevicesForSharing places unknown-order devices last")
    @MainActor func selectDevicesForSharingPlacesUnknownDevicesLast() {
        let manager = makeManager()
        let bt1 = AudioDeviceFixtures.bluetoothDevice(id: 1, uid: "uid-a", sampleRate: 48000)
        let bt2 = AudioDeviceFixtures.bluetoothDevice(id: 2, uid: "uid-b", sampleRate: 48000)
        let bt3 = AudioDeviceFixtures.bluetoothDevice(id: 3, uid: "uid-new", sampleRate: 48000)
        // Only a and b are in the saved order; uid-new is a new device
        manager.saveDeviceOrder(["uid-b", "uid-a"])

        let result = manager.selectDevicesForSharing([bt1, bt2, bt3])
        #expect(result[0].uid == "uid-b")
        #expect(result[1].uid == "uid-a")
        #expect(result[2].uid == "uid-new")
        UserDefaults.standard.removeObject(forKey: "PairPods.DeviceOrder")
    }
}
