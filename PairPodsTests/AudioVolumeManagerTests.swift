//
//  AudioVolumeManagerTests.swift
//  PairPodsTests
//

import CoreAudio
@testable import PairPods
import Testing

@Suite("AudioVolumeManager")
struct AudioVolumeManagerTests {
    @MainActor private func makeManager(
        devices: [AudioDevice] = [],
        userDefaults: UserDefaults? = nil
    ) async -> (AudioVolumeManager, MockAudioSystem, AudioDeviceManager) {
        let mock = MockAudioSystem()
        mock.devicesToReturn = devices
        let deviceManager = AudioDeviceManager(audioSystem: mock, shouldShowAlerts: false)
        await deviceManager.refreshCompatibleDevices()

        let defaults = userDefaults ?? {
            let suiteName = "PairPodsTests.\(UUID().uuidString)"
            let d = UserDefaults(suiteName: suiteName)!
            d.removePersistentDomain(forName: suiteName)
            return d
        }()
        let volumeManager = AudioVolumeManager(audioDeviceManager: deviceManager, userDefaults: defaults)
        return (volumeManager, mock, deviceManager)
    }

    @Test("Default volume is 0.5 when no cache exists")
    @MainActor func defaultVolumeIsHalf() async {
        let (volumeManager, _, _) = await makeManager()
        let device = AudioDeviceFixtures.bluetoothDevice()

        let volume = volumeManager.getDefaultVolume(for: device)
        #expect(volume == 0.5)
    }

    @Test("Returns cached volume when available")
    @MainActor func returnsCachedVolume() async throws {
        let suiteName = "PairPodsTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        // Pre-populate the cache in UserDefaults
        defaults.set(["cached-uid": Float(0.75)], forKey: "PairPods.DeviceVolumes")

        let (volumeManager, _, _) = await makeManager(userDefaults: defaults)
        let device = AudioDeviceFixtures.bluetoothDevice(uid: "cached-uid")

        let volume = volumeManager.getDefaultVolume(for: device)
        #expect(volume == 0.75)

        defaults.removePersistentDomain(forName: suiteName)
    }

    @Test("setVolume updates deviceVolumes immediately")
    @MainActor func setVolumeUpdatesDeviceVolumes() async {
        let bt1 = AudioDeviceFixtures.bluetoothDevice(id: 1, uid: "bt1")
        let (volumeManager, _, _) = await makeManager(devices: [bt1])

        await volumeManager.setVolume(for: 1, volume: 0.8)

        #expect(volumeManager.deviceVolumes[1] == 0.8)
    }

    @Test("setVolume persists to lastKnownVolumes by device UID")
    @MainActor func setVolumePersistsToLastKnownVolumes() async {
        let bt1 = AudioDeviceFixtures.bluetoothDevice(id: 1, uid: "persist-uid")
        let (volumeManager, _, _) = await makeManager(devices: [bt1])

        await volumeManager.setVolume(for: 1, volume: 0.65)

        #expect(volumeManager.lastKnownVolumes["persist-uid"] == 0.65)
    }

    @Test("Volume persistence survives UserDefaults round-trip")
    @MainActor func volumePersistenceRoundTrip() async throws {
        let bt1 = AudioDeviceFixtures.bluetoothDevice(id: 1, uid: "roundtrip-uid")

        let suiteName = "PairPodsTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))

        let mock = MockAudioSystem()
        mock.devicesToReturn = [bt1]
        let deviceManager = AudioDeviceManager(audioSystem: mock, shouldShowAlerts: false)
        await deviceManager.refreshCompatibleDevices()

        let vm1 = AudioVolumeManager(audioDeviceManager: deviceManager, userDefaults: defaults)
        await vm1.setVolume(for: 1, volume: 0.42)

        // Create a second instance with same UserDefaults
        let vm2 = AudioVolumeManager(audioDeviceManager: deviceManager, userDefaults: defaults)
        let loaded = vm2.getDefaultVolume(for: bt1)

        #expect(loaded == 0.42)

        defaults.removePersistentDomain(forName: suiteName)
    }

    @Test("setVolume for unknown device updates local state but not persistent cache")
    @MainActor func setVolumeForUnknownDevice() async {
        let (volumeManager, _, _) = await makeManager()

        // Device ID 999 is not in compatible devices
        await volumeManager.setVolume(for: 999, volume: 0.9)

        #expect(volumeManager.deviceVolumes[999] == 0.9)
        #expect(volumeManager.lastKnownVolumes.isEmpty)
    }

    @Test("Volume change notification updates both maps")
    @MainActor func volumeChangeNotificationUpdatesMaps() async throws {
        let bt1 = AudioDeviceFixtures.bluetoothDevice(id: 1, uid: "notif-uid")
        let (volumeManager, _, _) = await makeManager(devices: [bt1])

        // Post a volume change notification
        NotificationCenter.default.postDeviceVolumeChanged(deviceID: 1, volume: 0.33)

        // Give RunLoop time to process
        try await Task.sleep(nanoseconds: 100_000_000)

        #expect(volumeManager.deviceVolumes[1] == 0.33)
        #expect(volumeManager.lastKnownVolumes["notif-uid"] == 0.33)
    }
}
